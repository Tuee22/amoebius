# Amoebius Development Plan

> **Purpose**: Provide the authoritative numeric phase order, current status, remaining work, and routing
> to each phase's independently authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order, status, and dated implementation progress. Each phase document owns its
capability-specific validation contract, while the universal source-snapshot postcondition is owned by
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
Architecture remains owned by the doctrine suite under [`../documents/`](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/low_code_ui_workflow_lifting.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_ebs_credential_model.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/tla_modelling_assumptions.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md, documents/illegal_state/illegal_state_topology.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [Phase discipline](#phase-discipline)
- [Repository and evidence discipline](#repository-and-evidence-discipline)
- [Toolchain](#toolchain)
- [Document index](#document-index)
- [Status vocabulary](#status-vocabulary)
- [Implementation-progress vocabulary](#implementation-progress-vocabulary)
- [Definition of Done](#definition-of-done)
- [Reopened numeric sequence](#reopened-numeric-sequence)
- [Current implementation audit](#current-implementation-audit)
- [Phase overview](#phase-overview)
- [Related Documents](#related-documents)

---

amoebius is one Haskell runtime with command, host-daemon, control-plane daemon, scheduler, and worker responsibilities.
The bounded Python `pb` pre-binary handoff exists only to make the minimum platform-adapter distinction,
establish the contained Haskell toolchain, build the source-bound binary, and exec it with argv unchanged. It
does not own a public command, product decision, or validation verdict and is distinct from the Haskell
`BootstrapCoordinator` role.
The constituent prodbox, infernix, jitML, and hostbootstrap capabilities converge as libraries and
behaviours rather than separate products.

## Phase discipline

1. Phase gates execute and statuses close strictly in numeric order. A later `Substrate: none` phase may have
   its typed contract, independent oracle, and hardware-free implementation prepared ahead of the validation
   frontier, but that work is only an implementation observation: it cannot run the later phase gate, mint
   candidate evidence, consume an unavailable predecessor, or change status before every numerical predecessor
   passes. Live, host, image, container, cluster, accelerator, and other hardware-bearing work remains closed by
   the barrier in item 8.
2. Each phase document owns one cohesive capability claim and one acceptance command.
3. Every gate inherits the artifact-hygiene postcondition in
   [development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
4. Every hardware substrate can run the `linux-cpu` baseline **at its own natural architecture and no
   other**. Pristine Linux uses Incus on Linux or Linux-CUDA, Lima on Apple at `arm64`, and WSL2 on Windows at
   `amd64`. A gate names its lane with that architecture; nothing is emulated or cross-built
   ([substrate_doctrine.md §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).
5. A hardware gate names exactly one substrate and one lane. `apple`, `linux-cuda`, and `windows` are
   substrate members; `metal` and `cuda` are specialized capability lanes, while `provider` is a managed
   target lane. The `linux-cpu` baseline cannot substitute for a specialized claim, and one architecture
   cannot substitute for the other.
6. Register 1 is pure/semantic-oracle, Register 2 is boundary-with-fakes, and Register 3 is live. Register 2.5 is a
   deterministic-simulation activity, never a phase-gate register.
7. Missing prerequisites fail; they never skip to green. Unreached applicable layers remain UNVERIFIED.
8. Phase 49 is the complete no-hardware DSL gate barrier and requires every `LTD-SRC-*` query,
   including the Phase-2-owned `LTD-SRC-008` boundary, to be zero. Phase 0 first requires a scoped `SourcePb`
   zero for its captured bootstrap source without retiring that binding. Phase 50 owns no migration and validates
   only the runtime behavior of that already-bounded handoff. Phase 0 invokes its Haskell validator directly
   under the narrow GenesisTrust assumption; Phase 1 through Phase 49 bind the authenticated acquisition and
   source-built executable identity. `pb` is unavailable as validation transport until Phase 50 proves it.
   Phase 51 remains a hardware-free Haskell host-ensure
   kernel. Phase 52 is the first hardware-bearing gate. No host, image, registry, cluster, accelerator, or
   cloud validation work may begin before the Phase-49 gate and every intervening numerical predecessor gate
   pass.
9. A complete qualified phase-gate pass is sufficient for Done. A human, agent, or CI job may record the
   narrow status-only transition by applying the exact verified patch emitted by the validator. The validator
   never edits a tracked file itself.

## Repository and evidence discipline

Version-controlled behavioral source is Haskell (`*.hs`) only. Python beneath `pb/**` is the sole source-code
exception and is limited to the bootstrap handoff described above. Documentation, licences, Cabal/project
metadata, ignore rules, and narrowly bounded packaging metadata are tracked inputs, not alternative product
languages. Dhall, PureScript, JavaScript, Python outside `pb/**`, shell, Proto, Pulumi, Dockerfiles,
configuration projections, fixtures, checking tools, oracle serializations, mutants, ledgers, receipts, logs,
reports, screenshots, and other executable or behavioral artifacts are generated lazily from Haskell into
`.build/**` and remain untracked.

All amoebius-owned state stays under the physical checkout. `.build/**` owns reproducible, transient, and
evidentiary output; `.data/**` owns production runtime and durable state; `.test_data/**` owns exclusively
harness-created test state. Raw candidate evidence lives in `.build/runs/**`; a content-addressed result may
be installed beneath `.build/evidence-store/**`. Only a complete qualified result for the exact current source
is a gate pass. The complete
repository tree, output inventory, lifecycle rules, and normative `.gitignore`/`.dockerignore` patterns
are owned by
[repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md).

## Toolchain

`GenesisTrust` is the irreducible, non-numbered `BootstrapRoot` beneath the plan. It states only local custody
of the seven exact prepared archive/signature files pinned in the Phase-0 plan, compile-time GHC version
`9.12.4`, absolute reported `ghc` and library-directory paths, and Linux/`x86_64`. The signature files are
opaque pinned bytes. GenesisTrust does not authenticate a publisher, the actual compiler executable bytes or
their derivation, the loader, the broader host, or reproducibility, and the Phase-0 binary cannot prove those
facts about itself. Phase 1 owns those acquisition/provenance claims; Phase 2 owns the compiler-backed semantic
source graph.

Compilers, package tools, libraries, code generators, browsers, and transitive dependencies resolve
dynamically from authored compatibility requirements. Every clean run records the selected versions,
source identities, dependency graph, executable paths, and observed integrity data under `.build/toolchain/`
and `.build/locks/`, then binds them into repository-local evidence. No generated resolution is copied into Git.

Only the irreducible host floor is supplied by the operator; everything with a supported install path is
ensured beneath `.build/**`. The floor is checked before any requirement resolves, so an unsupported host is
named with its remedy rather than discovered as a later symptom. Every authored platform key is the canonical
`<os>-<arch>` token, and a publisher that offers no asset for the host's architecture is a refusal, never a
substitution.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Target-only Haskell component-to-doctrine/phase map; never a present-tree or status ledger |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | The sole reader-facing explanation of active typed Haskell divergence bindings; never executable contract |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) | Validation registers and boundary discipline |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | Sibling-source migration and convergence rules |
| `phase_00_*.md` … `phase_95_*.md` | One independently authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope phases not yet assigned an integer document |

## Status vocabulary

The numbered plan uses exactly three phase states: **✅ Done**, **🔄 Active — NOT VALIDATED**, and
**⏸️ Blocked — NOT VALIDATED**. At a non-terminal frontier, the tracker contains one contiguous Done
prefix, exactly one Active phase, and one Blocked suffix; at the terminal frontier every phase is Done. A
complete qualified gate pass and its exact emitted status patch are the only way to advance that projection.
Historical status words and symbols cannot reactivate themselves.

## Implementation-progress vocabulary

Until revalidation, the only permitted implementation classifications are **Observed footprint** and
**Known partial**. They report that files or prior run material exist; they do not establish correctness,
source-policy conformance, gate integrity, or phase completion. No previous command result changes either
classification.

## Definition of Done

A phase is Done only after all of the following occur in order:

1. Its fixed eighteen-row Gate-integrity contract has no `UNRESOLVED`, `MISSING`, skipped, implicit, or empty
   required field and every independently authored oracle required by that phase's typed qualification is part
   of the run. Phase 0's exact independent candidate oracle is the finite `BootstrapMutationDriver`; broader
   component-oracle integration belongs to the Phase-49 universal owner.
2. Phase 0 binds its explicit `GenesisTrust` root rather than pretending to prove an earlier numbered result;
   every later phase binds the exact current gate-pass result of its immediate predecessor.
3. The phase-scoped source check accounts for every tracked path. Phase 0 owns the finite exact-snapshot,
   path/mode/shebang classification and admission of the exact current captured `pb/**` bytes; Phase 2 owns the
   complete `VALIDATION_PB_GRAMMAR` selector/oracle suite and compiler-backed semantic source-graph closure.
   Until that later owner closes, the missing qualification and semantic layers remain exact typed, later-owned
   findings rather than becoming implicit Phase-0 prerequisites.
4. A fresh cleanroom run ordinarily starts without current-run generated/state roots or condemned legacy copies
   and lazily derives every required non-Haskell product beneath `.build/**`. Its sole retained generated input
   is the exact read-only immediate-predecessor receipt. Phase 0 instead consumes its seven GenesisTrust files,
   uses one unique serial qualification leaf, and proves that exact leaf absent afterward; it makes no
   whole-`.build/**` absent-before claim.
5. The exact Haskell harness build first rejects every qualification sabotage assigned to the phase, then runs
   the clean candidate. Phase 0 qualifies the finite seed kernel; Phase 49 owns the complete hardware-free,
   universal self-referential corpus.
6. Discovery is non-empty and joins in both directions; positive controls, paired negatives, applied
   changed-subject mutants, freshness, observers, authority/bypass probes, and cleanup produce the observations
   required by the typed phase contract. Phase 0's v2 transcript retains exact exits and streams for its clean
   plus three cases: clean is silent `ExitSuccess`; every mutant is `ExitFailure 1`, empty stdout, and its
   canonical case label plus one newline on stderr.
7. Every typed Haskell legacy binding owned by the phase returns zero findings and its independently authored
   reintroduction negative turns red; Markdown row content is not an input.
8. The candidate bundle contains raw per-row observations. Phase 0 requires `captureResidue` to be empty and
   expresses later capabilities only as typed exclusions/forward deferrals; later phases retain applicable
   `UNVERIFIED` residue. A bundle passes only when every required row succeeds for the exact current source.
9. The gate verifies and emits the narrow proposed tracker and phase/sprint status patch beneath `.build/**`
   without changing the tracked tree. After the gate process exits successfully, a human, agent, or CI job may
   recheck its bound preimage and apply that exact patch.

Markdown never embeds or manufactures generated evidence, a hash, a transcript, or dependency resolution. A
complete qualified gate pass is sufficient; a partial script, digest, component diagnostic, or pre-reset result
cannot satisfy Done. Commit timing is not a gate input
([development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate)).

## Reopened numeric sequence

**Validation reset — 2026-08-22.** Every prior phase and sprint validation claim was invalidated. The reset
initialized Phase 0 as Active and Phases 1–95 as Blocked. The live status authority is the phase-overview table
and its joined phase/sprint fields below; it advances only after the immediate numerical predecessor's complete
gate passes.

Here, `Blocked` governs candidate execution and status, not the existence of source. Once a later
hardware-free sprint has a complete typed contract and separately authored oracle, its implementation may be
prepared and component-diagnosed ahead of the frontier. Such work remains NOT VALIDATED and cannot use `pb`,
live resources, hardware, or a missing predecessor result. This lets the implementation be ready before the
short, serial validate-and-record sequence without weakening numerical validation order.

Existing source and historical results are retained only as implementation or migration observations. They
cannot satisfy an acceptance condition, and historical prose cannot become current through a status change.
Only the live typed frontier and the exact phase/sprint status fields report which gates have passed.

Hardware validation is frozen. No phase at or above Phase 52 may run as phase-gate evidence until the hardware-free
DSL gate barrier and every preceding redesigned phase gate have passed.

## Current implementation audit

The current audit makes no validation attribution.

| Phase(s) | Current classification | Meaning |
|---|---|---|
| 0 | **Finite seed implementation** | The bounded Haskell dispatcher, GenesisTrust input, static source/document checks, finite changed-subject qualification, evidence verifier, and emitted-only status projection form the Phase-0 subject. Its validation state is reported only by the phase-overview row and joined Phase-0 status fields. |
| 1–95 | **Staged implementation inventory** | Existing files and historical run material remain implementation or migration observations until their own gates pass. Hardware-free implementation may be prepared under complete typed contracts and oracles; gate execution and status still follow the numerical frontier. |

The dated 2026-08-23 and 2026-08-26 component runs remain historical diagnostics and are invalid wherever their
production or oracle subjects changed. The aggregate runner source now names twenty-one component oracles; the
separate phase-contract-internal suite runs acquired-evidence/gate-pass, status-projection, and phase-contract
internal oracles. Current focused checks establish bounded, no-replace, content-addressed candidate publication;
descriptor-bounded readback and synchronization; repository/directory/file identity binding; byte tamper and
replacement-inode refusal; source-derived frontier classification; and fd-relative atomic leaf exchange with
independent-byte preservation. Status diagnostics also cover bounded descriptor-relative journal discovery,
finalization, pruning, replacement/symlink/rebinding adversaries, and injected finalization/recovery cutpoints.
They do not establish a complete green token or qualified phase gate. The lock, journal, recovery, atomic-
exchange, and tracked-file application branches are an observed footprint to remove, not Phase-0 completion
requirements: the conforming validator emits a verified status patch and leaves the tracked tree unchanged.

A dirty worktree is admissible only when the gate captures and tests its exact bytes and rejects any mid-run
change. The dispatcher provides that local capture/recheck path, closed runner selection, durable publication,
and hidden verification/authorization. Its current repository-lock, startup-recovery, journal, atomic-exchange,
and tracked-file application branches are superseded implementation, not unfinished qualification work; the
finite seed replaces them with deterministic patch emission and tests that the validator leaves tracked bytes
unchanged. The finite dispatcher binds the eighteen Phase-0 rows without enumerating later semantic gaps as
Phase-0 evidence or residue. Later contracts remain fail-closed at their own validation frontier, while their
hardware-free implementations may be prepared under exact typed contracts and separate oracles. This
separation prevents a new later requirement from reopening the finite bootstrap seed.

On 2026-08-31 the exact source-bound Haskell dispatcher was invoked directly with `validate phase 00`. It
durably published and reacquired a candidate and then refused it, with the old bare `genesis` marker present
rather than a digest-bound `GenesisTrust` input, because authenticated
compiler/toolchain/process producers, execution-derived qualification and legacy witnesses, independent
oracle/clean-room observation, complete identities/context and rows, and residue cleanup were absent. At that
time this was the complete gate attempt, not a pass or a status transition; Phase 0 remained NOT VALIDATED and
Phase 1 remained blocked.

The 2026-08-26 serialized diagnostic restored the two exact pinned source-repository inputs beneath ignored
`.build/**`, built `lib:validation-kernel` and `test:validation-kernel-component` with one Cabal job, repaired
six absent documentation-header finding projections, and reran the aggregate component suite. All eighteen
named component oracles executed and reported their bounded diagnostic expectations met after the semantic
oracle was aligned with the exact opaque-table rule and the mutable-worktree prose count was refrozen at 1,591.
The restored inputs were fetched during development and are not part of an exact current candidate; the green
aggregate is neither qualification, clean-room evidence, source snapshot integrity, nor validation.

The 2026-08-29 serialized development diagnostic established a fresh current-code baseline without widening
compiler concurrency. The authored monolithic package spent nearly ten minutes in dependency solving before
any compiler invocation, so a development-only package projection beneath ignored `.build/**` isolated the
current `validation-kernel` library and aggregate component test. Its task-local store was populated one
package at a time, the 34-module projected library and 20-module test runner compiled, and all then-eighteen component oracles
again reported their bounded diagnostic expectations met. The projection, cached inputs, compile, and green
aggregate are not a complete clean-room run, the authored package boundary, qualification, candidate evidence,
or the complete gate. A later same-day serialized rerun after the gate-pass policy rewrite again passed all
then-eighteen oracles, including local source capture/recheck and `GatePass`; no current status changed.

A further 2026-08-29 serialized inspection ran at the **authored package boundary**, not a projection, with
`--jobs=1` and one compiler command at a time. Against a warm dependency store the solver reported only
`lib:validation-kernel` as needing work; a clean library build took 52 seconds and the aggregate component
binary built and linked in 38 seconds, so the earlier ten-minute solve reflects a cold store rather than a
standing property of the authored package. That inspection then replaced the gate kernel's unconditional
refusals with predicates over evidence: the `PhaseSemanticContract` registry no longer both requires and
forbids an unbound slot, `ContractSlot` is the `ContractGap`/`BoundSpecification` pair, a contract gap is fatal
only at or below the phase under validation, the nine constant Phase-0 readiness findings became a predicate
over a typed all-unobserved `PhaseReadiness` record, and the current `validatePhase` footprint re-derives gates
0..N at one snapshot. The redesign replaces that coupling with one selected phase and the exact verified
immediate-predecessor receipt. The seventeen-oracle aggregate and the
phase-contract, phase-contract-internal, source-debt-internal, and compiler-source-graph-acquired suites all
report their bounded expectations met after their independent expectations were re-authored. This changes what
the kernel can express, not what has been observed: it is not qualification, clean-room observation, candidate
evidence, or a gate run. At that checkpoint no semantic slot was bound, and every phase and sprint status was
unchanged.

Capability-by-capability target ownership remains in the linked phase contracts and the target-only
[system_components.md](system_components.md). Current divergence identity, ownership, and closure are typed
Haskell bindings; the single
[legacy register](legacy_tracking_for_deletion.md) is their reader-facing explanation, with correspondence
owned by the documentation gate. No historical or partial component result is a current validation result.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation, source policy, and validation baseline | none | `none` | — | ✅ Done | [Contract](phase_00_documentation_suite.md) |
| 1 | Haskell toolchain and probe-source closure | none | `none` | 1 | 🔄 Active — NOT VALIDATED | [Contract](phase_01_toolchain_spike.md) |
| 2 | Repository layout conformance and de-phased naming | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_02_repository_layout_conformance.md) |
| 3 | The artifact calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_03_artifact_calculus.md) |
| 4 | The budget calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_04_budget_calculus.md) |
| 5 | The lift calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_05_lift_calculus.md) |
| 6 | The workflow calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_06_workflow_calculus.md) |
| 7 | The evidence calculus | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_07_evidence_calculus.md) |
| 8 | Scoped identity kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_08_scope_index.md) |
| 9 | Capacity core fold + topology relation | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_09_resource_index.md) |
| 10 | Composition across the five calculi | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_10_calculus_composition.md) |
| 11 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_11_formal_model_kernel.md) |
| 12 | The amoebius explicit-state checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_12_explicit_state_checker.md) |
| 13 | The amoebius symbolic checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_13_symbolic_checker.md) |
| 14 | The amoebius refinement checker | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_14_refinement_checker.md) |
| 15 | The compile-fail fixture harness | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_15_compile_fail_harness.md) |
| 16 | Deterministic-simulation substrate | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_16_deterministic_sim_substrate.md) |
| 17 | Gateway-migration model (both branches) | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_17_gateway_migration_model.md) |
| 18 | DSL formal model | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_18_dsl_formal_model.md) |
| 19 | Reconcile decision core under deterministic simulation | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_19_reconcile_core_simulation.md) |
| 20 | The extension declaration | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_20_extension_declaration.md) |
| 21 | The per-extension laws L1-L5 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_21_extension_laws_per_extension.md) |
| 22 | The compositional laws C1-C7 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_22_extension_laws_compositional.md) |
| 23 | The security laws S1-S6 | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_23_extension_security_laws.md) |
| 24 | The generated conformance gate | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_24_conformance_gate_generator.md) |
| 25 | Haskell-derived Dhall projection and smart-constructor prelude | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_25_dhall_schema_generation.md) |
| 26 | Haskell protocol declarations, GADT-indexed IR, and total decoder | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_26_gadt_decode_ir.md) |
| 27 | Illegal-state corpus + validation-locus ledger | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_27_illegal_state_covering.md) |
| 28 | Logical→physical storage geometry folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_28_storage_geometry_folds.md) |
| 29 | Execution-epoch + scheduler + accelerator + provider-root folds | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_29_execution_accelerator_folds.md) |
| 30 | Capability union + representational bind | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_30_capability_bind.md) |
| 31 | Whole-deployment provision seal + expansion | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_31_provision_seal.md) |
| 32 | InferenceEngine capability + accelerator provision | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_32_inference_accelerator_provision.md) |
| 33 | Pure `renderAll` + rendered-artifact oracles | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_33_render_manifest_oracles.md) |
| 34 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_34_chain_kernel_boundary.md) |
| 35 | The amoebius image recipe | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_35_image_recipe_generation.md) |
| 36 | The closed transaction vocabulary | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_36_transaction_vocabulary.md) |
| 37 | Bounded UI-program schema | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_37_ui_program_schema.md) |
| 38 | UI authorization kernel | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_38_ui_authorization_kernel.md) |
| 39 | UI effect binding | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_39_ui_effect_binding.md) |
| 40 | UI plan compiler | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_40_ui_plan_compiler.md) |
| 41 | Offline language and paired plans | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_41_offline_language_plan.md) |
| 42 | Haskell browser-interpreter semantics and projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_42_ui_browser_interpreter.md) |
| 43 | Haskell UI-server boundary | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_43_ui_server_boundary.md) |
| 44 | Hardware-free Haskell UI composition | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_44_ui_local_composition.md) |
| 45 | Haskell offline-state semantics and runtime projection | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_45_encrypted_browser_runtime.md) |
| 46 | Haskell-generated browser contracts and bundle | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_46_ui_contract_generation.md) |
| 47 | Foreign-source generator closure, checking tools, and mutants | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_47_tool_and_mutant_generation.md) |
| 48 | The test-workflow algebra | none | `none` | 1 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_48_test_workflow_algebra.md) |
| 49 | No-hardware DSL gate barrier + self-referential gate suite | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_49_self_referential_gates.md) |
| 50 | Validate the bounded `pb` → Haskell handoff | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_50_host_assert_cli.md) |
| 51 | The host-ensure kernel | none | `none` | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_51_host_ensure_kernel.md) |
| 52 | Linux: sudoless Docker and the native image | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_52_linux_engine_bringup.md) |
| 53 | Apple: Homebrew, Colima, and the native image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_53_apple_engine_bringup.md) |
| 54 | Windows: WSL2 and the lifted Linux engine | windows | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_54_windows_engine_bringup.md) |
| 55 | Haskell substrate coordinator + single kind cluster | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_55_bootstrap_coordinator_kind.md) |
| 56 | The base image, the jit-build resolver, and the in-cluster registry | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_56_base_image_registry.md) |
| 57 | The complementary-architecture base image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_57_complementary_arch_child.md) |
| 58 | Typed renderer + object reconciler | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_58_object_reconciler.md) |
| 59 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_59_capacity_scheduler.md) |
| 60 | No-provisioner retained storage + lossless rebind | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_60_retained_storage.md) |
| 61 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_61_vault_pki.md) |
| 62 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_62_platform_backbone.md) |
| 63 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_63_platform_services_2.md) |
| 64 | Keycloak-owned ingress | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_64_keycloak_ingress.md) |
| 65 | Live DSL deploy via the replicas=1 control-plane daemon | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_65_live_dsl_deploy.md) |
| 66 | Tenant/provider provisioning | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_66_app_tenancy.md) |
| 67 | Native Pulsar client (CBOR) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_67_pulsar_client.md) |
| 68 | Live subject/tenant isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_68_user_tenant_isolation_live.md) |
| 69 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_69_content_store_workflow.md) |
| 70 | Owner-scoped UI projection runtime | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_70_ui_projection_runtime.md) |
| 71 | Release lifecycle | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_71_release_lifecycle.md) |
| 72 | Atomic immutable UI-program release | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_72_ui_program_release.md) |
| 73 | WireGuard network fabric | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_73_network_fabric_wireguard.md) |
| 74 | Multi-cluster spawn + geo-replication | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_74_multicluster_spawn_georepl.md) |
| 75 | Gateway-migration drills + model-correspondence | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_75_gateway_migration_drills.md) |
| 76 | Haskell-derived provider Pulumi program and enveloped checkpoint | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_76_provider_deploy_checkpoint.md) |
| 77 | Hostless provider child + convergence + Lease handoff | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_77_provider_child_bringup.md) |
| 78 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_78_provider_ebs_credential.md) |
| 79 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_79_provider_dynamic_nodes.md) |
| 80 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_80_determinism_jitcache.md) |
| 81 | Single-tenant low-code UI live path | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_81_ui_single_tenant_live.md) |
| 82 | Multi-tenant low-code UI isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_82_ui_multi_tenant_live.md) |
| 83 | UI rollout, projection catch-up, and reconnect | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_83_ui_rollout_reconnect.md) |
| 84 | Initial online UI multi-zone high availability | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_84_ui_ha_multizone.md) |
| 85 | Offline replay and durable receipts | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_85_offline_replay_receipts.md) |
| 86 | Offline blobs and partition isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_86_offline_blobs_isolation.md) |
| 87 | Offline release and schema evolution | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_87_offline_release_evolution.md) |
| 88 | Offline multi-zone continuity | linux-cpu | `provider` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_88_offline_multizone_continuity.md) |
| 89 | Apple-Metal host compute daemon | apple | `metal` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_89_apple_metal_host_daemon.md) |
| 90 | The live test topology and elevated harness | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_90_test_topology_live.md) |
| 91 | The infernix inference core, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_91_infernix_rederivation.md) |
| 92 | The infernix workflow and artifact contracts, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_92_infernix_ui_rederivation.md) |
| 93 | The jitML numerical core, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_93_jitml_rederivation.md) |
| 94 | The jitML training and checkpoint contracts, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_94_jitml_ui_rederivation.md) |
| 95 | The multi-tenant web application re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_95_webapp_rederivation.md) |

Unnumbered future work remains in [later_phases.md](later_phases.md). It is not a numbered phase, tracker row,
predecessor, or validation state until a standards change assigns it an exact ordinal and contract.

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
