# System Components

> **Purpose**: Map every target amoebius component to its Haskell ownership boundary, canonical doctrine, and
> numerical delivery phase without maintaining a second implementation or status ledger.
> **Read this if**: a component must be traced to the Haskell source shape, doctrine, or phase that owns it.

**Observed implementation** ([GateSpec:documentation_suite]). This is a target-only inventory. It owns no
architectural rule and makes no implementation or validation claim. Architecture belongs to the linked
doctrine, phase status belongs only to [the tracker](README.md), and executable source/layout-divergence
accounting belongs to typed Haskell bindings in `Amoebius.Plan.Legacy`. The single
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) file explains those bindings to readers;
the documentation gate owns the correspondence.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, documents/engineering/lift_and_compose_doctrine.md
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

**Observed implementation** ([GateSpec:documentation_suite]). This document deliberately contains no
present-tree audit, historical result, stale receipt, or deletion checklist. The closed typed Haskell
inventory in `Amoebius.Plan.Legacy` is the only executable source
of active divergence IDs, owners, observations, and closure predicates. The single
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) register explains that inventory to
readers and supplies no machine input. A current finding not bijectively matched to one typed Haskell ID is
itself a Phase-0 failure. Editing either Markdown file cannot conceal debt or validate it.

## 1. The single binary — three contexts, several typed roles

One Haskell executable owns command mode, the sudo host-daemon context, and in-cluster roles. Roles are a
closed Haskell sum; they are not separate products or foreign-language entry points.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Executable and total role dispatch | `app/**/Main.hs`; `src/**/Command.hs`; `src/**/Role.hs` | [Daemon Topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-runtime-binary-three-contexts) | [34](phase_03_typed_spine.md), [43](phase_70_ui_projection_runtime.md), [55](phase_55_bootstrap_coordinator_kind.md) |
| Haskell command-mode administration | `src/**/AdminClient.hs` | [Bootstrap Sequence §5](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-control-plane-daemon-rest-api) | [65](phase_65_live_dsl_deploy.md) |
| Sudo host daemon and host-worker supervision | `src/**/Host/*.hs`; `src/**/HostWorker/*.hs` | [Daemon Topology §1](../documents/engineering/daemon_topology_doctrine.md#1-one-runtime-binary-three-contexts) | [55](phase_55_bootstrap_coordinator_kind.md), [89](phase_89_apple_metal_host_daemon.md) |
| Control-plane daemon, capacity scheduler, and unelected workers | `src/**/ControlPlane/*.hs`; `src/**/Scheduler/*.hs`; `src/**/Workflow/*.hs` | [Daemon Topology §§3–4](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) | [59](phase_59_capacity_scheduler.md), [65](phase_65_live_dsl_deploy.md), [69](phase_69_content_store_workflow.md) |

## 1.5. The core algebra — five calculi, two indices, one contract

Artifact, budget, lift, workflow, and evidence calculi plus scope/resource indices are Haskell libraries.
Their tests, independent semantic expectations, and mutants are also `.hs`.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Five calculi and their indexed base composition | `src/Amoebius/Calculus/{Artifact,Budget,Evidence,Lift,Workflow}/**/*.hs`; `src/calculus-composition/Amoebius/Calculus/Composition.hs`; `test/spec/calculus/*.hs` | [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | [3–7](legacy_tracking_for_deletion.md#5-dsl-divergence), [10](legacy_tracking_for_deletion.md#5-dsl-divergence) |
| Scope and resource indices | `src/Amoebius/Scope/{Index,Flow}.hs`; `src/capacity-topology/Amoebius/Capacity/{Types,Fold}.hs`; `src/capacity-topology/Amoebius/Dsl/Topology.hs` | [Extension Security](../documents/engineering/extension_conformance_security.md), [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [8](phase_06_extension_admission_attested_scope.md), [9](phase_04_witness_manifests_capacity_storage.md), [28–32](phase_04_witness_manifests_capacity_storage.md) |
| Formal/checker models | `src/Amoebius/Formal/{Model,Interpret,Explore,EmitTLA,ToyModel}.hs`; `src/formal-composition-model/**`; checkers `src/{explicit-state-checker,symbolic-checker,refinement-checker,compile-fail-harness}/**`; Haskell semantic oracles and the run-local fake SMT boundary under `test/spec/formal/**` plus `test/spec/compile_fail_harness/**`; package-hidden the proof-assistant track–16 supervisors under `src/validation-kernel/**`; later checker/model modules under their phase roots | [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md), [Testing Doctrine §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) | [11–19](later_phases.md) |
| Deterministic simulation substrate | `src/Amoebius/Sim/**/*.hs`; `test/spec/sim/{SimSpec,FaultContracts}.hs`; `test/harness/deterministic_simulation/CalculusProjection.hs`; package-hidden Phase 75 supervisor | [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | [16](phase_75_gateway_migration_drills.md), later adopters [58–59](phase_58_object_reconciler.md) |
| Extension declaration, laws, conformance gate, and transactions | Phase 6 declaration `src/extension-declaration/Amoebius/Extension/Declaration.hs`; Phase 6 per-extension evaluator; Phase 6 normalized composite/C1–C7 evaluator; Phase 6 typed identity/scope/namespace/policy kernel and S1–S6 evaluator; Phase 6 declaration-derived plan, generated-suite/verdict/admission kernel `src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs`; Phase 8 closed GADT and schema/policy/statement projection `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`; independent `.hs` oracles, compiler fixtures, production mutants, and package-hidden supervisors; later `src/**/Extension/*.hs` and `test/**/Extension/*.hs` | [Extension Conformance Doctrine](../documents/engineering/extension_conformance_doctrine.md), [Extension Conformance Laws](../documents/engineering/extension_conformance_laws.md), [Extension Security](../documents/engineering/extension_conformance_security.md), [Transaction Laws](../documents/engineering/extension_conformance_transactions.md) | [20–24](phase_06_extension_admission_attested_scope.md), [36](phase_08_ui_program_language_binding.md) |

## 2. The DSL — Dhall decoder + chain/Step kernel

Haskell is the sole behavioral source for the DSL schema, typed decoder, lowering, binding, planning,
provision seal, renderer, and lifecycle plan. Dhall supplied by an operator is external/untracked input. Any
Dhall schema/prelude/projection used by tooling is lazily generated beneath `.build/**` from the decoder.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| One definition per closed axis: substrate, architecture, lane, engine, capability arm, extension identity, unit-tagged quantity | `Amoebius.Vocabulary` in `library vocabulary`, base-only | [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) | [Phase 3](phase_03_typed_spine.md) |
| The typed root specification and its records | `Amoebius.Dsl.Spec` with `RootInForceSpec`, `ClusterSpec`, `TopologySpec`, `AppSpec`, `DeploymentRules` | [DSL Doctrine — the typed spec records](../documents/engineering/dsl_doctrine.md#the-typed-spec-records) | [Phase 3](phase_03_typed_spine.md) |
| The one import front door, the decoder, the encoder, and the example corpus | `Amoebius.Dsl.Import`, `Amoebius.Dsl.Decode`, `Amoebius.Dsl.Encode`, `Amoebius.Dsl.Examples.*`; the schema rendered from the decoder beneath `.build/dhall/**` | [DSL Doctrine §5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract), [Testing Doctrine — the example corpus](../documents/engineering/testing_doctrine.md#the-example-corpus) | [Phase 3](phase_03_typed_spine.md) |
| Lowering into the bind input; the single constructor path for `BoundDeployment` | `Amoebius.Dsl.Lower` | [DSL Doctrine §4](../documents/engineering/dsl_doctrine.md#4-total-composability) | [Phase 3](phase_03_typed_spine.md) |
| Closed step algebra, the one interpreter, and the pipeline | `Amoebius.Kernel.Step`, `Amoebius.Kernel.Chain`, `Amoebius.Kernel.Interpret`, `Amoebius.Dsl.Pipeline` (`compileDeployment`) | [DSL Doctrine §2](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) | [Phase 3](phase_03_typed_spine.md) |
| Witness-driven rendering, unit-tagged capacity, storage witness | the bind/plan/provision/render modules consuming placement, epoch, storage, and accelerator witnesses | [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md), [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [Phase 4](phase_04_witness_manifests_capacity_storage.md) |
| Substrate profile, lanes on nodes, payload-bearing quorum, image recipe rendered from the spec | `SubstrateProfile`, `Detected`, `Rke2Quorum`, `ImageRecipe` | [Substrate Doctrine](../documents/engineering/substrate_doctrine.md), [Image Build Doctrine](../documents/engineering/image_build_doctrine.md) | [Phase 5](phase_05_substrates_lanes_image_recipe.md) |
| The one `ExtensionSpec` record, linked extensions, the gate-side source checker, attested scope | `Amoebius.Extension.Spec` in `library extension-spec`; `LinkedExtensions`; the scope index | [Extension Conformance Doctrine](../documents/engineering/extension_conformance_doctrine.md), [Capability Extension Doctrine](../documents/engineering/capability_extension_doctrine.md) | [Phase 6](phase_06_extension_admission_attested_scope.md) |
| Forest adjacency, the typed child projection, the obligation-indexed chain | `Amoebius.Dsl.Children`; `chain :: ProvisionedSpec -> Workflow '[] '[] [Step]` | [DSL Doctrine — recursion](../documents/engineering/dsl_doctrine.md#recursion-a-childs-spec-is-a-typed-subtree-projection), [Workflow Calculus Doctrine](../documents/engineering/workflow_calculus_doctrine.md) | [Phase 7](phase_07_child_clusters_obligation_teardown.md) |
| The typed effect-port catalog, the expression and update algebra, program-joined binding, paired plans | `Amoebius.Ui.Effect.Catalog`, `Amoebius.Ui.Expr`, `Amoebius.Ui.Check`, `Amoebius.Ui.Bind`, `Amoebius.Ui.Plan` in `library ui-core` | [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) | [Phase 8](phase_08_ui_program_language_binding.md) |
| The union corpus, the endpoint as subject, the operator demonstration | `Amoebius.Dsl.Examples.Union`; `Amoebius.Entry.ControlPlane` | [Gate-Runner Doctrine §7](../documents/engineering/gate_runner_doctrine.md#7-the-example-corpus-and-the-hardware-rule) | [Phase 9](phase_09_dsl_barrier.md) |

No live host, live browser, container, cluster, provider, or hardware validation may start until the DSL barrier (Phase 9) itself
has passed its complete qualified gate after every predecessor. Pure browser semantics, lazy UI
generation, and fake boundaries remain part of the pre-barrier Haskell proof.

## 3. Manifests — typed renderer + the SSA reconciler

`K8sObject` values, ownership, dependency order, diffing, and snapshot-bound actions are Haskell. YAML/JSON
manifests and observation records are lazy `.build/**` materializations.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Total typed renderer | `src/**/Manifest/*.hs`; `test/**/Manifest/*.hs` | [Manifest Generation Doctrine §2](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) | [33](phase_03_typed_spine.md) |
| Snapshot-bound SSA reconciler | `src/**/Reconcile/*.hs` | [Manifest Generation Doctrine §5](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions) | [58](phase_58_object_reconciler.md) |

## 4. Capabilities — the capability→provider→shape binder

Capabilities, providers, shapes, permissions, supply, binding, and provisioned seals are closed Haskell types
and functions. Application/operator values cannot name provider coordinates or construct authority.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Logical-to-physical storage geometry | `src/storage-geometry-folds/Amoebius/Capacity/{Storage,StorageGeometry,ServiceStorage,Growable,StorageScaling}.hs` | [Resource Capacity Doctrine §5–§7](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm) | [28](phase_04_witness_manifests_capacity_storage.md) |
| Execution epochs, scheduler reservations, runtime/node-local storage, accelerator residency, provider-root, and composed placement | `src/execution-accelerator-folds/Amoebius/Capacity/{Execution,Scheduler,HostReservation,RuntimeStorage,NodeLocalStorage,Accelerator,ProviderRoot,Etcd,PulumiExecution,Composed}.hs`; `test/spec/dsl/ExecutionAccelerator{Fixtures,Oracle,Gate,Props,Spec}.hs`; package-hidden Phase 4 supervisor | [Resource Capacity Doctrine §3–§4](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget), [Testing Doctrine §2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) | [29](phase_04_witness_manifests_capacity_storage.md) |
| Capability/provider catalog and binding | `src/capability-bind/Amoebius/Capability/*.hs` | [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) | [30](phase_03_typed_spine.md) |
| Whole-deployment provision seal | `src/provision-seal/Amoebius/Capacity/{Provision,RenderSource}.hs`; `src/provision-seal/Amoebius/Capability/{Engine,Provisioned}.hs`; `test/spec/capability/{ProvisionSealGate,ProvisionSealOracle,ProvisionSealSpec,ProvisionFixtures,ProvisionProps,RuntimeStorageBindingProps}.hs`; package-hidden Phase 3 supervisor | [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [31](phase_03_typed_spine.md) |
| Accelerator/engine offering | `src/provision-seal/Amoebius/Capability/Engine.hs`; `test/spec/capability/EngineAccelerator{Fixtures,Oracle,Gate,Props,Spec}.hs`; package-hidden Phase 4 supervisor | [Service Capability Doctrine §4](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding) | [32](phase_04_witness_manifests_capacity_storage.md) |
| Pure manifest renderer and semantic oracle | private `manifest-render` library at `src/manifest-render/Amoebius/Manifest{,/Types,/K8sObject,/Render,/RenderAll}.hs`; `test/spec/manifest/{DepGraphOracle,RenderGoldenOracle,RenderGoldenGate,RenderGoldenProps,RenderGoldenSpec}.hs`; package-hidden Phase 3 supervisor | [Manifest Generation Doctrine §2–§3](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) | [33](phase_03_typed_spine.md) |

## 5. Platform services — baked non-Registry binaries + separately preloaded Distribution `registry:2`

The Registry capability has exactly one provider: CNCF Distribution `registry:2`. No other registry product is
an alternative, fallback, compatibility arm, or future option. Its separately pinned image is preloaded; its
binary is never baked into `amoebius-base`. Every other platform-service binary is baked. Service declarations
and manifests are Haskell-owned; runtime artifacts are generated under `.build/**` or materialized in the
live target.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Base image recipe and Distribution registry | `src/Amoebius/Image/{BakeInventory,CanonicalBakeCatalog,BaseChannel,BuildArgv,RenderDockerfile}.hs`; `src/**/Platform/Registry*.hs` | [Image Build Doctrine](../documents/engineering/image_build_doctrine.md), [Service Capability Doctrine §3](../documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific) | [35](phase_05_substrates_lanes_image_recipe.md), [56](phase_56_base_image_registry.md) |
| Object store, message bus, retained storage | `src/**/Platform/{ObjectStore,MessageBus,Storage}*.hs` | [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) | [60–62](phase_60_retained_storage.md) |
| SQL, Redis, observability, readiness | `src/**/Platform/{Sql,Redis,Observability,Readiness}*.hs` | [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) | [63](phase_63_platform_services_2.md) |
| Identity and single ingress | `src/**/Platform/{Identity,Edge}*.hs` | [Platform Services Doctrine §9](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) | [64](phase_64_keycloak_ingress.md) |

## 6. The native Pulsar client — `lib:pulsar-client`

Protocol source, codec, framing, subscription vocabulary, client state, fakes, and tests are Haskell. A `.proto`
view and any bindings/checksums are generated lazily beneath `.build/proto/**`.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| Protocol declaration and generated projection | `Amoebius.Dsl.GadtDecode.protocolDeclarations`; generated `PulsarApi.proto` is run-local only | [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) | [26](phase_03_typed_spine.md) |
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
| Haskell tool-ensure kernel | `src/Amoebius/Host/{Substrate,Frame,HostTool,Ensure,Reconciler,Lift,Context}.hs`; independent Haskell oracle/spec and package-hidden Phase-51 supervisor | [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) | [51](phase_51_host_ensure_kernel.md) |
| Native engine and frame adapters | Linux ownership in `src/Amoebius/Host/LinuxEngine.hs`; Apple/Windows target ownership in `src/**/Substrate/*.hs` and `src/**/Engine/*.hs` | [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) | [52–54](phase_52_linux_engine_bringup.md) |
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
| Gateway migration model and drills | `src/Amoebius/Formal/GatewayMigration.hs`, `src/Amoebius/Multicluster/{StructuralFit,GatewayMigration}.hs` | [Gateway Migration Doctrine](../documents/engineering/gateway_migration_doctrine.md), [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) | [17](phase_75_gateway_migration_drills.md), [75](phase_75_gateway_migration_drills.md) |

## 14. The pre-cluster (Register 1–2) design-first validation surface

The pre-cluster surface is the seven slice gates, Phases 3 through 9, over one growing example corpus. Each
slice adds an observable fact through the shipped `amoebius` binary — one spec to fake-applied bytes,
witness-driven manifests, substrates and lanes, extension admission, child clusters, the UI language — and
the DSL barrier (Phase 9) re-runs the union corpus and carries the `SpineFact`. The gate runner and the
custody core that judge every gate are Phase 0's subject
([Gate-Runner Doctrine](../documents/engineering/gate_runner_doctrine.md)). The shared future public spelling is
`pb validate phase NN`, but `pb` is inadmissible evidence until Phase 50 is gate-passed; each candidate through
Phase 9 is run by the verifier `amoebius-validate`, which spawns the product binary as a child. Each phase's
18-key table must be resolved, independently run, and accepted in table order. Current applicability of
historical evidence follows
[§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass), including its closure-based
predecessor binding; a status field cannot establish it.

| Target surface | Haskell ownership shape | Doctrine | Phase owner |
|---|---|---|---|
| The runner, the gate-specification library, the plan-decisions library, the standalone documentation checker | `Amoebius.Validation.Runner`, `Amoebius.Validation.GateSpec`, `Amoebius.Plan.*`, `Amoebius.Doc.Check` | [Gate-Runner Doctrine](../documents/engineering/gate_runner_doctrine.md), [Documentation Standards §17](../documents/documentation_standards.md#17-the-doctrine-freeze) | [Phase 0](phase_00_documentation_suite.md) |
| The capacity differential as a component row | the unit-tagged `fits` fold and its independent expectation | [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) | [Phase 4](phase_04_witness_manifests_capacity_storage.md) |
| Pure reconcile core and modeled schedules | the reconcile core and the parked model libraries | [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md), [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) | [Phase 75](phase_75_gateway_migration_drills.md) |

The DSL barrier (Phase 9) is the final pre-hardware gate and must exercise, through `compileDeployment`:

`decode → lower → plan → provision → renderAll → chain → dry-run → fake apply`

with no browser, container, cluster, provider, network service, or hardware-specific observer. Until that
barrier passes, Phase 50 and every later phase remain blocked. Phase 50 then validates only the bounded
`pb` handoff, Phase 51 remains hardware-free, and Phase 52 is the first hardware-bearing gate.

## Related Documents

- [Development Plan Tracker](README.md) — sole phase-status record
- [Development Plan Standards](development_plan_standards.md) — plan and gate contract
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md) — sole reader-facing explanation of active typed Haskell divergence bindings
- [Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md) — closed source tree
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — lazy `.build/**` rule
- [Testing Spoof Resistance](../documents/engineering/testing_spoof_resistance.md) — independent validation trust
