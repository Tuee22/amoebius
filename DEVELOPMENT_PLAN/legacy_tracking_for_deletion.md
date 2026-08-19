# Legacy Tracking for Deletion

> **Purpose**: Record every repository artifact, generated-output practice, obsolete term, and sibling-project
> surface that the amoebius convergence must delete, relocate, or replace, with an owning phase and closure
> condition.
> **Read this if**: an artifact of the earlier planning approach turns up and its status has to be settled.

This document lists material retained only until its replacement lands, so that a reader meeting it elsewhere
can tell it is migration input rather than current doctrine. It owns deletion and relocation bookkeeping, not
design or phase status. Current status belongs to [README.md](README.md); artifact placement belongs to
[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md), and doctrine
routing belongs to the [documentation index](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_04_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_11_dhall_typecheck_schema.md, DEVELOPMENT_PLAN/phase_12_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_15_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_16_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_17_capability_bind.md, DEVELOPMENT_PLAN/phase_18_provision_seal.md, DEVELOPMENT_PLAN/phase_19_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_20_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_21_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_23_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_24_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_35_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_40_vault_pki.md, DEVELOPMENT_PLAN/phase_44_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_60_infernix_lift.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/documentation_standards.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Ledger Status](#ledger-status)
- [Host-band re-baseline — 2026-08-18](#host-band-re-baseline--2026-08-18)
- [Host-ensure amendment — 2026-08-17](#host-ensure-amendment--2026-08-17)
- [Phase re-baseline — 2026-08-17](#phase-re-baseline--2026-08-17)
- [One binary, many roles — 2026-08-17](#one-binary-many-roles--2026-08-17)
- [Natural-architecture rebaseline — 2026-08-16](#natural-architecture-rebaseline--2026-08-16)
- [Repository-containment rebaseline — 2026-08-15](#repository-containment-rebaseline--2026-08-15)
- [Existing-code divergence snapshot — 2026-08-11](#existing-code-divergence-snapshot--2026-08-11)
- [Phase-0 closure disposition — 2026-08-12](#phase-0-closure-disposition--2026-08-12)
- [Layout and naming divergence snapshot — 2026-08-14](#layout-and-naming-divergence-snapshot--2026-08-14)
- [What the layout conformance uncovered — 2026-08-17](#what-the-layout-conformance-uncovered--2026-08-17)
- [Generated-artifact and terminology migration — 2026-08-11](#generated-artifact-and-terminology-migration--2026-08-11)
- [Pre-implementation Phase Re-baseline — 2026-08-01](#pre-implementation-phase-re-baseline--2026-08-01)
- [Pending Removal](#pending-removal)
- [Notes](#notes)
- [Related Documents](#related-documents)

---

## Ledger Status

🔄 **Active through Phase 33.** The repository contains implementation and generated migration material. The
2026-08-15 containment amendment reopened phases 0–63, and the 2026-08-16 natural-architecture
amendment reopened every phase again and renumbered old 26–64 to 27–65. No row closes merely because a file is absent locally;
the owning phase must enforce the replacement against its source snapshot and verify repository-local evidence.

**Phase 2 closed the positional class on 2026-08-17**, which is the largest single reduction this ledger has
recorded: the deferral total falls from 876 to 314, and every `r13` and `r15` row is deleted rather than
re-owned. What remains is the *deletion* class — generated output still written beneath an authored root, host
state still escaping the checkout, and expectation tables whose provenance their owning phase must establish —
plus the behavioural halves the rows below now name explicitly.

Where a row leans on the sibling prodbox/infernix/jitML system as justification, that is **evidence from a sibling system, not proof in amoebius** (the honesty rule, [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

```mermaid
flowchart LR
  %% register: orientation
  div["an observed divergence"]
  row["a row here, with an owner and a closure condition"]
  defer["a deferral the audit reports and attributes"]
  close["the owning phase clears it, in numeric order"]
  stale["a row matching nothing fails the audit"]
  div -->|"is recorded as"| row
  row -->|"justifies"| defer
  defer -->|"is reported at every run until"| close
  close -->|"retires the row, because"| stale
```
*Orientation. The deferral list can only shrink, so the target tree is reached exactly when it empties; [development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate) clause 5 owns the deferral mechanism.*

---

## Host-band re-baseline — 2026-08-18

Six phases are inserted at 3 and the rest shift by six; phases 0–2 do not move. The band they form is the
plan's one deliberate departure from validating the DSL before implementing host logic, and it has a closure
condition rather than a precedent: the rule is not executable until the thing that executes it exists, and
nothing outside the critical path from a bare host to a built image belongs to these six.

**Order of operations.** The tree does not move in this change. No path outside the plan suite names a phase,
so this is the documentation act and it lands as one commit: check `u3` derives its slug-to-ordinal map from
the filenames on disk, so no rename can precede the reference sweep and no sweep can precede the rename.
Until phases 3–8 run, every statement in a later phase describing a host as already prepared is a divergence
this table owns rather than a defect in that phase.

### The audit map

| new id | new path | old id | old path | why it moved |
|--------|----------|--------|----------|--------------|
| 0 | `phase_00_documentation_suite.md` | 0 | `phase_00_documentation_suite.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 1 | `phase_01_toolchain_spike.md` | 1 | `phase_01_toolchain_spike.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 2 | `phase_02_repository_layout_conformance.md` | 2 | `phase_02_repository_layout_conformance.md` | unmoved — the inserted band opens at 3, below which nothing shifts |
| 3 | `phase_03_host_assert_cli.md` | — | — | **new.** The pre-binary host assertions had no owner: [`substrate_doctrine.md` §6](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) stated the coordinator contract and the first phase to gate any part of it sat 26 phases after the first host is touched |
| 4 | `phase_04_host_ensure_kernel.md` | — | — | **new.** The post-handoff ensure surface was specified per substrate inside unrelated phases; one closed substrate-indexed algebra makes the cross-substrate branch unrepresentable |
| 5 | `phase_05_amoebius_image_recipe.md` | — | — | **new.** "The recipe does not change as the remaining Haskell lands" is a claim only a sealed golden can hold, and it had no owning gate |
| 6 | `phase_06_linux_engine_bringup.md` | — | — | **new.** The bootstrap phase assumed a guest with a container runtime already present; nothing gated the step that installs it |
| 7 | `phase_07_apple_engine_bringup.md` | — | — | **new.** `apple` was gated only at phases the 2026-08-17 re-baseline moved to the tail, leaving the Apple host floor itself ungated |
| 8 | `phase_08_windows_engine_bringup.md` | — | — | **new.** `windows` was a declared catalog member no phase gated; [§L](development_plan_phase_model.md#l-one-substrate-discipline)'s own sentence saying so is retracted by this change |
| 9 | `phase_09_formal_model_kernel.md` | 3 | `phase_03_formal_model_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 10 | `phase_10_gateway_migration_model.md` | 4 | `phase_04_gateway_migration_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 11 | `phase_11_dhall_typecheck_schema.md` | 5 | `phase_05_dhall_typecheck_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 12 | `phase_12_gadt_decode_ir.md` | 6 | `phase_06_gadt_decode_ir.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 13 | `phase_13_illegal_state_corpus.md` | 7 | `phase_07_illegal_state_corpus.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 14 | `phase_14_capacity_core_folds.md` | 8 | `phase_08_capacity_core_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 15 | `phase_15_storage_geometry_folds.md` | 9 | `phase_09_storage_geometry_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 16 | `phase_16_execution_accelerator_folds.md` | 10 | `phase_10_execution_accelerator_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 17 | `phase_17_capability_bind.md` | 11 | `phase_11_capability_bind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 18 | `phase_18_provision_seal.md` | 12 | `phase_12_provision_seal.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 19 | `phase_19_inference_accelerator_provision.md` | 13 | `phase_13_inference_accelerator_provision.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 20 | `phase_20_render_manifest_goldens.md` | 14 | `phase_14_render_manifest_goldens.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 21 | `phase_21_chain_kernel_boundary.md` | 15 | `phase_15_chain_kernel_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 22 | `phase_22_deterministic_sim_substrate.md` | 16 | `phase_16_deterministic_sim_substrate.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 23 | `phase_23_dsl_formal_model.md` | 17 | `phase_17_dsl_formal_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 24 | `phase_24_reconcile_core_simulation.md` | 18 | `phase_18_reconcile_core_simulation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 25 | `phase_25_ui_program_schema.md` | 19 | `phase_19_ui_program_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 26 | `phase_26_scoped_identity_kernel.md` | 20 | `phase_20_scoped_identity_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 27 | `phase_27_ui_authorization_kernel.md` | 21 | `phase_21_ui_authorization_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 28 | `phase_28_ui_effect_binding.md` | 22 | `phase_22_ui_effect_binding.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 29 | `phase_29_ui_plan_compiler.md` | 23 | `phase_23_ui_plan_compiler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 30 | `phase_30_offline_language_plan.md` | 24 | `phase_24_offline_language_plan.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 31 | `phase_31_ui_browser_interpreter.md` | 25 | `phase_25_ui_browser_interpreter.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 32 | `phase_32_ui_server_boundary.md` | 26 | `phase_26_ui_server_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 33 | `phase_33_ui_local_composition.md` | 27 | `phase_27_ui_local_composition.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 34 | `phase_34_encrypted_browser_runtime.md` | 28 | `phase_28_encrypted_browser_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 35 | `phase_35_bootstrap_coordinator_kind.md` | 29 | `phase_29_bootstrap_coordinator_kind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 36 | `phase_36_base_image_registry.md` | 30 | `phase_30_base_image_registry.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 37 | `phase_37_object_reconciler.md` | 31 | `phase_31_object_reconciler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 38 | `phase_38_capacity_scheduler.md` | 32 | `phase_32_capacity_scheduler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 39 | `phase_39_retained_storage.md` | 33 | `phase_33_retained_storage.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 40 | `phase_40_vault_pki.md` | 34 | `phase_34_vault_pki.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 41 | `phase_41_platform_backbone.md` | 35 | `phase_35_platform_backbone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 42 | `phase_42_platform_services_2.md` | 36 | `phase_36_platform_services_2.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 43 | `phase_43_keycloak_ingress.md` | 37 | `phase_37_keycloak_ingress.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 44 | `phase_44_live_dsl_deploy.md` | 38 | `phase_38_live_dsl_deploy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 45 | `phase_45_app_tenancy.md` | 39 | `phase_39_app_tenancy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 46 | `phase_46_pulsar_client.md` | 40 | `phase_40_pulsar_client.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 47 | `phase_47_user_tenant_isolation_live.md` | 41 | `phase_41_user_tenant_isolation_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 48 | `phase_48_content_store_workflow.md` | 42 | `phase_42_content_store_workflow.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 49 | `phase_49_ui_projection_runtime.md` | 43 | `phase_43_ui_projection_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 50 | `phase_50_release_lifecycle.md` | 44 | `phase_44_release_lifecycle.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 51 | `phase_51_ui_program_release.md` | 45 | `phase_45_ui_program_release.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 52 | `phase_52_network_fabric_wireguard.md` | 46 | `phase_46_network_fabric_wireguard.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 53 | `phase_53_multicluster_spawn_georepl.md` | 47 | `phase_47_multicluster_spawn_georepl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 54 | `phase_54_gateway_migration_drills.md` | 48 | `phase_48_gateway_migration_drills.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 55 | `phase_55_provider_deploy_checkpoint.md` | 49 | `phase_49_provider_deploy_checkpoint.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 56 | `phase_56_provider_child_bringup.md` | 50 | `phase_50_provider_child_bringup.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 57 | `phase_57_provider_ebs_credential.md` | 51 | `phase_51_provider_ebs_credential.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 58 | `phase_58_provider_dynamic_nodes.md` | 52 | `phase_52_provider_dynamic_nodes.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 59 | `phase_59_determinism_jitcache.md` | 53 | `phase_53_determinism_jitcache.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 60 | `phase_60_infernix_lift.md` | 54 | `phase_54_infernix_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 61 | `phase_61_infernix_ui_lift.md` | 55 | `phase_55_infernix_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 62 | `phase_62_test_topology_dsl.md` | 56 | `phase_56_test_topology_dsl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 63 | `phase_63_ui_single_tenant_live.md` | 57 | `phase_57_ui_single_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 64 | `phase_64_ui_multi_tenant_live.md` | 58 | `phase_58_ui_multi_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 65 | `phase_65_ui_rollout_reconnect.md` | 59 | `phase_59_ui_rollout_reconnect.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 66 | `phase_66_ui_ha_multizone.md` | 60 | `phase_60_ui_ha_multizone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 67 | `phase_67_offline_replay_receipts.md` | 61 | `phase_61_offline_replay_receipts.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 68 | `phase_68_offline_blobs_isolation.md` | 62 | `phase_62_offline_blobs_isolation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 69 | `phase_69_offline_release_evolution.md` | 63 | `phase_63_offline_release_evolution.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 70 | `phase_70_offline_multizone_continuity.md` | 64 | `phase_64_offline_multizone_continuity.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 71 | `phase_71_jitml_lift_cuda.md` | 65 | `phase_65_jitml_lift_cuda.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 72 | `phase_72_jitml_ui_lift.md` | 66 | `phase_66_jitml_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 73 | `phase_73_complementary_arch_child.md` | 67 | `phase_67_second_arch_attested_index.md` | shift, **reopened, and renamed**: the attested multi-architecture index is retracted with the manifest list, so the slug's `attested_index` had become a false claim; the phase keeps the complementary architecture's native image and loses the join |
| 74 | `phase_74_apple_metal_host_daemon.md` | 68 | `phase_68_apple_metal_host_daemon.md` | shift only — displaced by an inserted phase or by a moved neighbour |

### Rejected, with reason

| # | proposal | not adopted, because |
|---|----------|----------------------|
| R1 | a fractional id (`Phase 2.5`) for the inserted band | [§E](development_plan_phase_model.md#e-one-canonical-phase-model) admits `0..N` contiguous with no fractional id; the fully mapped re-baseline is the only admitted mechanism |
| R2 | inserting the band at 1 or 2 | the CLI reads the authored toolchain requirements that Phase 1 delivers, so a phase below it inverts [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-3; and `tools/layout_relocation_map.tsv` names Phase 2 in its own header, so inserting at 2 edits the one artifact that must be authored before the move it records |
| R3 | tail placement for `apple` and `windows` | [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)-1 is the stronger constraint: splitting "amoebius prepares its host" across one early phase and two tail phases makes the host-portability claim a design plus two exceptions, and that claim is the one the project makes on its first page. The cost is recorded rather than hidden — the head band is a three-machine floor, and the contiguity a single-machine developer had is re-scoped to phases 9 through 70 |
| R4 | one merged host-bring-up phase | [§O](development_plan_standards.md#o-sprint-sized-seams-and-bounded-phase-gates) admits one acceptance command in one register on at most one substrate; a merged phase names three substrates and two registers |
| R5 | merging phases 3 and 4 | two languages, two test stacks, and two independently useful claims — that the pre-binary assertions are idempotent, and that the post-handoff assertions are substrate-indexed and branchless |
| R6 | keeping `buildx` for the base image while banning it elsewhere | two build mechanisms is the opposite of one lifted path, and [§6](../documents/engineering/image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1)'s question would then have two answers |
| R7 | preserving the OCI index as a publish-time join without `buildx` | the join produces an artifact no single host attested, which is the defect the natural-architecture rebaseline exists to remove |
| R8 | shifting the phase column of `test/oracle/preimplementation_artifacts.tsv` | twelve or more gates select their rows by literal ordinal prefix and assert a custody count against them; shifting the column zeroes those silently |
| R9 | bulk-shifting the phase ordinals inside `src/`, `test/`, `tools/`, and `dhall/` string content | shifting a stale name mints a fresh stale name; those are de-phased, not translated |

This change also retired twenty-one rows whose observation was struck and whose closure was recorded without
a residual half. A register row earns its place by naming work still owed; a row that records only that
something was finished is answered by the phase document that finished it, and keeping it here costs the
budget a live row needs.

### Still open after this change

- The gate modules for phases 3–8 do not exist; each new phase names a `**Gate:**` command the tree does not
  yet carry. Owner: phases 3–8. Closure: each gate runs to a verdict and emits its ledger.
- `questions.txt` is tracked at the repository root and rule `r13` reports it as outside the target tree.
  Owner: Phase 2. Closure: the file is placed or removed.
- 886 acronym first uses across the corpus are unexpanded against [`documentation_standards.md` §12.1](../documents/documentation_standards.md), whose registry is normative and whose adoption is zero. No check
  measures it. Owner: Phase 0. Closure: a check exists and the corpus passes it.
- The `p3` sentence-cap backlog stands at 69, and `SENTENCE_CAP` is parked at 90 against the stated 45.
  Owner: Phase 0. Closure: the cap reaches its stated value with the corpus under it.
- Five sprint sub-numbers cited across documents do not exist in either the old or the new numbering —
  `Sprint 20.8`, `Sprint 32.4`, `Sprint 32.5`, `Sprint 10.19`, and `Sprint 49.3`. The 2026-08-18 ordinal
  pass corrected each reference's *phase* component and left the sub-number, which was already dangling.
  Owner: the citing phase of each. Closure: each names a sprint that exists.

### What this change does not perform

This is the documentation act. Every row below is code the change deliberately did not touch.

| observation | required end state | owner and closure |
|-------------|--------------------|-------------------|
| `dhall/amoebius/Image.dhall` declares `Base : { name : Text }` and a three-arm `BakeStep`, while doctrine states an architecture-carrying `Base` and the four-rung ladder | the Dhall unions match [`image_build_doctrine.md` §5](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest) and [§6](../documents/engineering/image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1) | Phase 42. Closure: the tags and the rungs are representable and no fourth `BakeStep` shape exists |
| `dhall/amoebius/BakeCatalog.dhall` carries `baseDigest` and the rendered golden pins `ubuntu:24.04@sha256:…` | no authored digest in any recipe or catalog; the parent is a channel resolved per run | Phase 5. Closure: no authored digest remains under `dhall/` or the recipe golden |
| `src/Amoebius/Image/{BuildRuntime,Artifact,Publish,Ref,NodeLoad}.hs` and eight Python tools model a multi-architecture index | one image per architecture under its own tag, with no join | Phase 42. Closure: no module constructs or validates a manifest list |
| ~~`src/Amoebius/Host/Ensure.hs` carries `installMechanism :: String`, `installAndVerify` has no caller, and `HostTool` has five constructors and no `Docker` arm~~ | the ensure algebra is typed data with a probe-first driver | **Closed by Phase 4 on 2026-08-19.** A step is a `Performer` plus an `[Argument]` in which a version is a `RequirementVersion` rather than a literal; `HostTool` carries `Docker`; and the driver is exercised by the absent → present → present replay against a committed fake tool directory, which is what makes the re-resolve observable rather than argued |
| ~~`src/Amoebius/Cluster/Bootstrap.hs` refuses `apple` and `windows` outright~~ | every catalog member reaches a frame | **Closed by Phase 4 on 2026-08-19.** The wildcard arm is replaced by an exhaustive match over `Frame`, so each substrate enters the frame its row names; materializing the Lima and WSL2 frames belongs to Phases 7 and 8 |
| `test/fixture/bootstrap_coordinator/install_plans.tsv` describes the retired four-column step shape, which the typed `InstallStep` renders as five | the Phase-35 fixture describes the step shape that exists | Phase 35. Closure: `tools/bootstrap_coordinator_gate.py` reaches a verdict against the rendered plan |
| `dsl-core` compiled `Amoebius.Pulumi.Engine` as a home module its stanza never declared, so `-Werror=missing-home-modules` refused the build | every home module a component compiles is declared by that component | **Closed by Phase 4 on 2026-08-19**: the module is declared, and the gate builds under `-Werror` |
| ~~`pb/` is an `argparse` CLI under a setuptools `pyproject.toml` with no configured type checker, formatter, linter, or test runner~~ | a Poetry distribution installed with `pipx`, checked under `mypy --strict` with no explicit `Any` | **Closed by Phase 3 on 2026-08-19.** The distribution is Poetry-built with a Click topology; `ruff`, `black` and `mypy --strict` with `disallow_any_explicit` run as a gate precondition, a token-aware scan refuses `Any`, `cast` and `type: ignore` outright, and 217 tests cover it at 100% branch coverage |
| `test/spec/host/test_bootstrap_coordinator.py` imports `pb.bootstrap_coordinator`, which Phase 3 split into `pb/pb/{process,prereqs,bootstrap}.py` | the Phase-35 spec drives the modules that exist, through the one choke point | Phase 35. Closure: the spec imports resolve and `tools/bootstrap_coordinator_gate.py` reaches a verdict |
| `test/spec/host/test_live_dsl_deploy_admin_client.py` imports `pb.cli.parser`, which the Click topology replaced | the Phase-44 spec reads the command surface through the parser that exists | Phase 44. Closure: the spec imports resolve and the admin surface is exercised against the daemon |
| `pb/pb/admin.py` is the second (admin-REST) mode and has no live validation; Phase 3's gate exercises it only against a fake opener | the mode is validated against a running control-plane daemon | Phase 44. Closure: Sprint 44.4 drives Vault init/unseal, Dhall update and KV CRUD live |
| ~160 `tools/*_live.py` modules drive kind, Vault, Pulsar, MinIO and Kubernetes in Python, duplicating the typed, absolute-path host layer `src/Amoebius/Host/**` exists to own, and none is covered by any linter, type checker or suite | cluster drivers are Haskell behind the typed host boundary; Python keeps only the policy-over-text gate kernel, held to the standard Phase 3 set for `pb/` | the owning phase of each live gate. Closure: each `*_live.py` is retired as its phase reopens, or is brought under the `pb` quality standard |
| `tools/toolchain.py` resolves into `.build/toolchain/{bin,runtime,downloads,cache}` with no platform segment | the resolved-toolchain tree is partitioned by `<os>-<arch>` | Phase 4. Closure: two hosts of different architecture resolve into disjoint subtrees |
| thirty-one gate modules pass `PhaseGate(phase=N)` with `N` offset from their own contract's ordinal | the run-artifact tag and the contract ordinal agree, or the divergence is authored | the owning phase of each gate. Closure: the integer is derived from the contract path |
| `tools/base_image_registry_gate.py` maps its mutants to sprint ids from a superseded numbering | the sprint prefix is derived from the contract | Phase 42. Closure: no sprint id names a phase the document does not carry |
| `tools/live_dsl_deploy_gate.py` discovers a test module under a name the file no longer has, so the step runs no tests and passes | the discovery pattern names the file that exists | Phase 44. Closure: the step reports a non-zero test count |
| eight UI gate modules construct `PhaseGate` without a lane, which the constructor refuses | each names its lane | the owning phase of each gate. Closure: every gate constructs |
| two gate modules write run evidence into `DEVELOPMENT_PLAN/evidence/`, an authored root, and neither uses the shared harness that would refuse it | evidence lands beneath `.build/runs/**` | the owning phase of each gate. Closure: no gate writes into an authored root |
| `tools/containment.py` resolves `docker` at a hard-coded path that does not exist on `apple`, so the containment observer silently degrades there | the executable is resolved through the ensure kernel | Phase 4. Closure: the observer reports on every substrate |
| `tools/migration_allowlist.tsv` carries owner cells in a superseded numbering. `dhall/examples/locus_registry.tsv` and `tools/generator_registry.tsv` were shifted — the registry together with the `**Delivery-owner:**` tags it joins against and the literal ceiling in `tools/locus_registry_lint.py`, which is still written rather than derived | each owner cell names the current ordinal, and the ceiling is derived rather than written | the owning phase of each row. Closure: the owner column joins to the tracker |
| roughly three thousand phase ordinals sit in comments and string literals across `src/`, `test/`, `tools/`, and `dhall/`, most already stale | no authored non-plan content names a phase ordinal | the owning phase of each. Closure: the de-phasing that Phase 2 applied to paths is applied to content |
| `documents/engineering/substrate_doctrine.md` retains its ensure-contract, virtualized-substrate, and coordinator sections in a hub carrying one slice | the family carries a slice per aspect | Phase 0. Closure: each remaining aspect is its own slice |
| `documents/engineering/testing_doctrine.md` states no policy for the browser image, its three engines, or host-driven end-to-end runs | the end-to-end policy is authored in testing doctrine | Phase 0. Closure: the policy has an owning section |
| the gate ordinal families named `dhall-typecheck` and `gadt-decode` remain in filenames, oracle keys, and prose | each names the mechanism that rejects rather than an ordinal | Phase 0. Closure: no authored name carries a gate ordinal |

---

## Host-ensure amendment — 2026-08-17

amoebius ensures its own tools: an absent dependency with a supported install plan is installed, never
recorded as a manual prerequisite
([`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)).
The floor a host must supply is now written down
([§3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply)),
and [§F](development_plan_standards.md#f-the-sprint-block-format)'s vocabulary is narrowed to it. What the
change condemns is recorded here with an owner and a closure condition, per
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

| Existing observation | Required replacement | Owner and closure |
|---|---|---|
| `src/Amoebius/Host/Ensure.hs` exposes `installAndVerify`, and nothing in the tree calls it; no installer implementation exists, and `installMechanism` is a bare `String` that nothing parses, so the install plan is pure but uninterpretable | A closed mechanism sum an interpreter can execute, and a production caller | Phase 35. Closure: the driver has a caller outside a spec, and the mechanism is a closed union |
| Version literals live outside the authored requirements: `ghcup-install:3.16.1.0` at three plan sites and three candidate paths in `Ensure.hs`, `python-download:v0.32.0`, `ToolchainPin.hs`'s `ghc-9.12`, `Cluster/Kind.hs`'s pinned node image and digest, and the `install_plans.tsv` golden that pins the same values a second time | Every version and every download identity resolves from `tools/toolchain_requirements.json` at run time | Phase 35. Closure: no version literal outside the authored requirements. The Phase-35 record already calls `3.16.1.0` a deleted pin; six sites still carry it |
| `tools/toolchain.py` and `pb/pb/bootstrap_toolchain.py` each implement the version algebra and release selection; ~~the two disagreed on platform normalization, the second mapping Apple silicon to `darwin-aarch64`, which matches no authored `platform_map` key~~ | One resolver per language boundary over one canonical `<os>-<arch>` token set | **Normalization closed by Phase 1 on 2026-08-17**: `tools/host_platform.py` is the one normalizer, the gate module, the resolver, and the pre-binary coordinator all read it, and a pure check refuses any authored key outside the token set. Phase 35 keeps the rest — the duplicated version algebra and release selection, and the pb resolver's own test, mutant, and surface row |
| `Amoebius.Host.Ensure.firstExecutable` requires the executable bit while `Amoebius.Host.Context.firstAbs` checks only existence, and `Context` resolves `docker` and `df` outside the closed `HostTool` enum whose closedness Phase 35 asserts structurally | One resolver, and every resolved tool inside the enum | Phase 35. Closure: no second discovery helper, and the enum covers every tool a production path invokes |
| The closed tool set is written three times — the host spec's five constructors, `tools/pristine_host_gate.py`'s differently-populated five, and the coordinator gate's `7/7-absent` metric | One authored set the three read | Phase 35. Closure: one declaration, and the arity strings derive from it |
| `tools/base_image_registry_standup.py` derives `dhall-to-json` as a filesystem sibling of the resolved `dhall`, a companion no requirement declares. **Sharpened 2026-08-17 by Phase 1**: `dhall` is now acquired from its publisher's own release, whose archive contains `bin/dhall` and no companion at all, so the derived sibling does not exist rather than merely being undeclared | The companion is an authored requirement resolved like any other | Phase 36. Closure: no tool is reached by deriving a sibling of another tool's path |
| Twenty-five of the twenty-six gate call sites that resolve `dhall` or `chromium` cannot distinguish "tool absent" from "tool present but out of range"; one catches the error and reports a named check | One shared shape: resolution failure is reported at a named check, with the requirement it failed | **The shape landed in Phase 1 on 2026-08-17**: resolution refuses in three named classes — nothing offered, nothing in range, and no asset for this architecture — each mapping to its own check id and each message naming the requirement it failed. Each later phase adopts it at its own call site as it reruns |
| ~~`tools/toolchain.py` has no seeded negative for any resolution failure; the six existing Phase-1 negatives all target the provenance scan~~. `pb/pb/bootstrap_toolchain.py` still has no test, mutant, or surface row | A negative per resolution failure class: absent tool, out-of-range version, and no asset for the host's architecture | **Closed for the resolver by Phase 1 on 2026-08-17.** Release and offer selection are pure functions the corpus drives directly, with two positive controls and one negative per class; each reddens its own check and no other. The pb resolver's own coverage stays with Phase 35 |
| The `windows` floor is authored but unexercised: `tools/toolchain.py` has no Windows branch, `pb` refuses anything but Linux on `amd64`, and `Ensure.hs` names a winget path that is not where winget lives | The plan for a substrate is decidable even where the interpreter is not built, and returns an explicit refusal rather than failing late | Phase 35. Closure: the plan is total over the four substrates, and Windows is refused by name rather than by crash |

The doctrinal silences this amendment closed — the Command Line Tools, the Linux package-manager root's
absence behaviour, `ensure incus`, `/dev/kvm`, the NVIDIA kernel driver, CDI, the accelerator device plugin,
winget's absence and elevation, the Windows optional features, and where the container engine is ensured —
were Phase 0's own, and [§S clause 5](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
forbids deferring a finding out of its owning phase, so they closed in the same change rather than taking
rows here.

---

## Phase re-baseline — 2026-08-17

[§E](development_plan_phase_model.md#e-one-canonical-phase-model) admits a re-baseline only when the same
change records **every** old phase as `old id/path -> new id/path(s)`, updates every inbound link, and leaves
no stale old-number reference. The 2026-08-16 map recorded only the *changed ranges*, and seven ordinals
survived it; this one is exhaustive, and the `f5` check now fails on the class of defect that produced them.

Three phases are inserted and four move bands. The rest shift. What the re-baseline answers:

- **The artifact layer was inverted.** Every one of 876 deferred findings was owned by a phase 32 or later,
  because the allowlist attributed each shared-surface finding to the *last* phase that needed it. That is
  right for a deletion and wrong for a relocation, and it left nine pre-cluster phases specified against paths
  the target tree forbids. New Phase 2 owns the relocations; the deletions stay with their last consumer.
- **A re-baseline was unaffordable.** [§U](development_plan_gate_integrity.md#u-the-final-repository-layout)
  clause 3 makes one cheap on the premise that no path outside this plan suite names an ordinal — and rule
  `r15` deferred exactly that violation across 34 rows, one per phase 32 through 65. The de-phasing that makes
  a re-baseline safe was owned by the phases being re-baselined. New Phase 2 breaks that cycle.
- **The DSL was not fully validated before live.** TLA+ proved a throwaway model and `IOSim` a toy reconcile
  loop; neither instrument was ever pointed at the DSL. New Phases 11 and 12 do that, and the reconcile
  algorithm's only proof claim — sibling evidence from prodbox — becomes an amoebius result.
- **Two pure phases sat behind 36 live ones**, and specialized-hardware islands gated the linux-cpu chain at
  two points. Both are corrected below. A developer with one `linux-cpu/amd64` machine and a cloud account now
  runs 0 through 64 contiguously; before, the chain halted at old 25.

**Order of operations.** The tree does not move in this change. This is the documentation act; Phase 2's gate
is the tree act, and it follows — because a re-baseline is documentation-only once no path names a phase.
Until Phase 2 runs, every phase document naming an ordinal-bearing authored path is a divergence this table
owns, not a defect in that phase.

| new id | new path | old id | old path | why it moved |
|---|---|---|---|---|
| 0 | `phase_00_documentation_suite.md` | 0 | `phase_00_documentation_suite.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 1 | `phase_01_toolchain_spike.md` | 1 | `phase_01_toolchain_spike.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 2 | [`phase_02_repository_layout_conformance.md`](phase_02_repository_layout_conformance.md) | — (new) | — | **new.** A whole-tree closure predicate had no satisfiable owner: four register rows quantify over the entire tree and name a distributed owner, which [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 5 forbids |
| 3 | `phase_09_formal_model_kernel.md` | 2 | `phase_09_formal_model_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 4 | `phase_10_gateway_migration_model.md` | 3 | `phase_10_gateway_migration_model.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 5 | `phase_11_dhall_typecheck_schema.md` | 4 | `phase_11_dhall_typecheck_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 6 | `phase_12_gadt_decode_ir.md` | 5 | `phase_12_gadt_decode_ir.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 7 | `phase_13_illegal_state_corpus.md` | 6 | `phase_13_illegal_state_corpus.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 8 | `phase_14_capacity_core_folds.md` | 7 | `phase_14_capacity_core_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 9 | `phase_15_storage_geometry_folds.md` | 8 | `phase_15_storage_geometry_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 10 | `phase_16_execution_accelerator_folds.md` | 9 | `phase_16_execution_accelerator_folds.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 11 | `phase_17_capability_bind.md` | 10 | `phase_17_capability_bind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 12 | `phase_18_provision_seal.md` | 11 | `phase_18_provision_seal.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 13 | `phase_19_inference_accelerator_provision.md` | 12 | `phase_19_inference_accelerator_provision.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 14 | `phase_20_render_manifest_goldens.md` | 13 | `phase_20_render_manifest_goldens.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 15 | `phase_21_chain_kernel_boundary.md` | 14 | `phase_21_chain_kernel_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 16 | `phase_22_deterministic_sim_substrate.md` | 15 | `phase_22_deterministic_sim_substrate.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 17 | [`phase_23_dsl_formal_model.md`](phase_23_dsl_formal_model.md) | — (new) | — | **new.** The model kernel and the one cross-cluster obligation left the DSL itself model-checked by nothing |
| 18 | [`phase_24_reconcile_core_simulation.md`](phase_24_reconcile_core_simulation.md) | — (new) | — | **new.** The simulation substrate had no amoebius-owned subject before the live band; the reconciler was first simulated inside the same phase as its live gate |
| 19 | `phase_25_ui_program_schema.md` | 16 | `phase_25_ui_program_schema.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 20 | `phase_26_scoped_identity_kernel.md` | 17 | `phase_26_scoped_identity_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 21 | `phase_27_ui_authorization_kernel.md` | 18 | `phase_27_ui_authorization_kernel.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 22 | `phase_28_ui_effect_binding.md` | 19 | `phase_28_ui_effect_binding.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 23 | `phase_29_ui_plan_compiler.md` | 20 | `phase_29_ui_plan_compiler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 24 | `phase_30_offline_language_plan.md` | 60 | `phase_30_offline_language_plan.md` | Register 1, substrate `none` — pure UI offline language work stranded behind 36 Register-3 phases |
| 25 | `phase_31_ui_browser_interpreter.md` | 21 | `phase_31_ui_browser_interpreter.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 26 | `phase_32_ui_server_boundary.md` | 22 | `phase_32_ui_server_boundary.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 27 | `phase_33_ui_local_composition.md` | 23 | `phase_33_ui_local_composition.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 28 | `phase_34_encrypted_browser_runtime.md` | 61 | `phase_34_encrypted_browser_runtime.md` | Register 2, substrate `none` — browser runtime work stranded behind the live band |
| 29 | `phase_35_bootstrap_coordinator_kind.md` | 24 | `phase_35_bootstrap_coordinator_kind.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 30 | `phase_36_base_image_registry.md` | 25 | `phase_36_base_image_registry.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 31 | `phase_37_object_reconciler.md` | 27 | `phase_37_object_reconciler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 32 | `phase_38_capacity_scheduler.md` | 28 | `phase_38_capacity_scheduler.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 33 | `phase_39_retained_storage.md` | 29 | `phase_39_retained_storage.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 34 | `phase_40_vault_pki.md` | 30 | `phase_40_vault_pki.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 35 | `phase_41_platform_backbone.md` | 31 | `phase_41_platform_backbone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 36 | `phase_42_platform_services_2.md` | 32 | `phase_42_platform_services_2.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 37 | `phase_43_keycloak_ingress.md` | 33 | `phase_43_keycloak_ingress.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 38 | `phase_44_live_dsl_deploy.md` | 34 | `phase_44_live_dsl_deploy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 39 | `phase_45_app_tenancy.md` | 35 | `phase_45_app_tenancy.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 40 | `phase_46_pulsar_client.md` | 36 | `phase_46_pulsar_client.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 41 | `phase_47_user_tenant_isolation_live.md` | 37 | `phase_47_user_tenant_isolation_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 42 | `phase_48_content_store_workflow.md` | 38 | `phase_48_content_store_workflow.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 43 | `phase_49_ui_projection_runtime.md` | 39 | `phase_49_ui_projection_runtime.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 44 | `phase_50_release_lifecycle.md` | 40 | `phase_50_release_lifecycle.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 45 | `phase_51_ui_program_release.md` | 41 | `phase_51_ui_program_release.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 46 | `phase_52_network_fabric_wireguard.md` | 42 | `phase_52_network_fabric_wireguard.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 47 | `phase_53_multicluster_spawn_georepl.md` | 43 | `phase_53_multicluster_spawn_georepl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 48 | `phase_54_gateway_migration_drills.md` | 44 | `phase_54_gateway_migration_drills.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 49 | `phase_55_provider_deploy_checkpoint.md` | 45 | `phase_55_provider_deploy_checkpoint.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 50 | `phase_56_provider_child_bringup.md` | 46 | `phase_56_provider_child_bringup.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 51 | `phase_57_provider_ebs_credential.md` | 47 | `phase_57_provider_ebs_credential.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 52 | `phase_58_provider_dynamic_nodes.md` | 48 | `phase_58_provider_dynamic_nodes.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 53 | `phase_59_determinism_jitcache.md` | 49 | `phase_59_determinism_jitcache.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 54 | `phase_60_infernix_lift.md` | 50 | `phase_60_infernix_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 55 | `phase_61_infernix_ui_lift.md` | 51 | `phase_61_infernix_ui_lift.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 56 | `phase_62_test_topology_dsl.md` | 55 | `phase_62_test_topology_dsl.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 57 | `phase_63_ui_single_tenant_live.md` | 56 | `phase_63_ui_single_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 58 | `phase_64_ui_multi_tenant_live.md` | 57 | `phase_64_ui_multi_tenant_live.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 59 | `phase_65_ui_rollout_reconnect.md` | 58 | `phase_65_ui_rollout_reconnect.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 60 | `phase_66_ui_ha_multizone.md` | 59 | `phase_66_ui_ha_multizone.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 61 | `phase_67_offline_replay_receipts.md` | 62 | `phase_67_offline_replay_receipts.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 62 | `phase_68_offline_blobs_isolation.md` | 63 | `phase_68_offline_blobs_isolation.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 63 | `phase_69_offline_release_evolution.md` | 64 | `phase_69_offline_release_evolution.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 64 | `phase_70_offline_multizone_continuity.md` | 65 | `phase_70_offline_multizone_continuity.md` | shift only — displaced by an inserted phase or by a moved neighbour |
| 65 | `phase_71_jitml_lift_cuda.md` | 52 | `phase_71_jitml_lift_cuda.md` | `linux-cuda` island interrupting the linux-cpu chain; moved to the specialized tail, grouped by machine |
| 66 | `phase_72_jitml_ui_lift.md` | 53 | `phase_72_jitml_ui_lift.md` | `linux-cuda` island interrupting the linux-cpu chain; moved to the specialized tail, grouped by machine |
| 67 | `phase_73_complementary_arch_child.md` | 26 | `phase_73_complementary_arch_child.md` | `apple` island at old 26 blocking 39 downstream linux-cpu phases; moved to the specialized tail |
| 68 | `phase_74_apple_metal_host_daemon.md` | 54 | `phase_74_apple_metal_host_daemon.md` | `apple`/`metal` island interrupting the linux-cpu chain; moved to the specialized tail |

**Rejected, with reason** ([§T](development_plan_gate_integrity.md#t-plan-to-implementation-reconciliation)
clause 5). The proposal recorded elsewhere in this register to move the third-party bake into the pre-cluster
band is **not adopted**. A BuildKit bake needs a container engine and a detected natural architecture, so it
is neither substrate `none` nor Register 1/2 and cannot enter the DSL-validation band without breaking the
register cut that band exists to hold. The bake stays with the native base image in the live sequence. That
row's *second* sentence — that a re-baseline follows the de-phasing — is adopted verbatim as this one's order
of operations.

**Still open after this change.** Phase 73's gate command names `tools/complementary_arch_gate.py`, which does
not exist; it is the only phase in the suite naming a gate tool the tree does not have. The 2026-08-18 doctrine
pass renamed it from `tools/attested_index_gate.py` when the attested-index join was retracted with the
manifest list, so the missing tool now at least names what the phase does. Owner: Phase 73. Closure: the gate
runs to a verdict.

---

## One binary, many roles — 2026-08-17

The role a running copy holds is a **decoded value** carried by the frame config, not the identity of the
executable that runs
([`daemon_topology_doctrine.md` §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid),
which owns the closed `Process` union). The tree still says otherwise in a handful of places, and says the
union itself three different ways. Each divergence takes a row with an owner and a closure condition, per
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

| Existing observation | Required replacement | Owner and closure |
|---|---|---|
| `amoebius.cabal` declares two executables, `amoebius` at `:900` and `amoebius-singleton` at `:933`, where doctrine admits one. `app/singleton/Main.hs` parses no arguments at all, because the executable's identity *is* the role selection; it also hard-codes phase-ordinal paths (`/phase33-artifacts/`, `/phase33-dhall/`, six `phase32-`/`phase33-` object names) and `ControlPlane/Daemon.hs:138` mints the field manager `amoebius-phase33-singleton` | One executable whose role arrives decoded. The control-plane daemon branch becomes an arm of the dispatch, and neither a path nor a field manager carries a phase ordinal | Phase 44. Closure: `amoebius.cabal` declares one `executable` stanza, `app/singleton/` is gone, and no phase ordinal appears in a runtime path or a field-manager identity |
| `infernix/infernix-lift.cabal:61` declares `executable phase49-native-driver` — a gate driver rather than a runtime role, and phase-ordinal-named besides | A gate driver is not a role and needs no role-shaped home; whatever it must remain, it is named for what it does | Phase 60. Closure: no executable in the tree carries a phase ordinal, and the driver is reachable without a second role-shaped binary |
| The role union is written three times and no two agree: `dhall/amoebius/Image.dhall:43-46` gives an anonymous inline `ControlPlaneDaemon \| Scheduler \| Worker \| HostDaemon` with an unparameterised `Worker` and a `Text` binary field, while both doctrine statements give three arms with `Worker` carrying its kind. Because the union is inline, `union_arms` cannot resolve it, so **no gate pins its arms today** | One `dhall/amoebius/Role.dhall` the other schema modules import, named so `arm_inventory.csv` can pin it | Phase 12 for the decode, Phase 11 for the schema module and its arm rows. Closure: one declaration, its arms pinned in `arm_inventory.csv`, and a closedness negative per union |
| `FrameConfig` is named by doctrine as the second Dhall authority surface and the carrier the role arrives on, and it exists in no `.dhall`, no `.hs`, and — until this change — no phase deliverable | The carrier is a decoded value with a schema, a decoder, and a witness | Phase 35, which owns the `BinaryContext` triple it extends. Closure: an `amoebius.dhall` schema, a total decoder, and a role field no running copy can hold two of |
| `src/Amoebius/Host/Context.hs:37` gives `contextKind :: AbsExe` — the resolved path of the `kind` tool — colliding with the doctrine's frame-config sense of context. Five call sites in `Cluster/Kind.hs` read it | One of the two names changes, so a reader cannot mistake a tool path for a frame's context | Phase 35, with the `FrameConfig` work. Closure: `contextKind` has one meaning in the tree |
| `test/golden/convergence_argv.txt:2` pins `tool=/usr/local/bin/amoebius-singleton` — a path no code produces, and a second executable the target tree does not have | The golden pins the one binary and the role it was handed | Phase 56, which owns the golden. Closure: no golden names a second amoebius executable |
| **Neither dhall-typecheck nor gadt-decode can run.** `tools/dhall_typecheck.py:21` resolves its oracle to `tests/oracle/dhall-typecheck`, and `tools/gadt_decode_ir_gate.py:55-57` to `tests/oracle/gadt-decode/{positive_trees,compile_pairs,decode_cases}.tsv`. Both halves are wrong: the tree has `test/`, not `tests/`, and the real homes are `test/oracle/dhall_typecheck_schema/` and `test/oracle/gadt_decode_ir/`. These are run-time reads, so both gates fail before their first check — independently of this amendment, and since before it | Each gate resolves its oracle from the path the tree actually has | Phase 11 for the first, Phase 12 for the second. Closure: each gate runs to a verdict, proven by the run. Their historical seals were recorded against paths that have since moved, so neither seal is re-usable as evidence until the gate runs again |

Two findings this amendment condemned were Phase 0's own and closed in the same change rather than taking
rows, per [§S clause 5](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate): the owning
doctrine contradicting its own union on `HostDaemon` and on `ContinuousTrainer`, and three citations sending
the reader to `resource_capacity_doctrine.md` for a type that document does not contain.

**gadt-decode's metrics are untouched.** Nothing in Haskell mirrors the role union today — zero occurrences of
`AmoebiusRole` or `ContainerProcess` across `.hs` — so the decode-foreclosure claim doctrine makes for the
role is an unmet design claim, not a regression this amendment introduces.

---

## Natural-architecture rebaseline — 2026-08-16

The amendment's predicate is
[development_plan_gate_integrity.md §S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
clause 15. What the amendment condemns is recorded here with an owner and a closure condition, per
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase). Every row's owner is the phase whose
gate must clear it, never a later one.

| Existing observation | Required replacement | Owner and closure |
|---|---|---|
| `tools/base_image_registry_build_products.py` extracts BuildKit's static QEMU binary, bind-mounts it as the container entrypoint, and compiles GHC and the pgAdmin closure under it — the file states outright that GHC does not cross-compile this closure | Each architecture's build products are produced on a host whose natural architecture is that one; no emulator is extracted, mounted, or executed | Phase 36 for its own architecture, Phase 73 for the complement. Closure: no emulator extraction path in the tree, and a kernel-read `binfmt_misc` table unchanged across each gate run |
| `tools/base_image_registry_source_probe.py` and `tools/base_image_registry_live_build.py` require an `--emulator` argument and probe the non-native architecture through it | Probes execute natively only, and the tool has no emulator parameter to supply | Phase 36. Closure: neither tool accepts an emulator argument, and every probe's recorded platform equals the host's natural architecture |
| `src/Amoebius/Image/BuildRuntime.hs` hard-codes `--platform linux/amd64,linux/arm64` in the emitted `buildx` argv | The platform argument is the host's natural architecture, resolved from detection rather than a literal pair | Phase 36. Closure: no multi-platform literal in the emitted argv, and the argv oracle pins one platform |
| `src/Amoebius/Image/BakeInventory.hs` rejects any stage whose platform set is not exactly `{Amd64, Arm64}` (`CatalogPlatformSetIncomplete`, at three loci), so a single-architecture catalog is a decode error | The catalog decodes for one architecture at a time, and the two-architecture obligation moves to the index join | Phase 36. Closure: a single-platform catalog decodes, and the joined index is what carries the both-architectures requirement |
| `dhall/amoebius/BakeCatalog.dhall` sets `platforms = both` on every stage and `architectureConcurrency = 2`; `dhall/amoebius/Image.dhall` carries `archConcurrency` on `BuildExecutionEnvelope` | A stage names the architecture being built; the envelope carries stage concurrency only, because there is no second architecture to expand within one build | Phases 17 and 19 for the dhall-typecheck/gadt-decode schema, Phase 36 for the catalog value. Closure: no `archConcurrency` field in the schema and no `both` platform literal in the catalog |
| `src/Amoebius/Host/Substrate.hs` computes `NormalArch` during classification and then discards it; `supportsLinuxCpu _ = True` answers without reference to architecture, and the module does not export the type | Classification returns the substrate and its natural architecture, and the lane predicate is indexed by that architecture | Phase 35. Closure: `classify` returns the architecture, `NormalArch` is exported, and the detector's own test asserts the arch-indexed lane |
| `dhall/amoebius/Capability.dhall`'s `EngineRuntime.LinuxCpu` arm and `dhall/test/Topology.dhall`'s `Substrate` union carry no architecture, so a `.dhall` can select a CPU lane without naming one | Both carry the architecture, so an engine offering and a generated test topology are architecture-locked at the type level | Phases 73–69 for the capability arm, Phase 62 for the test topology. Closure: neither union admits a lane value without an architecture |
| Phase-36 fixtures and oracles pin two architectures: `Dockerfile.golden`'s `TARGETARCH` selectors, `builder_channels.json`'s `requiredPlatforms`, `base_image_registry_surfaces.tsv` rows `multi-arch-manifest-list` and `per-arch-official-file-execution`, `base_image_registry_sbom.py`'s `EXPECTED_PLATFORMS`, `base_image_registry_oci_probe.py`'s `EXPECTED_PLATFORMS`, and `base_image_registry_publication_gate.py`'s published-platform domain | Each is re-authored for one architecture, and the two-architecture expectations move to Phase 73's index oracle | Phase 36 for the single-architecture forms, Phase 73 for the index oracle. Closure: no Phase-36 fixture names a platform the gate does not build |
| `test/fixture/base_image_registry/haskell_arm64.Dockerfile` states that it produces its arm64 build product under `binfmt`/QEMU when the host is not arm64 | The arm64 builder image is used only on an arm64 host | Phase 73. Closure: the fixture asserts the host is already `aarch64` and carries no emulation clause |
| `dhall/jitml/package.dhall` encodes `universalLinuxCpu.availableOnEveryHardwareSubstrate = True` as data, with no architecture axis | The record carries the per-substrate natural architecture alongside the provider map | Phase 71. Closure: the value names an architecture per substrate |
| 468 paths outside the plan suite carry a phase ordinal — 72 under `tools/`, the rest under `test/mutant/` and `mutants/` — and the renumber below makes each name a phase it no longer belongs to | Each is renamed for the capability it implements, which [§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 already required | **Closed by Phase 2 on 2026-08-17.** 468 paths, 216 build flags, and 43 `main-is` values took the capability name derived from the owning phase's slug, read off the same pre-amendment join this register recorded; rule `r15` reports zero findings, and the only ordinal-bearing names left are the plan suite's own and the doc-lint corpus that tests them |
| Roughly 240 restatements across 71 documents say every hardware substrate supplies `linux-cpu` without naming an architecture | Each restatement names the natural architecture, or cites [substrate_doctrine.md §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule) instead of restating | Each document's owning phase, at its rerun. Closure: no governed document asserts the baseline without an architecture. The statements are under-specified rather than false, so they are deferred, not suppressed |
| The Phase-36 `Implementation` fields named `test/**/PhaseNN*.hs` modules; the plan now names the capability module while the files on disk keep their ordinal | The modules are renamed to the capability names the plan states | Each owning phase, at its rerun. Closure: no `Phase\d\d` module name in the tree |

**Audit map — the re-baseline [§E](development_plan_standards.md#e-one-canonical-phase-model) requires.** Old
Phase 25's two-architecture claim split; every phase at or above old 26 shifts by one. No phase document
changed its capability under the shift alone.

| Historical id and path | Current id and path |
|------------------------|---------------------|
| Phase 30 `phase_36_base_image_registry.md` (both architectures) | Phase 36 `phase_36_base_image_registry.md` (its substrate's architecture) + Phase 73 `phase_73_complementary_arch_child.md` (the complement and the index) |
| Phases 31–64 as they stood on 2026-08-16 | each shifted by one at that date; today's ordinal is the one the [2026-08-18 audit map](#the-audit-map) gives |
| The tracker's open tail row `65+` | `75+` |
| `dhall/examples/locus_registry.tsv` `owner_phase` values as they stood on 2026-08-16 | today's values, `Phase-11`…`Phase-54` |
| `tools/migration_allowlist.tsv` and `test/oracle/preimplementation_artifacts.tsv` owner columns | the post-amendment ordinal; each row's *path* keeps its pre-amendment one until the owning phase renames it |
| A pin a phase document cites as `test/**/phase_NN…` | the same artifact at `phase_(NN-1)…` on disk, resolved through this map and reported as a deferral until that phase renames it |

---

## Repository-containment rebaseline — 2026-08-15

This snapshot records implementation paths observed while adopting the hostbootstrap containment model. Host
cleanup may remove present bytes, containers, mounts, and volumes, but a row closes only when its owning gate
also removes the code path, proves the replacement, and catches a seeded recurrence.

**Host cleanup observation — 2026-08-15.** The active Phase-39 kind node, its anonymous volume, the Phase-36
BuildKit and Go-cache volumes, four loop-backed mounts, the idle kind network, `/var/lib/amoebius`, every
`/var/tmp/amoebius*` and `/tmp/amoebius*` path, `~/.amoebius`, `~/.local/share/amoebius`, project-derived
GHC/HIE and Kubernetes discovery caches, and amoebius-labelled editor log files were removed. The postflight
found no amoebius mount, loop device, container, volume, image, network, Incus instance, systemd unit, or
system path. Claude project-history directories and a live tmux session named for the checkout are
user-tool metadata rather than amoebius runtime/build state and were deliberately preserved.

| Existing observation | Required replacement | Owner and closure |
|---|---|---|
| Generated output, run bundles, tool acquisition, Cabal builds/stores, Node dependencies, and temporary files were spread across legacy roots; only `gen/**` and later-phase system-temp callers remain, while Phase-1 tool/build homes are closed | Route every reproducible, transient, and evidentiary byte to `.build/**`, including `.build/tmp/**` and `.build/evidence-store/**` | **Phase-0 classifier/observer and Phase-1 tool/build migration closed 2026-08-15.** Each later phase clears its own hard-coded output path before resealing. The r16 allowlist is the shrink-only ownership map |
| **Discovered 2026-08-16 by Phase 40.** The Phase-36 image baked Pulsar 4.0.6 but omitted Apache's separately published offloader archive; an `aws-s3` broker therefore exited before readiness with `No offloader found for driver 'aws-s3'` | The typed Phase-36 catalog acquires the publisher-checksummed companion archive, the OCI handoff contains the jcloud NAR on both architectures, and a seeded omission mutant goes red; phases 41–43 then consume the amended exact handoff in order | **Paused — Phase 36 live proof pending.** The implementation, dual-architecture bake, file oracle, omission mutant, and Sprint-31.1 receipt have passed. Sprint 36.2 stopped before its receipt, Sprints 25.3–25.4 did not run, and the dependent predecessor chain remains blocked |
| Phase-41 through Phase-43 live fixtures and drivers use `/var/tmp/amoebius-phase*` retained roots and host-global kind/Docker objects | Production retained state under `.data/storage/**`; each gate's live state under its exact `.test_data/**` root | Owning Phases 35–36; each closes only after its live gate preserves the intended durable witness, safely deletes test state, and leaves no external resource |
| Many gate scripts and tests use `tempfile`, `/tmp`, or `/var/tmp` without a repository-scoped temp parent | All temporary creation names `.build/tmp/**` for pure work or the run's `.test_data/**` root for live test state; no ambient fallback | Each owning phase in numerical order; Phase 0 supplies a whole-tree scanner and escaped-temp mutant |
| Test harnesses tag resources but do not yet implement exclusive `.test_data/**` ownership markers, production-root/config refusal, exact-path deletion, or changed-marker quarantine | Adopt the hostbootstrap create/own/delete discipline and fail before effects on production overlap | Phase 62 implements the general harness; earlier live phases implement the minimal same invariant in their phase gates |
| ~~Production did not prove that `test-secrets.dhall` is rejected and never copied~~; the elevated test harness does not yet prove its flagged authority and ordinary prompt-path use | Harness-only prompt automation through the ordinary prompt-to-Vault path; no plaintext in output/state/argv/env/log/context/attestation | **Closed for production by Phase 40 on 2026-08-16.** The boundary check and two seeded negatives reject production reads and every copy sink. Phase 62 still owns flagged test authority and harness use |
| ~~amoebius-created Docker containers, anonymous/named volumes, caches, and daemon data could coexist with unrelated projects in `/var/lib/docker/**`~~ | No amoebius resource in the host-global daemon; all project engine data and resource identities resolve below `.data/**` or `.test_data/**` | **Closed for the shared engine/build boundary by Phases 1–70 on 2026-08-16.** Phase 36 proved build/cache containment and empty postflight inventory; every later live phase inherits the same observer and must still close its own callers |

---

## Existing-code divergence snapshot — 2026-08-11

This snapshot applies
[development_plan_standards.md §T](development_plan_standards.md#t-plan-to-implementation-reconciliation) to
clean commit `c8870a2`, which matched `origin/master` at inspection. It separately covers 2,324 tracked paths,
8,884 ignored paths, a fresh-clone verifier run, all 54 reachable commits, and 10 unreachable local stash
commits. Searches included every repository root. Counts are diagnostics, not generated status, and must be
refreshed when a relevant path changes.

| Existing observation | Misalignment with intended plan | Owner and closure |
|---|---|---|
| A fresh clone cannot complete `python3 tools/doc_lint_verify.py`: ignored Phase-0 ledger/enumeration inputs, a Phase-62 ledger input, and the Phase-1 Supernova patch are absent. The run exits 1 and reports 353 diagnostics: 56 `b1`, 20 `c`, 118 `p3`, 43 `p5`, and 116 `p6` | A local pass that relies on ignored worktree state does not establish repository source closure; hard failures and advisory backlog must remain distinct | Phase 0 fixes the generated inputs and hard lint failures and dispositions advisory output; Phase 1 relocates the required patch; the command must pass against the source snapshot |
| `tools/doc_lint_verify.py` invokes the legacy ledger checker with `test/golden/phase_00_ledger.json` and `test/enumeration/phase_00_surfaces.txt` | The redesigned Phase-0 gate must generate both under `.build/` and externally attest the run | Phase 0: replace the inputs and make the current two-sided gate pass |
| `tools/ledger_lint.py` requires a repository-resident ledger filename, self-hash, and enumeration | The current doctrine forbids committed/generated ledgers, hashes, and enumerations in authored roots | Phase 0: validate the run-local schema and external binding instead |
| `tools/phase0_artifact_lint.py` still audits `test/phase0_oracle_manifest.tsv` under the old pin/exemption model; its complete ignore-pattern and bytecode-suppression slices are current, but complete provenance, write-guard, effective context, resolution, attestation, and terminology checks remain absent | The partial implementation cannot satisfy the complete Phase-0 gate contract even when its current checks pass | Phase 0: retain the ignore/bytecode policy checks and replace the remaining manifest model with the doctrine's classifier and generator registry |
| `test/phase0_oracle_manifest.tsv` names 487 unique paths. Git first records 485 beside their implementations in commit `c8870a2`; the other two are ignored ledger paths | Same-commit introduction does not establish independent oracle custody, and ignored paths cannot be committed provenance | Phase 0 classifies each row as independently reviewed source, regression fixture, or generated output; each owning phase reviews or replaces regressions |
| `tools/doc_lint_corpus/` tracks 421 paths: one builder, ten positive seeds, and 410 negative copies recreated by the builder; the tree occupies 1,719,147 bytes | The negative copies are reproducible test input, not authored source | Phase 0 keeps the builder, positive seeds, mutation definitions, and expected diagnostics; negatives materialize beneath `.build/test-corpora/**` |
| phases 1–70 each have a primary phase-gate script plus test/auxiliary and generated-evidence footprints; Phase 0 has several component linters but no current unified implementation | Footprint is not semantic completeness, numeric-order permission, or current validation | Phase 0 first; then each phase revalidates in order |
| 167 tracked files reference `DEVELOPMENT_PLAN/evidence`; 27 reference `DEVELOPMENT_PLAN/ledgers`; 64 reference `test/enumeration`; 67 reference a phase-ledger JSON path | Gates and tests are coupled to generated material in authored roots | Phase 0 supplies the run-local framework; phases 27–70 migrate their consumers |
| **Discovered 2026-08-12 by the Phase-15 surface join.** The Phase-15 contract names 27 storage claims and `test/oracle/storage_geometry/storage_cases.tsv` carries 27 cases, but the two vocabularies were authored separately and never reconciled. 24 pairs match by name; three do not: `complete-failure-scenarios` was joined to `object-count-quota`, `backing-allocation-rounding` to `root-ebs-quota`, and `pulsar-hot-tier-ceiling` to `incluster-cache-emptydir` | A surface-to-case association that nobody reviewed is not independent evidence, and the alternative — pointing twenty surfaces at one acceptance token — is worse, because it reads as twenty independent results | Phase 15: confirm or correct the three provisional associations, or rename the cases to match the contract vocabulary |
| **Discovered 2026-08-12 by the Phase-16 surface join.** Five surfaces named in the Phase-16 contract — `accelerator-interconnect`, `build-execution-envelope`, `engine-system-reserve`, `monitoring-work-budget`, and `pulumi-execution-envelope` — have no oracle case, no seeded mutant, and no recorded metric of their own. The battery's 32 variants and 45 mutants partition cleanly across the phase's other 37 claim surfaces, leaving these five with nothing that measures them | A contract surface with no recorded observation cannot be reported `tested`. The pre-amendment ledger listed all five as tested by naming them in a hand-maintained set, which is an assertion rather than evidence | Phase 16: give each of the five an oracle case, a mutant, or a metric, or remove it from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-12 by the Phase-17 surface join.** Five surfaces named in the Phase-17 contract — `controller-child-source-expansion`, `unresolved-transition-references`, `registry-storage-bound-intent`, `extension-totality`, and `phase10-validation-locus-ledger` — have no oracle case, no seeded mutant, and no recorded metric of their own | Same class as the Phase-16 finding: the pre-amendment ledger reported them tested by naming them in a hand-maintained set | Phase 17: give each an oracle case, a mutant, or a metric, or remove it from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-12 by the Phase-18 surface join.** Six surfaces named in the Phase-18 contract — `creation-provider-action-batch`, `plan-token-replay-rejection`, `action-token-replay-rejection`, `receipt-bound-materialization-readback`, `promised-identity-rejection`, and `phase11-validation-locus-ledger` — have no oracle case, no seeded mutant, and no recorded metric of their own | Same class as the Phase-16 and Phase-17 findings: the pre-amendment ledger reported them tested by naming them in a hand-maintained set | Phase 18: give each an oracle case, a mutant, or a metric, or remove it from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-12 by the Phase-19 surface join.** Two surfaces named in the Phase-19 contract — `opaque-provisioned-engine-accelerator` and `phase12-validation-locus-ledger` — have no oracle case, no seeded mutant, and no recorded metric of their own | Same class as the Phase-16 through Phase-18 findings | Phase 19: give each an oracle case, a mutant, or a metric, or remove it from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-12 by the Phase-20 surface join.** Seven surfaces named in the Phase-20 contract — `aeson-round-trip`, `sealed-render-source-domain`, `deterministic-identity-order`, `exact-source-identity-projection`, `closed-reconcile-mode`, `default-deny-network-policy`, and `phase13-validation-locus-ledger` — have no corpus row, no seeded mutant, and no recorded metric of their own. Two others, `sole-public-render-facade` and `phase13-compile-totality`, did have real source checks behind them and are now joined to those checks explicitly | Same class as the Phase-16 through Phase-19 findings: the pre-amendment ledger reported all nine tested by naming them in a hand-maintained set | Phase 20: give the seven an oracle row, a mutant, or a metric, or remove them from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-12 by the Phase-21 gate.** Thirteen surfaces named in the Phase-21 contract — `counted-step-run`, `step-nfdata-excludes-action`, `whole-provisioned-plan-config`, `pure-chain-builder`, `identity-disjoint-step-projections`, `render-all-object-union`, `four-frame-activation-projection`, `pure-next-frame-after`, `pure-fold-lift`, `canonical-render-chain-plan`, `zero-step-run-render`, `exact-applied-bytes`, and `hostile-path-canary` — have no locus entry, no mutant, and no metric of their own. Separately, the whole-tree subprocess-primitive-site inventory had drifted: `Image/Build.hs`, `Image/BuildRuntime.hs`, and `Image/Publish.hs` reach the primitive and were not in the declared set | A contract surface with no recorded observation cannot be reported tested. The site inventory is a whole-tree invariant, so its declared list must name every legitimate site, including later phases' | Phase 21: give the thirteen an oracle entry, a mutant, or a metric, or remove them from the enumeration. The site list is amended with the three Phase-36 image modules and the reason recorded beside it; the check stays exact |
| **Discovered 2026-08-13 by the Phase-26 surface join.** Three surfaces named in the Phase-26 contract — `tenant-flow-preservation`, `cycle-diagnostic`, and `missing-member-diagnostic` — have no pinned row, no seeded mutant, and no recorded metric of their own. `Amoebius.Ui.Security.Flow` declares `TenantFlowMismatch`, a cycle diagnostic, and `MissingFlowMember`, but the committed four-row flow matrix decides audience widening, integrity elevation, and one transitive leak and nothing else | Same class as the Phase-16 through Phase-21 findings: the pre-amendment ledger reported all three tested by naming them in a hand-maintained set. A declared error constructor no case constructs is an unexercised branch, not a tested one | Phase 26: extend the independently authored flow matrix with a tenant-mismatch row, a cyclic graph, and a graph missing a named member, or remove the three from the enumeration. Until then the ledger carries them UNVERIFIED |
| **Discovered 2026-08-13 by the Phase-26 gate.** `tools/scoped_identity_gate.py` invoked `cabal exec ghc` without the resolved compiler, so on a host whose default GHC is newer than the authored range the compile-fail battery could not resolve `base` and reported `compile-fail locus drifted` | A toolchain mismatch reported as a capability regression sends the reader to the wrong file. Phase 14 established that every cabal invocation carries `--with-compiler` | Closed 2026-08-13. The gate resolves `ghc` per run and injects it into every cabal call; the same defect in Phases 11 and 12 is deferred to each owning phase |
| **Discovered 2026-08-13 by the Phase-32 surface join.** One surface named in the Phase-32 contract — `unreferenced-handler-unreachable` — has no oracle row, no mutant, and no metric of its own. `admitServerPlan` ignores linked handlers the plan never references, which is what lets one binary serve more than one plan, but `startup_plan_matrix.tsv` varies only the count of the *referenced* identity | Same class as the Phase-16 through Phase-26 findings: an implemented property with nothing measuring it cannot be reported tested | Phase 32: add a startup row that links a handler the plan never references and requires readiness anyway, or remove the surface. Until then the ledger carries it UNVERIFIED |
| **Discovered 2026-08-13 while reviewing the sibling hostbootstrap secrets policy; closed 2026-08-13 by Phases 11 and 12.** [`vault_pki_doctrine.md` §3](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) names the shared `SecretRef` union and the gates that admit it. `src/Amoebius/Vault/SecretRef.hs` implemented `Vault` and `TransitKey` only — no `Prompt`, no rejection of a literal — and no `SecretRef` existed under `dhall/amoebius/**` at all. `dhall/amoebius/SecretRef.dhall` now carries the three-arm union with its arms pinned in the dhall-typecheck arm-inventory oracle, the Haskell type carries the `Prompt` arm, and the decoder refines every sensitive field into that one shared type, returning `PlaintextSecret` for a value | Without the `Prompt` arm there is no typed home for prompt-supplied elevated material, and without the dhall-typecheck union plus the gadt-decode rejection, "a config that decodes carries no secret" is doctrine rather than mechanism. A scanner cannot substitute: it runs after authoring and cannot tell a live key from a fixture | **Closed by Phase-0/1 for type/decoder admission and Phase 40 for use on 2026-08-16.** The union belongs to dhall-typecheck and literal rejection to gadt-decode; Phase 40 now consumes it through the sealed prompt write, presence check, and direct-client paths |
| **Discovered 2026-08-13.** `dhall/test/TestCredential.dhall` types its credential as `{ secretRef : Text, testSimulation : Bool }`, and `src/Amoebius/Test/Credentials.hs` wraps a bare `Text` in its own local `SecretRef` newtype unrelated to `Amoebius.Vault.SecretRef` | A `Text` field is exactly the shape the type-level rule exists to forbid: a plaintext credential typechecks there. Two unrelated types named `SecretRef` also mean the production validator cannot see the test one | Phase 62 narrows the test-topology credential onto the shared `SecretRef`, keeping the existing flagged-test-simulation requirement |
| **Recorded 2026-08-13.** No `test-secrets.dhall` seam existed, and neither ignore contract covered one | The sanctioned cleartext file must be unable to reach a commit or a build context before it exists, not after someone creates it | Closed for the ignore half: `/test-secrets.dhall` is in `.gitignore` and `.dockerignore` as of 2026-08-13, and [`vault_pki_doctrine.md` §3.3](../documents/engineering/vault_pki_doctrine.md#33-the-test-secrets-seam-the-operators-prompt-automated) specifies the seam. The file itself is authored by the operator when a live provider gate is first run |
| **Recorded 2026-08-13 (monocontainer conformance).** `dhall/amoebius/BakeCatalog.dhall` offers only `CopyOci` and `BuildProduct`, so the rendered Dockerfile is 23 `FROM` stages of public images with zero `apt-get`, on an `nvidia/cuda:…-devel-ubuntu24.04` base; the Postgres step hand-copies `libxml2` and `libgssapi_krb5` out of the upstream image | [`image_build_doctrine.md` §2](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) says amoebius does not pull public images for platform services and prefers apt, then an official tarball, then source. With no arm for the upper rungs the ladder is advice the type cannot express, and extraction transfers each upstream image's shared-library closure into amoebius's hands permanently | Closed 2026-08-14 by the Phase-36 seal. The catalog carries `AptPackage`, `OfficialArtifact` with publisher-resolved checksums, `BuildProduct`, and `CopyOci` as a last resort that must record its reason; all 22 baked binaries sit on a rung above scavenging, so the rendered file has one `FROM` on plain `ubuntu:24.04`, the 35 hand-maintained `supportCopies` entries are gone, and the accelerator toolchain is confined to the `linux-cuda` lane at Phase 61. The gate's `ladder` side re-decides all three claims every run and a seeded mutant that substitutes a scavenge step for an available apt rung goes red |
| **Discovered 2026-08-13 by the Phase-35 migration.** The gate required a `live-*` evidence battery — `live-split-runtime-boundary.tsv`, `live-split-runtime-readback.tsv`, `live-etcd-transition-highwater.tsv`, `live-audit-system-log-highwater.tsv`, and six more — that **no tool in the repository writes**. It also had no committed surface enumeration and no ledger, so it could not derive a ledger at all. Seeded mutant M6 read one of those leftovers | A gate that verifies files an earlier run left behind certifies whoever wrote them last, not the run in progress. Clause 9 makes an ignored worktree file never an input | Closed 2026-08-14. Every metric is measured from evidence the run produces into `.build/runs/phase_29/<run-id>/`, M6 no longer reads a leftover, and a check fails if the retired directory reappears. The SplitRuntime gap is closed too: the pristine run prepares two loop-backed filesystems and brings the cluster up a second time on that layout once the Unified lifecycle is swept, so the kubelet's nodefs and containerd's shared content/snapshot root report distinct identities and M6's swap is decidable. Fixing that surfaced a defect worth recording — the M6 observer's third clause duplicated its first and so could never fire, meaning the mutant would have gone green on a check incapable of failing; it now applies the swapped mapping and requires a shared predicate to reject it |
| **Discovered 2026-08-13, immediately after commit `0526152` first tracked the phases 1–70 machinery; closed 2026-08-13.** The artifact-policy audit reported seven findings against its own seeded negatives — a developer-home compiler path and a synthetic package digest in the Phase-1 corpus, an invented output class and a plan-tree evidence path in the audit's own mutant set, and a second plan-tree evidence path in the attestation refusal corpus. All are synthetic inputs whose purpose is to make each rule fire | An audit that flags its own negative corpus reports a defect where the corpus is doing its job, and the finding is indistinguishable from a real one. The exemption mechanism existed but covered only the ledger corpus. The gap was unobservable while these files were untracked, because the scan keyed on the tracked tree | Closed by Phase 0, which owns the audit and its corpora and could not defer a finding it owns. [`repository_layout_doctrine.md` §3.6](../documents/engineering/repository_layout_doctrine.md#36-authored-negative-corpora-and-their-audit-scope) declares the corpora as one authored set with the rules each seeds; the audit parses that table, suppresses exactly those pairings, and reports a stale row at `r12`. The attestation refusal corpus moved into its own module so the adapter stays fully scanned, and every rule that asks what a build or gate reads now keys on the source snapshot rather than the tracked tree, so an uncommitted file is no longer invisible to it |
| 100 tracked files contain the observed developer-home prefix | Authored code and tests must resolve logical tools and workspace paths at run time | Phase 1 for shared resolution; each later owner removes inherited consumers |
| **Closed 2026-08-12 (Phase 1).** `cabal.project.freeze` is deleted, so cabal no longer silently re-freezes resolution; the solver graph is written per run to `.build/locks/phase_01/`. `package-lock.json` and `ui-runtime/spago.lock` remain ignored package-manager caches, never gate inputs | Lock/freeze and generated package-checksum files must resolve beneath `.build/` and cannot remain eligible for version control or the Docker context | Closed. Verified by the Phase-1 gate's twice-resolved and snapshot-closure sides |
| **Closed 2026-08-13 (Phase 26).** The twelve names `Amoebius.Ui.Server.Dispatch` did not define — `ActionRequest`, `BoundaryMutant`, `BoundaryResponse`, `HandlerBinding`, `HandlerContract`, `HandlerInvocation`, `UiServerAbi`, `admitServerPlan`, `authorizeAndDispatch`, `parseBoundaryMutant`, `publicResponse`, `unavailableResponse` — are implemented, and the entry point moved to `app/amoebius/Amoebius/Ui/Server/Main.hs` so the executable no longer searches `src` | The UI-server boundary ABI was an unimplemented seam, not a compile-order accident. Separately, `hs-source-dirs: src` on the executable made GHC recompile the shared core into that component against its own shorter `build-depends`, so the build failed on `Amoebius.Vault.SecretRef`, a module the executable never mentions | Closed by [phase_32](phase_32_ui_server_boundary.md). `exe:amoebius` builds, the gate passes on all twelve sides, and an `entry-point-outside-shared-core` check fails if the entry point returns to the shared tree or the executable's search path grows past `app` |
| No Python bytecode is tracked at `c8870a2`; three paths and five bytecode blob versions remain in reachable history | Current ignore policy is satisfied, while old generated blobs require an explicit history disposition | Phase 0: retain current-tree enforcement and record the non-secret forward-cleanup/history-retention decision |
| Tracked `notes.txt` contains 74 lines but has no governed-document classification | Every tracked file must be authored source/policy, reviewed external input, or an independently authored fixture; unclassified migration notes cannot remain a fourth class | Phase 0: route unique intent into governed Markdown and delete the text file, or classify and rename it as an authored governed document |
| 64 phase evidence directories, 20 ledger Markdown files, 66 phase-ledger JSON files, and 65 enumeration files exist as ignored worktree material | Generated projections and run records belong under `.build/` or repository-local evidence. The 20 Markdown ledgers also contain unique human reasoning that must not be discarded | Phase 0 migrates unique reasoning into owning phase documents before deleting old ledgers; Phases 35 and 42 migrate generated consumers |
| Phase evidence contains 132 JSON, 128 TSV, 128 log, 44 text, 2 YAML, 2 patch, 2 generated Haskell, 1 compressed archive, and 1 extensionless checksum-list file | File extension does not establish provenance; authored patches are incorrectly mixed with generated evidence | Phase 0 classifies every artifact; Phase 1 relocates reviewed patch inputs and regenerates bindings |
| **Closed 2026-08-12 (Phase 1).** The Supernova patch is now tracked at `patches/supernova_ghc_9_12.patch` with non-SHA upstream provenance and applies into the run-local checkout only; the `dual` patch was superseded by the already-vendored source and is deleted, with `vendor/dual/PROVENANCE.md` recording that package's provenance | Authored source cannot live under an ignored evidence root, and the source snapshot cannot build with the required patch missing | Closed. The gate's `patch-under-authored-root` check and its seeded negative hold the property |
| The Phase-35 source module, error type, imports, tests, commands, plan filename, and links now use Bootstrap Coordinator terminology; current-tree case-insensitive scans are empty | The canonical component name is Bootstrap Coordinator, with `bootstrap_coordinator`/`BootstrapCoordinator` identifiers and no compatibility alias | Phase 35: retain the current-tree zero-result scan and rerun the current gate after generated-output migration |
| 64 generated phase-ledger JSON files and 40 generated evidence records retain historical bytecode-suppression command text | These are invalidated generated records, not executable policy or authored inputs; hand-editing them would create another snapshot | Phase 0 and each owning phase: discard them during migration and emit fresh records beneath `.build/runs/**` with ordinary Python caching |
| Tests read generated phase evidence directly, and `cabal.project` consumes a patch beneath Phase-1 evidence | Authored tests/build inputs cannot depend on an evidence directory | Phase 1 and each affected phase: move authored inputs to authored roots; generate observations at run time |
| `.gitignore` and `.dockerignore` now cover the complete documented generated, evidence/ledger, enumeration, dependency-resolution, build/cache, runtime, credential, and Python-bytecode pattern set | Pattern coverage is implemented and seeded-negative checked; effective tracked-path, provenance, authored-write, and Docker-context audits are still incomplete | Phase 0: retain pattern enforcement and implement the remaining semantic/context guards |
| Zero tracked paths match the current `.gitignore`, yet semantically derived files remain tracked | Ignore-pattern agreement cannot detect generated files placed in authored-looking paths | Phase 0: add content/generator provenance classification and seeded negatives for misleading paths |
| The repository tracks 163 TSV files, including expected hashes/digests/traces and copied inventories whose provenance is unresolved | TSV is a format, not an authored-source class | Phase 0 classifies shared tables; each owning phase independently reviews an expectation or moves its generation under `.build/**` |
| Phase 60 tracks `frozen_sources.txt`, `expected_hashes.tsv`, and `sibling_golden.cbor`; the hashes reproduce sibling `../infernix/src/**`, the gate hard-codes them, and the golden captures sibling output | Copied source inventory, digest table, and reference-program output are generated observations, not independent expectations | Phase 60: resolve and execute the reviewed sibling boundary dynamically, generate identity/reference observations per run, and remove hard-coded hashes |
| Phase 74 tracks `job_A.expected` and `job_B.expected`; both are exact output of `metal_job_ref.py` on the tracked inputs | Reference-program output must be generated at run time | Phase 74: retain the independent program and authored job inputs, generate expected results beneath the run bundle, and redesign the replay mutant |
| **Phase-1 half closed 2026-08-12.** `toolchain/pins.json` is deleted and `cabal.project` carries no path, revision, or frozen index snapshot. `pb/bootstrap_execution_envelope.json` and `test/fixture/phase31/postgres-share-package.sha256` still retain fixed resolution/integrity fields | Tracked source may state compatibility requirements, but not resolver output or package/archive integrity observations | Phase 41–43 split their domain envelopes and observations; the shared toolchain half is closed |
| Phase 51, 64, and 34–69 expected base-digest files and the Phase-48 canonical/noncanonical manifest and no-fault HEAD outputs are reproducible. UI/browser/offline digest and trace candidates remain under Phases 31, 41–43, 48, 51, 64, and 34–70. **Phase-31 half closed 2026-08-13:** `test/fixture/ui_browser/reference_traces.tsv` is deleted, its Phase-0 manifest row is removed, the suite derives the trace side from `ReferenceClientPlan.referenceTraces` at run time, and a `derived-trace-table-untracked` check fails any tracked fixture whose header names the trace columns. **Phase-29 half closed 2026-08-13:** `test/fixture/ui_plan_compiler/expected_digests.tsv` is deleted, its Phase-0 manifest row is removed, the suite derives the expected digests at run time by hashing the authored goldens with the independent adapter, and a `derived-digest-table-untracked` check fails any tracked fixture other than the four goldens that carries a `sha256:` literal | Reproducible observations must move to run bundles. A behavioral trace/table remains source only after independent review establishes that it was authored as an expectation | phases 55–58, 60–66, and 34–70: remove known copies, classify each named candidate, and review/replace or generate it at run time |
| **Discovered 2026-08-13 by the Phase-29 seal.** The four paired-plan goldens — `client_plan.golden.json`, `ui_server_plan.golden.json`, `public_contracts.golden.json`, and `content_manifest.golden.json` — were first committed alongside `src/Amoebius/Ui/Compile/**`, so Git establishes no chronology between fixture and subject | A byte-exact golden with no established chronology is a regression fixture, not an independent oracle ([development_plan_standards.md §M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 1). The goldens hold and the mutants prove the comparison has teeth; neither establishes that the intended output was authored before the observed one | Phase 29 owner: an independent reviewer validates or replaces the four goldens, or a reference renderer generates the canonical bytes at run time. No gate run can discharge this, so the Phase-29 seal records it open rather than absorbing it |
| The path/component audit records missing or substituted target seams, while phases 1–69 explicitly retain provider, specialized-hardware, production-runtime, cleanup, or multi-zone gaps | Existing code and the intended phase contracts are not yet aligned semantically | Follow [system_components.md](system_components.md#reconciliation-state) and close each owning phase in order |
| Reachable history contains the deleted bytecode blobs, the generated documentation-lint corpus from commit `2695482`, and 17 deltas plus four historical filenames using the retired Bootstrap Coordinator predecessor term. No secret, lock/freeze file, or other compiled binary was found | Current-tree cleanup cannot remove prior blobs; non-secret history needs an explicit retain-or-rewrite disposition | Phase 0 records the operator decision. Any rewrite requires explicit coordination; current work proceeds by forward cleanup |
| Ten unreachable local stash commits contain no detected secret and repeat only the known bytecode findings | Unreachable objects are local repository state, not shared reachable history | Phase 0 reports them separately; local cleanup remains an operator action and is not a gate mutation |

The implementation footprint is committed, clean, and pushed, but it is not policy-conformant. Nothing in this
snapshot closes a phase; it exists to make the migration path explicit and reviewable.

## Phase-0 closure disposition — 2026-08-12

This section refreshes the rows above that the Phase-0 implementation closed, and names the mechanism that
now carries the rest. It does not rewrite the dated snapshot: that remains the observation of record for
`c8870a2`.

| 2026-08-11 row | Verified disposition |
|---|---|
| The verifier could not complete without ignored inputs; 353 diagnostics | Closed. The gate is green on all nine sides, and its snapshot side re-lints the corpus from non-ignored source alone. The 56 `b1` and 20 `c` results were authored documents linking into `DEVELOPMENT_PLAN/ledgers/**` and `evidence/**`; the links are removed, the code spans retained as prose, and the lint no longer collects generated Markdown from the plan tree. `p3`/`p5`/`p6` stay advisory at 117/43/117 |
| The gate consumes `test/golden/phase_00_ledger.json` and `test/enumeration/phase_00_surfaces.txt` | Closed. The run enumerates its own surfaces into `.build/test-surfaces/phase_00.json`, joins them two-way to the authored `test/phase_00_surface_expectations.tsv`, and emits its ledger into `.build/runs/phase_00/<run-id>/ledger.json` |
| `ledger_lint.py` requires a repository-resident ledger filename and enumeration | Closed. It accepts a JSON enumeration and a run-bundle ledger path; the phase-named form survives only for the corpus |
| `tools/doc_lint_corpus/` tracks 410 reproducible negative copies | Closed. `_build.py` materializes all 41 negatives under `.build/test-corpora/doc_lint/`; the copies are deleted and the seeds, mutation list, and expected diagnostics remain source |
| `phase0_artifact_lint.py` lacks provenance, write-guard, context, resolution, attestation checks | Closed by `tools/artifact_policy.py` (eleven rules), `tools/artifact_policy_selftest.py` (one seeded negative each), and `tools/attestation.py` (write-once store plus refusal corpus). The manifest audit is retained for the oracle/mutant inventory |
| Two manifest rows name ignored Phase-62 ledger paths | Closed. Both rows are removed; a generated ledger is not a Phase-0 oracle |
| Non-secret generated and obsolete blobs in reachable history need a disposition | Closed as a decision, not a rewrite. `tools/history_disposition.tsv` records `retain-history` for the four superseded phase-document paths and the five bytecode blobs. No secret was found, and the audit fails closed if one appears |
| 167/27/64/67 tracked files reference generated roots; 100 carry the developer-home prefix | **Open, and now enforced.** Every occurrence is reported by rule `r5`, `r6`, or `r7` and deferred through `tools/migration_allowlist.tsv` to the phase that owns it — 392 findings across phases 1–70. A row that matches nothing fails the gate, so the backlog can only shrink |
| Doctrine documents cite sibling projects by developer-home path | Closed. The citations name the sibling repository and its relative path instead |
| Tracked `notes.txt` has no governed-document classification | Closed by deletion. Every entry already named the doctrine that absorbed it, and its one unresolved item — tenant promotion across a cluster boundary — is recorded open in [`migration_doctrine.md`](../documents/engineering/migration_doctrine.md) and [`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit). No unique intent was discarded, and the open item keeps its governed owner |

**The allowance mechanism, and why it exists.**
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate) clause 5
reads as a whole-tree condition on every gate, while
[repository_layout_doctrine.md §3.5](../documents/engineering/repository_layout_doctrine.md#35-tsv-inventory-and-provenance)
gives Phase 0 the shared corpora and each later phase its own domain tables, and
[§9](../documents/engineering/repository_layout_doctrine.md#9-migration-boundary) declares the present tree a
migration surface throughout. Under the whole-tree reading Phase 0 could close only after Phases 32 and 44 had
already migrated, which inverts the numeric order the plan is built on. The allowlist implements the §3.5
reading without weakening the gate: a deferred finding is still reported and still attributed, its owning
phase is named, its justification must exist in the migration table below, and a stale row is a hard failure.

---

## Layout and naming divergence snapshot — 2026-08-14

This snapshot applies [development_plan_standards.md §T](development_plan_standards.md#t-plan-to-implementation-reconciliation)
to the working tree on 2026-08-14, covering all 31 top-level roots, all tracked paths, the four authored ignore
surfaces, and the enforcement modules that audit them. The 2026-08-11 snapshot covered repository *shape* only
where a generated artifact was involved; this one covers shape and naming as such, against the target tree
[§U](development_plan_standards.md#u-the-final-repository-layout) now makes normative. Counts are dated
diagnostics, not status.

| Existing observation | Misalignment with intended plan | Owner and closure |
|---|---|---|
| 31 top-level roots hold tracked content against the 14 the target tree declares. `tools/artifact_policy.py` `AUTHORED_ROOTS` lists 30 names; nothing compares either list to the other or to the tree | A tree declared exhaustive that nothing compares against reality is prose, not a boundary. [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) has always said a new root needs an amendment first; with no check the amendment is optional in practice | Phase 0: derive `AUTHORED_ROOTS` from the [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) table or check them equal, and fail on a root present in one and absent from the other, with a seeded negative in each direction |
| Four roots contain only a package declaration whose library exposes no modules, with `hs-source-dirs` reaching `../src` and suites reaching `../test/**`. Their real payload is 72 build flags and suite groupings | A package boundary that buys no separate resolution is configuration wearing a directory. It also multiplies the test taxonomy: the same seven roles are instantiated once per package and drift apart | **Closed by Phase 2 on 2026-08-17.** All fourteen package roots are stanzas in `amoebius.cabal`; `cabal.project` names `amoebius`, `probe`, and `vendor/dual`, which are the two [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) grounds and the one authored package. `cabal build all --dry-run` and `cabal test all --dry-run` both resolve |
| Three further roots hold a package declaration plus one module that is a preprocessor `#include` of a file already in `src/`, added to break an import cycle | The cycle exists only because the split exists: an intra-package sub-library graph cannot cycle at the package level. The shim is the cost of a boundary that creates the problem it solves | Phases owning the sibling lifts: delete the shim, fold the package into `amoebius.cabal`. Closure: no tracked Haskell file whose body is an `#include` of another tracked Haskell file |
| Two package roots set `hs-source-dirs` to a path outside the repository, resolving to a sibling checkout that is not in the source snapshot | [§S](development_plan_standards.md#s-universal-artifact-hygiene-gate) clause 9 requires the snapshot to contain every authored input, and clause 3 of [§T](development_plan_standards.md#t-plan-to-implementation-reconciliation) makes an input that exists only because the worktree happens to hold it a missing-source finding. A relative path out of the tree is unresolvable from a clone that lacks it | The phases owning the sibling lifts: replace with a `source-repository-package` in `cabal.project`, the mechanism already used for the forked broker client. Closure: no `hs-source-dirs` escapes the repository root |
| Seeded mutants live under five roots in three record formats, and 162 further mutations are carried as build flags that no listing of any mutant directory can see | [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 2 makes the seeded mutant the instrument proving a check has teeth. An instrument stored five ways cannot be inventoried, and a second registry nothing enumerates is how a mutation quota is met on paper | **Closed by Phase 2 on 2026-08-17.** One root, one registry: `test/mutant/registry.tsv` carries all 411 mutations with capability, id, operator, expected locus, committed body, and build flag, and `tools/mutant_registry.py` is the one parser. 99 mutations that only a build flag reached are rows; the ten per-capability `mutants.tsv` files are gone. Each owning phase still re-runs its own battery, which is the behavioural half |
| `test/` carries `golden/` beside `goldens/`, `fixture/` beside `fixtures/`, `negative/` beside `negatives/`, and `ui/` beside `Ui/`; nine of its subdirectories hold exactly one file | A singular/plural pair is two names for one class, and it defeats every path-keyed audit written against either spelling. A directory holding one file names a category the tree does not have | **Closed by Phase 2 on 2026-08-17.** `test/`'s second level is exactly `fixture`, `golden`, `harness`, `mutant`, `negative`, `oracle`, `spec` over 1,084 files, and rule `r13` reports zero findings |
| `test/ui/` and `test/Ui/` differ only by case | Two of the four declared substrates reach the tree through a case-insensitive filesystem, so the two paths are one there: a checkout or a bulk move on such a host produces a corrupt tree, and no current check would say so | **Closed by Phase 2 on 2026-08-17.** The pair is one `test/spec/ui/`, and the collision check ran before any relocation sprint — over the *enumeration* rather than the disk, because the pair a case-insensitive filesystem cannot hold is exactly the pair the index can. Mutant m6 proves the check can fail |
| 468 tracked paths outside `DEVELOPMENT_PLAN/` carry a phase ordinal in four conventions, plus 90 build flags and 22 suite names that no path count reaches | [§U](development_plan_standards.md#u-the-final-repository-layout) clause 3: an ordinal in a path records ownership where no tool can check it, and it makes [§N](development_plan_standards.md#n-reopening-and-amending-a-phase) expensive enough to avoid. Two same-ordinal spec files in different packages already cover different subjects, and the ordinal distinguishes neither | Phase 0 defines the derivation from each phase document's slug and ships the detector; each phase renames its own paths in numeric order. Closure: no tracked path outside `DEVELOPMENT_PLAN/` matches a phase ordinal, and every gate's slug round-trips against its contract |
| The ordinal vocabulary "dhall-typecheck / gadt-decode / extension-astcheck" names three admission checks across the doctrine and plan suites, four tool filenames, seven directories, and roughly twenty identifiers | The ordinal on the third is not merely uninformative but false: it runs at build time over extension source, not at decode time over a spec, and the doctrine's own pipeline diagram draws it nowhere on that path. Six negative fixtures also record their locus in the filename while their siblings record it only in the case table, so the same fact is authored twice and can disagree | The three phases owning the checks rename to schema admission, decode admission, and extension admission; Phase 0 owns the doctrine prose and anchors. Closure: no ordinal gate reference outside a dated historical row, and every locus authored once |
| ~~`docker/` contains exactly one tracked file, a phase-named cross-compilation builder that no file in the repository references, carrying a pinned image digest and a URL beside its checksum~~ | [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) declares `docker/**` "authored image inputs only; rendered recipes go to `.build/docker/`", and the monocontainer recipe is generated from the typed catalog. The root's entire tracked content is the artifact class its own declaration excludes, and the pinned digest is what [§4](../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution) forbids in a tracked file | **Root deleted; the rendering half is still owed.** The tracked builder and the `docker/` root are gone and `dhall/amoebius/BakeCatalog.dhall` carries the catalog, so Phase 0 dropped the root from the write guard's declaration on 2026-08-17. Phase 36 still owes the other half of the closure: the recipe rendering to `.build/docker/`, proven by its own gate |
| `ui/` holds eight PureScript modules that no spago project covers and no tool, gate, or test names; the repository's only spago workspace covers a different root | Modules in an authored root that nothing compiles are neither authored source nor generated output, which is a fourth class [§1](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) does not admit | Phase 0 requires every authored root to name its builder; the phase owning the offline runtime adopts the modules into the one workspace or deletes them. Closure: every authored source root is reachable from a build |
| `AGENTS.md` and `CLAUDE.md` are byte-identical, and both are declared authored agent policy | Two tracked copies of one policy is a copy, and [§1](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) says copying does not create a second authored input. They diverge the first time one is edited, and nothing would report it | Phase 0: keep one file and make the other a link. Closure: no two tracked files at the repository root are byte-identical |
| A Cabal build root is present in the worktree and clean only because of the operator's personal ignore configuration; the repository's own `.gitignore` has no pattern for it | A tree clean only under one developer's configuration is not clean. [§8](../documents/engineering/repository_layout_doctrine.md#8-enforcement-and-source-snapshot-acceptance) binds a run to every non-ignored file, so the source snapshot differs between two clones of the same commit, and no check reading the worktree can see it | Phase 0: declare the build-root pattern in both contracts, and add a check that re-reads status with no personal ignore source and fails on any path clean only under one |
| The ignore contract was authored in four places with only a one-directional subset check between two of them, so nine `.gitignore` and twenty-two `.dockerignore` patterns existed that doctrine never declared | Four copies of one policy with a subset check in one direction is not a contract; it is four documents that agree today. Both the undeclared-pattern and the undeclared-build-root findings are the same hole seen from opposite sides | Phase 0. **Partly closed 2026-08-14**: doctrine [§6](../documents/engineering/repository_layout_doctrine.md#6-gitignore-contract)/[§7](../documents/engineering/repository_layout_doctrine.md#7-dockerignore-contract) are now exhaustive in both directions and reconcile exactly with both files. Remaining: derive or check the lint's required sets from the doctrine blocks rather than restating them, with a seeded negative per surface |
| `tools/artifact_policy.py` skips an `AUTHORED_ROOTS` entry that is not a directory instead of reporting it, so renaming or mistyping a root silently removes that tree from the rule-`r5` write guard | A fail-open in the rule whose purpose is to notice writes beneath an authored root, failing open exactly when the tree changes — the moment the guard is most needed. [§S](development_plan_standards.md#s-universal-artifact-hygiene-gate) clause 4 rests on this baseline | Phase 0, **before any repository-wide rename**: make a listed root that is not a directory a hard finding, with a seeded negative that renames a root and requires the audit to redden |
| `tools/artifact_policy.py` declares a gate-script glob one directory level shallower than where the Python bootstrap coordinator's sources live, so rule `r5`'s static write-location audit has never inspected them | A glob matching no file is a check that cannot fail, which [§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) says is not evidence. The phase that owns the coordinator sealed on a run whose artifact audit had a hole exactly where its subject lives | Phase 0 widens the glob and seeds a negative; the phase owning the coordinator clears whatever the corrected audit then reports and re-attests |
| Two roots are declared for infrastructure programs with no stated boundary between them, and five package roots exist with no stated criterion for when code lives in a package rather than the shared source tree | [§T](development_plan_standards.md#t-plan-to-implementation-reconciliation) clause 5 requires an unresolved ambiguity to be recorded with the decision required, never settled implicitly. The package split silently governs which dependencies a module may reach | **Closed 2026-08-14** for the criteria themselves: [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) states the package criterion and the reader test that separates a program root from the Haskell that drives it. Remaining: each affected phase applies them to its own root |
| The bake catalog fuses two of the three declared image identities into one image: its third stage builds the amoebius binary on top of the two third-party stages, which have no dependencies of their own. The phases that lift the sibling engines therefore rebuild and republish the whole image, twenty-one third-party binaries included, to relink one Haskell library | [`image_build_doctrine.md`](../documents/engineering/image_build_doctrine.md) declares the base and the runtime image as distinct arms of a closed identity. Fusing them makes a later phase rebuild an artifact an earlier phase sealed, which [§N](development_plan_standards.md#n-reopening-and-amending-a-phase) invariant 2 forbids, and it holds the whole third-party image behind everything the binary needs — the DSL, the folds, the UI stack, and a live cluster — when the two service stages need none of it | The phase owning the image build, in the re-baseline below: split the catalog at the runtime-stage edge so the third-party image is baked and probed against a host builder alone, and the runtime image and its publication follow. Closure: the service stages build and every baked binary executes on both architectures with no cluster, no containerd, and no registry request |
| The plan's numbering places the monocontainer after the whole pre-cluster sequence, so the image carrying every third-party service cannot be validated until the DSL, the folds, the UI stack, and the first live cluster are all sealed | The bake's real dependency floor is the toolchain phase: the catalog imports nothing, its decoder is generic, and the builder is named in doctrine as bootstrap infrastructure outside the no-public-pull boundary. A phase ordered by what it happened to be written after, rather than by what it needs, delays the artifact everything else runs on | Re-baseline, owned by Phase 0 and recorded here with its audit map when it lands: the third-party bake moves to immediately after the toolchain phase, the runtime image and registry publication stay in the live sequence, and every other phase shifts. It follows the de-phasing, because a re-baseline is documentation-only once no path names a phase ([§U](development_plan_standards.md#u-the-final-repository-layout) clause 3) |
| The substrate doctrine states that the two host workers are the same shape and symmetric, but only one has a declared root; the module tree already holds both side by side | A structural symmetry asserted in doctrine with a home on one side is design intent presented as structure | **Closed 2026-08-14** in doctrine: [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) states that per-substrate host code is a module tree, not a root, so the symmetry the substrate doctrine requires is what the source tree already expresses. Remaining: the phase owning the Apple host worker deletes its root |

### What the partition check found that the snapshot above did not — 2026-08-14

The snapshot above was authored by reading the tree. The three checks the reopened Phase-0 gate added then
read it mechanically, and four surfaces turned out to have no row. Each is a real divergence with a real owner,
so each takes one here rather than being absorbed into a neighbouring row.

| Existing observation | Misalignment with intended plan | Owner and closure |
|---|---|---|
| `ui-runtime/**` holds the one spago project and five tracked paths, and three ignore rules cover its build output, under a root the target tree does not have | [§2.2](../documents/engineering/repository_layout_doctrine.md#22-present-day-roots-and-their-required-destination) sends the root to `ui/**`. Until it moves, the repository has two PureScript roots and the ignore contract names the one that is leaving | **Positional half closed by Phase 2 on 2026-08-17**: the root is gone, `ui/spago.yaml` is the one project, and no ignore rule in either contract names `ui-runtime`. The behavioural half stays with Phase 64 — the spago output home is still `ui/{.spago,output,dist}`, beneath an authored root, and retargeting it into `.build/**` is a build change rather than a relocation |
| ~~`test-secrets.dhall` was a root-level cleartext-secret file ignored by both contracts while the target tree had no entry for it~~ | The seam is sanctioned by [`vault_pki_doctrine.md` §3.3](../documents/engineering/vault_pki_doctrine.md), and containment doctrine names this single ignored root file explicitly | **Closed by Phase 0 for layout/ignore on 2026-08-15 and by Phase 40 for production/no-copy on 2026-08-16.** The seam remains outside Git and every build context; production rejection and sink scans are sealed by `sha256:4f029c9f8fe3fa35da3da2cd1a6b94cdc7f2d2a808a821540d290848d6130dcb` |
| `app/` holds `Main.hs`, `singleton/`, and `Amoebius/Ui/Server/`, against the fixed `app/<executable>/**` second level [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) declares | A second level fixed in doctrine and instantiated three other ways is a taxonomy nothing enforces — the same defect as `test/`'s singular/plural pairs, one root over. This row read "one of the four declared names" until the [one-binary amendment](#one-binary-many-roles--2026-08-17) retired the fourth, third, and second | **Closed by Phase 2 on 2026-08-17.** `app/` holds one directory, `app/amoebius/`. `app/singleton/Main.hs` is `app/amoebius/Amoebius/Daemon/ControlPlaneMain.hs` behind an `amoebius control-plane` verb, and `executable amoebius-singleton` is gone. Phase 44 still owns the decoded `InClusterRole` arm, which is the behavioural half |

---

## What the layout conformance uncovered — 2026-08-17

Phase 2 moved the tree and found four things a positional move alone could not settle. Each was a real
divergence the package split had been hiding, so each takes a row here rather than being absorbed into the
relocation it surfaced during.

| Existing observation | Misalignment with intended plan | Owner and closure |
|---|---|---|
| `amoebius-pulsar` was `build-type: Custom`, and its `Setup.hs` resolved the repository-pinned `protoc`/`proto-lens-protoc` and generated `Proto.PulsarApi` into the build tree | A root `Setup.hs` is not in the [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) tree, and [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package) admits no ground for a package that exists only to carry one. The generator therefore retired with the split, and `lib:pulsar-client` names two autogen modules nothing currently produces | Phase 46, which owns the native Pulsar client. Closure: the bindings render to `.build/proto/**`, which the target tree already declares, under a generator whose search domain is closed the way the retired `Setup.hs` closed it — no ambient `PATH`, resolved tools by absolute path |
| `lib:jitml` exposed `JitML.Codegen.RuntimeOperationsCuda`, which exists in neither this repository nor the `jitml` package the sibling checkout resolves to, and `test/spec/kernel/JitMLCudaArtifactContractSpec.hs` imports it | The old `hs-source-dirs: ../../jitML/src` never resolved it either, so the component could not have built; the out-of-tree path made the absence invisible until the boundary became a package dependency | Phase 71, which owns the jitML CUDA lift. Closure: the module is authored — here or upstream — or the surface and its import are removed |


---

## Generated-artifact and terminology migration — 2026-08-11

The table is the mandatory implementation path for the documentation redesign. Items are ordered by their
first owning phase; work proceeds in numeric order.

| Legacy surface | Required disposition | Owner | Closure condition |
|---|---|---|---|
| Generated files beneath `DEVELOPMENT_PLAN/evidence/**` | Stop writing there; write run bundles to `.build/runs/**`; upload immutable attestations externally | Phase 0, then each owning phase | No tracked or unignored evidence path; every gate uses external retention |
| Generated Markdown beneath `DEVELOPMENT_PLAN/ledgers/**` | Retain unique human reasoning in the owning phase document; regenerate views under `.build/docs/**` | Phase 0 | No generated ledger Markdown in the plan tree |
| Mechanically expanded `tools/doc_lint_corpus/**/negative_*` and `negative_multi_*` copies | Retain positive seeds, mutation definitions, checker, and authored expected diagnostics; generate copies under `.build/test-corpora/**` | Phase 0 | No reproducible negative copy is tracked; clean generation exercises every mutation identity |
| `test/enumeration/**` | Generate surfaces at run time under `.build/test-surfaces/**` | Phase 0 framework; phases 1–70 adoption | No checked-in enumeration; missing/extra joins fail |
| `test/golden/phase_*_ledger.json` and Phase-62 expected-run ledger | Generate per-run ledgers under `.build/runs/**` | Phase 0 framework; phases 1–70 adoption | No ledger JSON under `test/`; schema-checked repository-local attestation exists |
| Generated `phase-results.tsv`, validation-locus ledgers, live/sprint tables, red-before-correction tables, and ambiguous expected-hash/digest/trace TSVs | Relocate generated tables to the owning run bundle; retain a test table only after independent authorship/review is recorded | Phase 0 framework; each owning phase | Every TSV has a provenance classification; no generated TSV is tracked outside `.build/**` |
| `cabal.project.freeze`, `package-lock.json`, `spago.lock`, and every `.lock`/`.freeze` file | Resolve dynamically into `.build/locks/**` | Phase 1 | **Met 2026-08-12.** No lock/freeze file is tracked; `.build/locks/phase_01/` carries the per-run graph |
| Hard-coded library/package SHA values, package archive checksums, and fixed dependency commits | Replace with authored compatibility requirements and dynamic resolution observations | Phase 1 | **Met 2026-08-12** at the Phase-1 loci, with `integrity-pin` and `fixed-commit` checks and their seeded negatives; remaining hits are deferred to their owning phases |
| Absolute developer-home executable paths and the resolved portion of `toolchain/pins.json` | Resolve logical tool identities into `.build/toolchain/resolved.json` | Phase 1 | **Met 2026-08-12.** `toolchain/pins.json` is deleted; 22 gates consume `tools/toolchain.py`. Developer paths in later phases' gates are deferred to those phases |
| Authored patches stored beneath generated evidence directories | Move reviewed patch inputs to an authored `patches/**` or `vendor/**` path and record upstream provenance without a fixed package SHA | Phase 1 | **Met 2026-08-12.** `patches/supernova_ghc_9_12.patch` is tracked with non-SHA provenance; the superseded `dual` patch is deleted |
| Generated protobuf Haskell modules and checksum lists beneath Phase-1 evidence | Regenerate from the authored `.proto` beneath `.build/proto/**` or the build tree | Phase 1 | **Met 2026-08-12.** The gate emits both modules into `.build/proto/phase_01/` per run and records their digests in the run bundle |
| Python bytecode | Permit source-adjacent interpreter caches with ordinary Python behavior; never track them or include them in Docker contexts | Phase 0 | Current-tree policy is implemented at `c8870a2`; retain both ignore/context checks and record the reachable-history disposition |
| Package trees, UI output, Cabal output, browser profiles, screenshots, coverage, and reports | Keep beneath ignored build/run roots | Phase 0 | `.gitignore`, `.dockerignore`, and tracked-path scans cover every class |
| Expected files produced by a reference program, including Phase-74 job output | Keep the independent reference program and authored inputs; generate expected bytes during the run | Owning phase | No reference-program output is version-controlled |
| Phase-60 frozen sibling-source inventory, expected hashes, captured sibling output, and duplicated gate hash constants | Resolve and execute reviewed sibling inputs dynamically and record identity/integrity/reference observations in the run bundle | Phase 60 | No copied inventory, expected hash table, captured reference output, or hard-coded sibling-source hash is tracked |
| Fixed resolution/integrity fields in Phase-35 bootstrap and Phase-42 package envelopes | Retain authored compatibility and resource requirements; resolve versions, URLs, packages, and integrity per run | Phases 35 and 42 | Tracked envelopes contain no package-resolution observation; run-local evidence records the selected inputs |
| Expected base-image digests, canonical-manifest outputs, UI digest tables, and reference traces with unresolved provenance | Independently review or replace authored expectations; otherwise generate observations under `.build/runs/**` | Phases 29, 31, 41–43, 48, 51, 64, and 34–70 | Every retained fixture records independent provenance; every reproducible observation is untracked |
| Generated documentation markers and tables inside governed Markdown | Keep governed Markdown authored; write generated views only to `.build/docs/**` | Phase 0 | Every governed document declares `Generated sections: none` |
| Prior oracle-custody claims not established by Git history, including same-commit subject/fixture additions | Classify as regression fixtures until independent review or replacement | Phase 0 and owning phase | Phase contract records independent author/reviewer provenance |
| Gates and builds whose inputs exist only in ignored worktree state | Relocate authored inputs, generate derived inputs at run time, and repeat the documented command against the source snapshot | Phase 0 framework; Phase 1 patch closure; each owning phase | The source-closure gate passes with no ignored worktree file as an input |
| Non-secret generated or obsolete files retained in reachable Git history | Remove current copies forward and record whether old history is retained or rewritten | Phase 0 policy and operator decision | Secret scan remains empty; an explicit history disposition is recorded without an implicit rewrite |
| `.gitignore` gaps | Implement the complete pattern contract in repository-layout doctrine | Phase 0 | Generated-path audit passes after a clean full gate run |
| `.dockerignore` gaps | Implement the complete container-context contract in repository-layout doctrine | Phase 0 | Context audit contains no derived, evidentiary, cache, secret, or runtime path |
| The term formerly used for the Python Bootstrap Coordinator in Markdown | Replaced with `Bootstrap Coordinator`; the Phase-35 Markdown file and links are renamed | Phase 0 | Implemented at `c8870a2`; retain a case-insensitive zero-result Markdown scan |
| The same obsolete term in Python filenames, identifiers, tests, commands, and generated output | Renamed to `bootstrap_coordinator`/`BootstrapCoordinator` without a compatibility alias; invalidated generated records are discarded | Phase 35 | Terminology scan is implemented; the migrated Phase-35 gate must still pass in numeric order |

The ignore-file changes, gate rewrites, source renames, and file deletions are implementation work. This
documentation change records them but does not perform them.

---

## Pre-implementation Phase Re-baseline — 2026-08-01

This table is the audit map for the approved low-code UI-runtime insertion. The left column is deliberately
historical text, not a live link; the right column records every current destination. Rows 17–42 are mechanical
renames, while the former broad UI phases 19 and 48 are explicit one-to-many splits and the `N/A` rows are new
seams. The renumbering used old-id placeholders before emitting any new id, so overlapping ids could not
cascade (for example, old Phase 20 could not become 31 by being rewritten first to 24 and then rewritten
again). Ubuntu-24.04 was explicitly protected as a non-phase literal.

| Historical id and path | Current id and path |
|------------------------|---------------------|
| 16 — phase_16_spa_composition_representational.md | 19 — phase_25_ui_program_schema.md; 20 — phase_26_scoped_identity_kernel.md; 21 — phase_27_ui_authorization_kernel.md; 22 — phase_28_ui_effect_binding.md; 23 — phase_29_ui_plan_compiler.md; 25 — phase_31_ui_browser_interpreter.md; 26 — phase_32_ui_server_boundary.md; 27 — phase_33_ui_local_composition.md |
| 17 — historical Phase-17 bootstrap-kind document | 29 — phase_35_bootstrap_coordinator_kind.md |
| 18 — phase_36_base_image_registry.md | 30 — phase_36_base_image_registry.md |
| 19 — phase_37_object_reconciler.md | 31 — phase_37_object_reconciler.md |
| 20 — phase_38_capacity_scheduler.md | 32 — phase_38_capacity_scheduler.md |
| 21 — phase_39_retained_storage.md | 33 — phase_39_retained_storage.md |
| 22 — phase_40_vault_pki.md | 34 — phase_40_vault_pki.md |
| 23 — phase_41_platform_backbone.md | 35 — phase_41_platform_backbone.md |
| 24 — phase_42_platform_services_2.md | 36 — phase_42_platform_services_2.md |
| 25 — phase_43_keycloak_ingress.md | 37 — phase_43_keycloak_ingress.md |
| 26 — phase_44_live_dsl_deploy.md | 38 — phase_44_live_dsl_deploy.md |
| 27 — phase_45_app_tenancy.md | 39 — phase_45_app_tenancy.md |
| 28 — phase_46_pulsar_client.md | 40 — phase_46_pulsar_client.md |
| N/A — newly isolated live-enforcement seam | 41 — phase_47_user_tenant_isolation_live.md |
| 29 — phase_48_content_store_workflow.md | 42 — phase_48_content_store_workflow.md |
| N/A — newly isolated owner-projection seam | 43 — phase_49_ui_projection_runtime.md |
| 30 — phase_50_release_lifecycle.md | 44 — phase_50_release_lifecycle.md |
| N/A — newly isolated UI-release seam | 45 — phase_51_ui_program_release.md |
| 31 — phase_52_network_fabric_wireguard.md | 46 — phase_52_network_fabric_wireguard.md |
| 32 — phase_53_multicluster_spawn_georepl.md | 47 — phase_53_multicluster_spawn_georepl.md |
| 33 — phase_54_gateway_migration_drills.md | 48 — phase_54_gateway_migration_drills.md |
| 34 — phase_55_provider_deploy_checkpoint.md | 49 — phase_55_provider_deploy_checkpoint.md |
| 35 — phase_56_provider_child_bringup.md | 50 — phase_56_provider_child_bringup.md |
| 36 — phase_57_provider_ebs_credential.md | 51 — phase_57_provider_ebs_credential.md |
| 37 — phase_58_provider_dynamic_nodes.md | 52 — phase_58_provider_dynamic_nodes.md |
| 38 — phase_59_determinism_jitcache.md | 53 — phase_59_determinism_jitcache.md |
| 39 — phase_60_infernix_lift.md | 54 — phase_60_infernix_lift.md |
| N/A — newly isolated infernix-to-UI seam | 55 — phase_61_infernix_ui_lift.md |
| 40 — phase_71_jitml_lift_cuda.md | 65 — phase_71_jitml_lift_cuda.md |
| N/A — newly isolated jitML-to-UI seam | 66 — phase_72_jitml_ui_lift.md |
| 41 — phase_74_apple_metal_host_daemon.md | 68 — phase_74_apple_metal_host_daemon.md |
| 42 — phase_62_test_topology_dsl.md | 56 — phase_62_test_topology_dsl.md |
| 43 — phase_43_spa_live_deploy.md | 57 — phase_63_ui_single_tenant_live.md; 58 — phase_64_ui_multi_tenant_live.md; 59 — phase_65_ui_rollout_reconnect.md; 60 — phase_66_ui_ha_multizone.md |

Destination phases **43, 45, 47, 57, and 59** are the explicitly mapped new live isolation, projection,
UI-release, infernix-UI, and jitML-UI seams inserted between the mechanically renamed phases. The old Phase 19
and Phase 48 milestone documents were retired only after every split destination was enumerated above. The resulting plan is one
contiguous `0..58` sequence at that date; two later re-baselines have since extended it.

---

## Pending Removal

"Location" names the **sibling-project artifact** being supplanted; the target
amoebius module that absorbs or replaces it is owned by [system_components.md](system_components.md). "Why
slated" cites the governing doctrine section by name. "Owning phase" is the amoebius phase whose adoption
work performs the removal. The final column preserves the invalidated pre-amendment observation that explains
what code or gap was seen; it is not current status. Every row is currently reopened with its owning phase,
and only [README.md](README.md) supplies that status.

| Item | Location (sibling artifact) | Why slated | Owning phase | Pre-amendment observation (invalidated) |
|------|-----------------------------|------------|--------------|--------|
| **prodbox** as a standalone product / CLI | sibling `prodbox/` — `app/prodbox/Main.hs`, `src/Prodbox/` | prodbox is absorbed as the **root single-node control-plane behaviour** — a library + the in-cluster control-plane daemon (a Deployment `replicas=1`, single-instance from k8s/etcd, no election) under the one amoebius binary, not a separate product; see [`daemon_topology_doctrine.md` §3 — the control-plane daemon](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-daemon) and the convergence framing in [README.md](README.md) | [Phase 35](phase_35_bootstrap_coordinator_kind.md) – [Phase 44](phase_44_live_dsl_deploy.md) | 📋 Planned |
| **The shell `bootstrap.sh` igniter** | sibling hostbootstrap `bootstrap.sh` (the substrate shell script) | Retired for the **Python `pb` bootstrap coordinator CLI** — one Python CLI, two modes (bootstrap coordinator bring-up + admin-REST client); amoebius owns no bootstrap shell script; see [`substrate_doctrine.md` §6 — the bootstrap coordinator contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) | [Phase 35](phase_35_bootstrap_coordinator_kind.md) | ✅ Replacement built; complete pristine-Incus Phase-29 gate passed |
| **infernix** as a standalone product / image | sibling `infernix/` — `Infernix.Runtime.*` | infernix becomes an **ML extension library** linked into the amoebius binary (and a shared library at the app surface), never a separate product; see [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library, the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule) | [Phase 60](phase_60_infernix_lift.md) | 🟡 Scoped gate passed 2026-08-11: one untouched sibling compacted-topic module and the new facade are linked; full sibling inference-engine linkage remains UNVERIFIED |
| **infernix handwritten SPA** as an authority-bearing frontend | sibling infernix PureScript demo client | Replaced by the bounded Dhall module and linked Haskell adapter interpreted through the generic UI runtime; the sibling screen remains UX evidence, never a second executable frontend or authority source. | [Phase 61](phase_61_infernix_ui_lift.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. The test uses loopback UI origins and a reference worker, so full edge/Kubernetes replica/production cutover remains UNVERIFIED. Every hardware substrate can run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows. |
| **jitML** as a standalone product | sibling `jitML/` — `JitML.*` | jitML becomes a linked **ML extension library** behind one scope-bound CUDA-training → pointer-committed-artifact facade; Phase 42 continues to own delegated Pulsar-Failover/CAS coordination and Phase 66 alone owns UI interaction | [Phase 71](phase_71_jitml_lift_cuda.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. One sibling CUDA generator is linked, but the full trainer/checkpoint graph and Kubernetes owner remain UNVERIFIED. Every hardware substrate can run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows. |
| **Baked / Poetry-venv ML engine payloads** | sibling infernix per-engine Poetry venvs + curl-tar-at-image-build (`docker/Dockerfile`, `model_cache.py`) | Retired for the shared **jit-build resolver + `CacheBudget`-bounded content-addressed cache**: each engine is a named catalog identity resolved on first miss, never baked or URL-fetched; see [`content_addressing_determinism.md` §4.5 — the ML-asset lifecycle](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) and [`image_build_doctrine.md` §7](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 59](phase_59_determinism_jitcache.md) | 🟡 Scoped replacement validated with a pinned engine fixture; production engine payloads remain UNVERIFIED |
| **All third-party Helm charts + the Helm binary** | sibling prodbox chart platform (`Prodbox.Lib.ChartPlatform`, vendored charts); `helm` baked in the hostbootstrap base image | No-Helm: platform and app manifests are **pure typed Haskell rendered and applied by the typed reconciler** (server-side apply, ApplySet prune, wait), so neither charts nor the `helm` dependency survive; see [`manifest_generation_doctrine.md` §1 — why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) | [Phase 41](phase_41_platform_backbone.md) (platform) → [Phase 44](phase_44_live_dsl_deploy.md) (app DSL) | 📋 Planned |
| The **five upstream operator charts** — Harbor, MetalLB, Envoy Gateway, cert-manager, Percona — *as charts* | vendored Helm charts in sibling prodbox | Operators are **generated as typed CRs**, and their binaries **baked into the base container**, not installed via operator charts: no-third-party-charts ≠ no-third-party-software; see [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software: operators are generated](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated) and [`image_build_doctrine.md` §7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 41](phase_41_platform_backbone.md) | 📋 Planned |
| **The per-app container image** | the `app/workload image` class every app shipped as its second artifact | Retired: an app is bounded `UiSource` plus immutable client/server plans interpreted by the generic runtime — no per-app browser or server image, hand-written Dockerfile, or registry publication. Only a reviewed trusted Haskell adapter changes a `Runtime.linkedAdapters` variant; an ordinary UI change mints a `ProgramDigest`/`Release` and reuses the image digest. See [`app_vs_deployment_doctrine.md` §2 — the application-logic surface](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is) and [`image_build_doctrine.md` §5 — the closed `ImageIdentity`](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest) | [Phases 25–33](phase_25_ui_program_schema.md) (language/runtime) → [Phase 51](phase_51_ui_program_release.md) (immutable program release) | 📋 Planned |
| **The hand-authored `docker/base/Dockerfile`** | the committed `ARG`/`RUN … install` template driving the base-image bake | Retired for a **generated** Dockerfile emitted from the typed `BakeCatalog`, on the same ground [`manifest_generation_doctrine.md` §1](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) retires Helm charts: interpolated text that nothing inspects until it runs. See [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) | [Phase 36](phase_36_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **Harbor** itself (the registry) | sibling prodbox in-cluster Harbor + mirror-into-registry pipeline | Replaced by the single-binary **`distribution` (`registry:2`)** registry — itself a baked binary, no relational DB, no public-registry pulls; see [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source) | [Phase 36](phase_36_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **jitML Node.js-subprocess WebSocket** Pulsar transport | sibling jitML — the Node subprocess owning the WebSocket client (`JitML.*`) | Retired for the **native `amoebius-pulsar`** TCP binary-protocol client: one client, one wire, **no WebSockets**, no Node runtime; see [`pulsar_client_doctrine.md` §1 — one client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets) and [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 46](phase_46_pulsar_client.md) (native client) → [Phase 71](phase_71_jitml_lift_cuda.md) (jitML cutover) | 📋 Planned: Phase 65's scoped host-CUDA slice does not exercise native CBOR/Pulsar, so transport cutover remains UNVERIFIED. The portable `linux-cpu` lane and Incus/Lima/WSL2 clean-host routing remain available. |
| **infernix in-process WebSocket gateway** Pulsar transport | sibling `Infernix.Runtime.Pulsar` (WebSocket gateway, one-producer-per-publish, base64-in-JSON) | Same native-client replacement; infernix stops shipping its own transport and consumes `amoebius-pulsar`; see [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 46](phase_46_pulsar_client.md) (native client) → [Phase 60](phase_60_infernix_lift.md) (infernix cutover) | 🟡 Scoped gate passed 2026-08-11: native-CBOR driver and dedup path observed; full command-to-worker cutover remains UNVERIFIED |
| **infernix single-arch (amd64-only)** image publication | sibling infernix image-build pipeline | Replaced by **multi-arch (`amd64` + `arm64`) baked binaries** under one manifest list; see [`image_build_doctrine.md` §3 — buildx multi-arch, amd64 and arm64, one manifest list](../documents/engineering/image_build_doctrine.md#3-multi-architecture-images--one-natively-built-child-per-architecture) | [Phase 36](phase_36_base_image_registry.md) | ✅ Done — resealed 2026-08-16 |
| **Per-substrate chart / image re-pins** | sibling prodbox substrate-aware version/image-ref pinning | Forbidden by **substrate equivalence**: one release/image-ref value across every substrate, with a build-time check that no code path re-pins conditionally on the active substrate; see [`platform_services_doctrine.md` §12 — substrate equivalence as a structural invariant](../documents/engineering/platform_services_doctrine.md#12-substrate-equivalence-as-a-structural-invariant). This bars per-substrate divergence of chart **versions** and **image refs** only; per-cluster **shape** divergence (single-node vs distributed) is permitted by [`service_capability_doctrine.md`](../documents/engineering/service_capability_doctrine.md) | [Phase 41](phase_41_platform_backbone.md) | 📋 Planned |

---

## Notes

- **"Removed" rarely means "deleted code."** For the three standalone products, the convergence retires their
  *product / packaging / transport identity*, not their domain logic. prodbox's control-plane behaviour and
  infernix's/jitML's ML logic are **preserved as libraries** linked into the one amoebius binary. Their demo
  clients remain migration evidence while the flows become bounded UI modules; what disappears is the separate
  CLI, image, release, and browser trust seam. This is why these rows are tracked here rather than as plain
  feature work.

- **Charts vs software (the Helm rows).** Dropping the five operator charts does **not** drop the five
  operators. Harbor is the one operator/service that is genuinely *replaced* (by `distribution`); MetalLB,
  Envoy Gateway, cert-manager, and Percona survive as **baked binaries with generated CRs**. Only the Helm
  *delivery mechanism* — the charts and the `helm` dependency — is removed. The distinction — charts and the
  `helm` dependency are removed, the operators are not — is the subject of [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated).

- **Why two phases on the transport rows.** The native `amoebius-pulsar` client lands in
  [Phase 46](phase_46_pulsar_client.md), but the sibling transports are only *deleted* when
  each library is migrated onto it — infernix's WebSocket gateway at [Phase 60](phase_60_infernix_lift.md)
  and jitML's Node-subprocess client at [Phase 71](phase_71_jitml_lift_cuda.md), one subsystem at a time
  behind reversible adapter seams. The "client-lands → library-cutover" pair is captured so neither half is
  marked Done prematurely.

- **The substrate-equivalence row is a standing prohibition, not a one-time deletion.** "Per-substrate
  re-pins" is removed in the structural sense that no amoebius code path is allowed to express one; the
  enforcing build-time check is itself a [Phase 41](phase_41_platform_backbone.md) deliverable,
  and the substrate catalog it ranges over is owned by [substrates.md](substrates.md). It belongs on this
  ledger because it forecloses a prodbox-era pattern (substrate-conditional image refs) by construction.

- **Sibling evidence, not amoebius proof.** Every justification above that points at prodbox / infernix /
  jitML behaviour begins as evidence from a sibling system. Passed/scoped text in the final column is an
  invalidated historical observation and may be used only for diagnosis at its stated boundary; it is not a
  current amoebius result. All "Why slated" text remains design intent (the honesty rule,
  [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

- **No fractional phases, no forward dependencies.** Owning-phase assignments above respect the one-phase
  model and strict numeric order ([development_plan_standards.md §E](development_plan_standards.md#e-one-canonical-phase-model)): every
  removal is pinned to an existing, contiguously-numbered phase, never to a fractional or later-than-its-cause
  id.

---

## Related Documents
- [README.md](README.md) — the live tracker: phase order, status, and gates that drive every owning-phase column
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (status vocabulary [§C](development_plan_standards.md#c-status-vocabulary), one-phase model [§E](development_plan_standards.md#e-one-canonical-phase-model), doctrine-citation [§H](development_plan_standards.md#h-the-doctrine-citation-rule-cite-by-name), honesty [§K](development_plan_standards.md#k-honesty-proven--tested--assumed)) this ledger obeys
- [system_components.md](system_components.md) — the target amoebius modules that absorb or replace each slated artifact
- [substrates.md](substrates.md) — the substrate registry the substrate-equivalence row ranges over
- [phase_41_platform_backbone.md](phase_41_platform_backbone.md) — owns the no-Helm platform render, the baked operators, and the substrate-equivalence check (`distribution` and multi-arch are [phase_36_base_image_registry.md](phase_36_base_image_registry.md)'s)
- [phase_46_pulsar_client.md](phase_46_pulsar_client.md) — owns the native `amoebius-pulsar` client that retires the WebSocket transports
- [`manifest_generation_doctrine.md`](../documents/engineering/manifest_generation_doctrine.md) — no-Helm rendering + generated operators
- [`image_build_doctrine.md`](../documents/engineering/image_build_doctrine.md) — baked binaries, `distribution`, multi-arch
- [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md) — the registry and substrate-equivalence invariants
- [`pulsar_client_doctrine.md`](../documents/engineering/pulsar_client_doctrine.md) — the native client and what it replaces
- [`app_vs_deployment_doctrine.md`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only) — infernix/jitML-as-library and their interactions expressed through the bounded UI runtime
- [`daemon_topology_doctrine.md`](../documents/engineering/daemon_topology_doctrine.md) — prodbox absorbed as the control-plane daemon
