# Amoebius Development Plan

> **Purpose**: Provide the authoritative numeric phase order, current status, remaining work, and routing
> to each phase's human-authored validation contract.
> **Read this if**: the current phase, the next permitted work, or the location of a phase gate must be established.

This tracker owns phase order, status, and dated implementation progress. Each phase document owns its
capability-specific validation contract, while the universal source-snapshot postcondition is owned by
[development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
Architecture remains owned by the doctrine suite under [`../documents/`](../documents/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_determinism.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/diagram_conventions.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/low_code_ui_workflow_lifting.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_ebs_credential_model.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_schema.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/substrate_node_inventory.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_tenancy.md, documents/reading_order.md
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
The Python `pb` bootstrap coordinator exists only before binary handoff and as the later admin-REST client.
The constituent prodbox, infernix, jitML, and hostbootstrap capabilities converge as libraries and
behaviours rather than separate products.

## Phase discipline

1. Phases close strictly in numeric order. Phase N+1 cannot close or begin new implementation work before
   Phase N satisfies its redesigned gate.
2. Each phase document owns one cohesive capability claim and one acceptance command.
3. Every gate inherits the artifact-hygiene postcondition in
   [development_plan_standards.md §S](development_plan_standards.md#s-universal-artifact-hygiene-gate).
4. Every hardware substrate can run the `linux-cpu` baseline **at its own natural architecture and no
   other**. Pristine Linux uses Incus on Linux or Linux-CUDA, Lima on Apple at `arm64`, and WSL2 on Windows at
   `amd64`. A gate names its lane with that architecture; nothing is emulated or cross-built
   ([substrate_doctrine.md §1.1](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule)).
5. A gate may additionally require at most one specialized lane — Apple, Linux-CUDA, or Windows. The baseline cannot
   substitute for a specialized claim, and one architecture cannot substitute for the other.
6. Register 1 is pure/golden, Register 2 is boundary-with-fakes, and Register 3 is live. Register 2.5 is a
   deterministic-simulation activity, never a phase-gate register.
7. Missing prerequisites fail; they never skip to green. Unreached applicable layers remain UNVERIFIED.

## Repository and evidence discipline

Only human-authored inputs and reviewed external source are version-controlled. Generated projections,
compiled output, lock/freeze files, package checksum databases, hard-coded library or package SHA values,
resolved paths, test enumeration, ledgers, receipts, logs, reports, screenshots, and generated
documentation remain untracked.

All amoebius-owned state stays under the physical checkout. `.build/**` owns reproducible, transient, and
evidentiary output; `.data/**` owns production runtime and durable state; `.test_data/**` owns exclusively
harness-created test state. Immutable run attestations live in `.build/evidence-store/**`. The complete
repository tree, output inventory, lifecycle rules, and normative `.gitignore`/`.dockerignore` patterns
are owned by
[repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md).

## Toolchain

Compilers, package tools, libraries, code generators, browsers, and transitive dependencies resolve
dynamically from authored compatibility requirements. Every clean run records the selected versions,
source identities, dependency graph, executable paths, and observed integrity data under `.build/toolchain/`
and `.build/locks/`, then binds them into repository-local evidence. No generated resolution is copied into Git.

**No requirement is expected on the developer host**, per the ensure rule of
[development_plan_standards.md §F](development_plan_standards.md#f-the-sprint-block-format). The floor it
leaves behind is authored data evaluated before any requirement resolves, so an unsupportable host is named
along with its remedy rather than discovered as a symptom. Every authored platform key is the one canonical
`<os>-<arch>` token, and a publisher that offers no asset for the host's architecture is a refusal, never a
substitution.

## Document index

| Document | Role |
|---|---|
| [development_plan_standards.md](development_plan_standards.md) | The plan rulebook's hub: every section heading and anchor, and the document-form rules |
| [development_plan_phase_model.md](development_plan_phase_model.md) | Rulebook slice: status vocabulary, the phase model, honesty, substrate discipline, reopening and re-baselining |
| [development_plan_gate_integrity.md](development_plan_gate_integrity.md) | Rulebook slice: gate integrity, universal artifact hygiene, reconciliation, and the final repository layout |
| [overview.md](overview.md) | Target architecture and cross-cutting invariants |
| [system_components.md](system_components.md) | Implemented, substituted, missing, generated, and planned component inventory |
| [substrates.md](substrates.md) | Hardware/substrate registry and pristine-host routing |
| [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) | Current-tree and history divergences, owners, and closure conditions |
| [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) | Complete authored/generated tree, dynamic resolution, and ignore/context contract |
| [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) | Validation registers and boundary discipline |
| [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) | Register-2.5 scheduling and replay discipline |
| [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) | Sibling-source migration and convergence rules |
| `phase_0_*.md` … `phase_82_*.md` | One human-authored capability and validation contract per phase |
| [later_phases.md](later_phases.md) | In-scope phases not yet assigned an integer document |

## Status vocabulary

✅ Done · 🔄 Active · 📋 Planned · ⏸️ Blocked · 🧪 Live-proof pending. Definitions live in
[development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary). The former
non-standard `🟡 Scoped` marker is retired. A scoped historical result is diagnostic, not a current status.

## Implementation-progress vocabulary

Status is a gate decision; progress is a dated repository observation. **No footprint observed**, **Observed
footprint**, **Known partial**, and **Policy-conformant** have the exact meanings in
[development_plan_standards.md §C](development_plan_standards.md#c-status-vocabulary). Source, tests, a gate
script, or an old run can establish only an observed footprint. Only the redesigned current gate plus its
verified repository-local attestation can establish Policy-conformant progress or support ✅ Done.

## Definition of Done

A phase is Done only when all of the following are true:

1. Its phase-specific acceptance command passes in the declared register and substrate, against a recorded
   source snapshot of every non-ignored file.
2. Its runtime-generated surface enumeration joins completely to independently authored expectations.
3. Applicable mutants, negative controls, external observers, authority pairs, and cleanup checks pass.
4. All deliberate generated files stay under ignored output roots; source-adjacent ignored Python interpreter
   caches are the sole exception, and no other command writes beneath an authored root.
5. Nothing the gate ran altered a tracked file, and it left no unignored path behind.
6. The Docker context contains no generated output, evidence, cache, dependency tree, secret, or runtime state.
7. The generated run bundle passes its schema and honesty checks.
8. An immutable repository-local attestation verifies against that source-snapshot digest and the phase contract.
9. The source snapshot contains every referenced authored input and passes the same documented gate with no
   ignored worktree file as an input.
10. Semantic provenance checks reject reproducible tracked copies, including generated fixtures placed beneath
    otherwise authored roots.
11. A before/after host inventory proves that the gate created no amoebius-owned state outside the checkout.
12. Production state uses only `.data/**`; normal teardown preserves durable descendants.
13. Tests use only one marker-owned `.test_data/runs/<run-id>/**` root, fail fast on production state, and
    delete only that exact root after verifying ownership.
14. `test-secrets.dhall` is the sole cleartext secret-at-rest, is read only by the elevated test harness, is
    never copied or emitted, and is rejected by all production entry points.

Markdown never embeds the generated ledger, receipt, hash, transcript, or dependency resolution. A human
status decision may link the content-addressed run reference. A prior seal cannot satisfy Done, and neither can a run whose
source snapshot no longer matches the tree. **When the operator commits is their own affair and never a gate
condition** ([development_plan_standards.md §S](development_plan_standards.md#s-commit-timing)).

## Reopened numeric sequence

### The 2026-08-20 conformance review

The re-baseline moved every ordinal and added eight documents, but most of the prose describing the world it
created had been swept rather than re-derived. A review of the whole corpus found roughly two hundred and fifty
defects across four kinds, and none had been caught by any check.

**Doctrine arguments repaired.** The closure argument of
[`extension_conformance_doctrine.md` §7](../documents/engineering/extension_conformance_doctrine.md#7-link-time-union-closure)
read as a theorem and is a finite pairwise test; it now says so, and records that a proof of C1 is owed. The
claim that the security family "adds no power" is withdrawn — three of its six laws reach where no L-law does,
so the closure argument does not carry them across a seam, and nothing yet closes that. A digest is described as
total and collision-resistant rather than injective, which it cannot be. C7 is restated so two extensions
rendering identical content name one artifact instead of failing a disjointness assertion. The fifth calculus
gained the owner it never had, in
[`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md).

**Two contradictions closed.** `repository_layout_doctrine.md` recorded `source-repository-package` entries on
two seeds as the achieved target state, which
[`lift_and_compose_doctrine.md` §2](../documents/engineering/lift_and_compose_doctrine.md#2-the-two-non-dependencies)
forbids by name; and `image_build_doctrine.md`'s image-identity section framed the tagging scheme as an open
question that its own [published-tag rule](../documents/engineering/image_build_doctrine.md#21-a-published-tag-is-a-cache-warm-up-and-its-name-is-the-content-address)
had already decided.

**Three corrections to this plan's own claims.** The register cut is **51/52**, not 49/50 — the two pre-binary
phases at 50 and 51 are Register 2 against a committed fake-host boundary. There are **nine** bands, not eight.
And `Phase scope` was present in all 96 contracts rather than missing from 63, but 63 of them repeated the
document's own Purpose blockquote and so carried nothing.

**The covering closed.** The case-family axis was described rather than enumerated, and the generator inferred
it from the entries it measured — so a family nothing declared produced no cells, and the covering could not
report the one thing it exists to report. The axis is now declared at fourteen members, the generator reads
that declaration, and the grid resolves 252 cells with 11 owing a reason for the documented reason that they
are *unknown* rather than empty.

**Four checks added**, because the review's real finding is that all of this coexisted with a clean lint:
`phase_contract_lint`'s `d5` (a scope that restates its purpose), `d6` (clause 13 neither discharged nor
excused — 67 contracts were silent), `d7` (a completion marker surviving in a reopened phase), and `d8`, which
recomputes every band, register and substrate claim the plan makes about itself from the contracts.

### The 2026-08-19 generative re-baseline

The plan sequenced a closed DSL that lifted its sibling projects. amoebius is an **open core** whose lawful
instances are domains and hardware substrates, it depends on no seed project, and every artifact that is not
Haskell source is generated from Haskell types. Twenty-one phases are inserted for capabilities that had no
owner — the five calculi, the two indices, the amoebius-owned proof stack, the extension contract, and the
generative classes — one phase splits into a pure half and a live half, and the sequence is re-ordered so the
algebra precedes every instance of it. The count goes from 75 to 96. The exhaustive old-to-new map is recorded
in [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#the-audit-map), as
[§E](development_plan_phase_model.md#e-one-canonical-phase-model) requires.

**It reopens every phase.** Four things every gate rests on are different afterwards: where the Dhall schema
comes from, what an expectation over rendered output is, whether releasing a resource is optional, and who
maintains the checkers. No prior seal survives that, so every sealed phase loses ✅ and its attestation becomes
history rather than completion evidence
([§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)). The two phases green on 2026-08-19
are reopened with the rest: their host capability is unaffected, but a host gate under the lift calculus is not
the gate they passed.

**Consequence for order of work.** Phase 0 is Active and every other phase is Blocked, returning to work in
numeric order. The register cut moves from 34/35 to **51/52**: everything at or below 51 is a statement about
values — the two pre-binary phases at 50 and 51 reach Register 2 against a committed fake-host boundary — and
the first gate needing a machine is the Linux engine bringup at 52
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)). Two new gate obligations land with
it — [§M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 13,
extension-conformance discharge, and
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 16, the illegal-state
covering — and each is owed by every phase it applies to, in numeric order.

### The 2026-08-17 one-binary-many-roles amendment

The role a running copy of the binary holds is a **decoded value** on its frame config, not the identity of
the file that was executed
([`daemon_topology_doctrine.md` §2](../documents/engineering/daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)).
The suite said "one binary" in a dozen places and then drew four of them in the target tree; the union naming
the roles was written three times — in the schema, and in two doctrine documents — with no two agreeing on
its arms; and the context × role grid stayed prose, so the grid's empty cells were foreclosed by nothing. The
grid is now a closed `Process` union with a named schema module to carry it, `app/`'s second level has one
name, and the two states the shape forecloses are catalogued as 3.89 and 3.90.

**Consequence for order of work: none.** Phase 0 reopened and resealed the same day under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase), gaining
[Sprint 0.13](phase_00_documentation_suite.md#sprint-013-one-binary-many-roles-). Phase 1 is Active and
untouched by this change. Every other phase is Blocked, so amending its contract invalidates no seal —
Phases 25, 25, 33, 39, 41, 61 and 77 each gain or sharpen a deliverable. What the amendment condemns in code is
recorded in
[`legacy_tracking_for_deletion_archive.md`](legacy_tracking_for_deletion_archive.md#one-binary-many-roles--2026-08-17),
including the finding that **neither the dhall-typecheck nor the gadt-decode gate can run today**: both resolve their
oracles under a `tests/` directory the tree does not have.

### The 2026-08-17 host-ensure amendment

A tool with a supported install plan is **ensured**, never recorded as a prerequisite
([`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)).
[§F](development_plan_standards.md#f-the-sprint-block-format)'s `host-toolchain` token contradicted that by
naming six binaries a developer had to supply — two of which the resolver was already acquiring — and the
doctrine suite had never written down what a host must supply instead. The token is replaced by `host-floor`,
pointing at the per-substrate floor now stated in
[§3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply);
`accelerator-device-plugin` is retired because the device plugin is a DaemonSet the reconciler renders like
every other operator install. The vocabulary is now parsed from the rulebook's own table and joined to the
declaring phases in both directions, which immediately found two phases the table listed that declared
nothing and one that declared a token its row omitted.

**Consequence for order of work: none.** Only Phase 0 was Done, and it reopened and resealed the same day
under [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase). Phase 1 was already Active and
gains [Sprint 1.7](phase_01_toolchain_spike.md#sprint-17-discover-then-ensure--the-resolver-acquires-what-it-needs-).
Every other phase was Blocked, so amending its contract invalidates no seal. What the amendment condemns is
recorded in
[`legacy_tracking_for_deletion_archive.md`](legacy_tracking_for_deletion_archive.md#host-ensure-amendment--2026-08-17).

### The 2026-08-16 natural-architecture amendment

It **reopens every phase**, and re-baselines the sequence. Its
predicate is [development_plan_gate_integrity.md §S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
clause 15: a run records the natural architecture it proved, and executes no artifact of another. No seal
recorded before 2026-08-16 names an architecture, and the one that named two reached the second under an
emulator, so no prior seal satisfies the amended gate. Phase 0 adopted the clause and resealed on 2026-08-17;
Phase 1 is Active and Phases 9–74 are Blocked, each returning to work only in numerical order after its
predecessor validates.

The re-baseline is the amendment's second half. No host can build an architecture it cannot execute, so the
old Phase 41 — one gate claiming a two-architecture image — became two: Phase 41 builds, proves, and publishes
its own architecture's child, and a new **Phase 85** does the same on the complementary substrate and joins
both into one attested index. Old phases 26–64 shift to 27–65 (that re-baseline's own record, not this one's); the audit map is recorded in
[legacy_tracking_for_deletion_archive.md](legacy_tracking_for_deletion_archive.md#natural-architecture-rebaseline--2026-08-16),
as [§E](development_plan_standards.md#e-one-canonical-phase-model) requires.

**Consequence for order of work.** Every phase reopens, so work restarts at Phase 0 and proceeds in numeric
order; a phase's rerun differs from its last one only by recording the architecture it ran on, except in the
image band where the contract itself changed. Phases 0–2 and 9–34 are substrate `none` and pure, so re-recording their
lane is a short run rather than a campaign. From Phase 57 onward the plan needs **two physical machines** — one
per architecture — which is a cost the amendment accepts rather than hides: a two-architecture image proven by
one machine was proven for one of them.

Each phase reruns its own gate and records the architecture that gate ran on; the containment criteria every
phase already inherited are unchanged and carry forward.

```mermaid
flowchart LR
  %% register: orientation
  p0["Phase 0: clause 15 + the amended lint"] -->|"reseal"| p1["Phase 1: rerun, recording its lane and architecture"]
  p1 -->|"then, in numeric order"| live["Phases 9-36: rerun on one architecture"]
  live -->|"then the pair"| pair["The complementary host joins, then the chain continues"]
```
*Orientation. [Phase 0](phase_00_documentation_suite.md) adopts the architecture postcondition; each later phase reruns its own gate in numeric order, and the image band needs both machines.*

**Historical amendment record (superseded as status, retained as rationale):**

The **2026-08-15 repository-containment amendment** reopened every previously sealed phase without
renumbering, because the older contract admitted `.build/`'s predecessor, system temporary roots, user-home
state, and host-global container-engine data. Phase 0 validated the closed root set, both ignore contracts,
production rejection of `test-secrets.dhall`, test/production root separation, and a host-inventory negative
that detects any escaped path or global engine resource; each later phase then migrated its own paths, cleared
its rows in the legacy register, and reran its capability gate. Those containment criteria remain in force —
this amendment adds to them rather than replacing them.

The 2026-08-11 generated-artifact amendment reopened every phase — then numbered 0–68 — without renumbering them.

1. **Phase 0 adopted and sealed the repository-containment boundary on 2026-08-15.** Its ten-sided gate is
   green with 17 independently seeded policy rules, project-contained run evidence and attestation, and an
   unchanged outside-host inventory. The whole-tree containment scanner attributes 158 legacy callers to
   their numerical owner phases; none is a Phase-0 deferral.

2. **Phase 0 was reopened again on 2026-08-14 by the final-layout amendment, and resealed the same day.**
   [development_plan_standards.md §U](development_plan_standards.md#u-the-final-repository-layout) makes the
   target repository tree normative and gives it to Phase 0. The tree in
   [`repository_layout_doctrine.md` §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure)
   had enumerated thirty-one roots and called itself exhaustive, but nothing compared it to the worktree, so
   its rule that a new root needs an amendment first had never decided anything. [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) is now the target final
   layout at fourteen roots; Phase 0 owns the check that the tree matches, the no-phase-ordinal rule of [§U](development_plan_standards.md#u-the-final-repository-layout)
   clause 3, and the ignore contracts that are now exhaustive in both directions. Every divergence is recorded
   in
   [`legacy_tracking_for_deletion_archive.md`](legacy_tracking_for_deletion_archive.md#layout-and-naming-divergence-snapshot--2026-08-14)
   with an owner and a closure condition, deferred on the shrink-only terms
   [§S clause 5](development_plan_standards.md#s-universal-artifact-hygiene-gate) already sets. The three
   checks and the write-guard repair landed as Sprint 0.9; 876 findings are deferred with owners, none of
   them Phase 0's, and the phase resealed with all nine sides passing.
   A **re-baseline follows**, not precedes, that work: the third-party monocontainer bake moves to immediately
   after the toolchain phase, because its dependency floor is the toolchain and not the DSL, and the runtime
   image and registry publication stay in the live sequence. It is sequenced after the de-phasing because a
   re-baseline is documentation-only once no path names a phase, and it lands with the audit map
   [§E](development_plan_standards.md#e-one-canonical-phase-model) requires. Both obligations are recorded in
   [`legacy_tracking_for_deletion_archive.md`](legacy_tracking_for_deletion_archive.md#layout-and-naming-divergence-snapshot--2026-08-14).
3. **Phase 0 was reopened and resealed on 2026-08-13.** Its deliverables — the provenance classifier,
   generator registry, authored-root write guard, semantic generated-file scan, source-snapshot verification,
   ignore/context coverage, reachable-history audit, external-attestation validation, and the documentation
   lints — were sealed on 2026-08-12. Once commit `0526152` first tracked this phase's own machinery, the
   audit began scanning its own seeded negative corpora and the `policy` side went red. The finding belonged
   to Phase 0, which cannot defer what it owns; it closed by declaring the corpora as one authored set and
   is sealed again.
4. **Phases 1, 2, 11, and 17 were previously Done.** Phase 1 replaced its pin manifest with authored compatibility requirements and a
   run-local resolver; Phases 11 and 17 migrated the formal-model and gateway-migration gates onto resolved
   toolchains, run-bundle ledgers, and run-time surface enumeration. Each was sealed on 2026-08-12 with a
   verified pre-containment external attestation, recorded in the historical phase record table below.
5. **The lowest phase not yet sealed is Active; every phase above it is Blocked.** In order, each must migrate
   enumeration and evidence to `.build/`, establish oracle provenance, adopt the authored-root write guard, rerun
   its capability gate, and publish a snapshot-bound repository-local attestation. The phase-overview table is the
   authority on which phase that currently is.
6. **Later phases remain Planned.** They inherit the redesigned doctrine from their first authored contract.

Prior implementation and run records may guide diagnosis. They do not allow a phase to skip its reopened
gate or numeric predecessor.

### The 2026-08-13 secrets amendment reopens Phases 25 and 26

Secrets reach a workload only from Vault, and a production config cannot express a secret value. That second
half is a statement about **dhall-typecheck and gadt-decode**, so it belongs to the phases that own them: Phase 25 gains the
shared `SecretRef` union and Phase 26 gains its decode-and-reject. Both were sealed on 2026-08-12; both are
reopened under [§N](development_plan_standards.md#n-reopening-and-amending-a-phase) with the reason dated in
their status blocks.

Locating the type anywhere later would be the forward dependency
[§E](development_plan_standards.md#e-one-canonical-phase-model) forbids: Phases 25 and 26 would keep claiming a
complete admission boundary while a higher-numbered phase quietly completed it.

**Consequence for order of work.** While 4 and 5 are Active, no phase above them begins new implementation
work ([phase discipline](#phase-discipline) rule 1). Both are pure Register-1 gates, so reclosing them is a
short run rather than a campaign, and phases 13–35 keep the seals they already hold — each is bound to the
snapshot it actually ran against, and this amendment does not touch what those gates cover.

**Vault before providers is now structural, not procedural.** Because a spec cannot be admitted until every
`SecretRef` it names resolves in Vault
([vault_pki_doctrine.md §3.4](../documents/engineering/vault_pki_doctrine.md#34-admission-proves-the-named-secret-exists-before-any-effect)),
no live provider phase can run before Phase 61 exists. The check ranges over the references a spec *names*,
so a spec naming none needs no Vault — which is what keeps Phases 36–39 free of any dependency on 34.

## Current implementation audit

**Current conclusion — 2026-08-19:** **No phase is Policy-conformant.**
[§C](development_plan_standards.md#c-status-vocabulary) reserves that term for a pass of the *current* gate,
and the generative re-baseline changed what every current gate covers. What the rows below record is an
**observed footprint**: a run that happened, against a contract that has since been superseded.

*The paragraphs that follow describe the pre-re-baseline conclusion and are retained as rationale.*

**Superseded conclusion — 2026-08-17:** Phases 0 and 1 were Policy-conformant; no other phase was.
[§C](development_plan_standards.md#c-status-vocabulary) reserves that term for a pass of the *current* gate,
and the current gate is [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15.
Phase 0's 2026-08-17 run is the first to satisfy it: it records the substrate, lane, and natural architecture
it executed on, and refuses a translated one. The current seal is the third of that day and covers
[Sprint 0.13](phase_00_documentation_suite.md#sprint-013-one-binary-many-roles-). Phase 1 followed the same
day on the host-ensure contract: the two tools its previous run declared missing are now acquired rather than
expected, so the phase seals on the host it stopped on rather than on a differently-provisioned one.
Every other row below stays at
**Observed footprint** or **Known partial**, which is a change of label, not a claim that the work is gone —
each phase's capability evidence stands as history and is what makes its rerun short.
The existing later-phase implementation still
uses legacy repository roots, system temp and data directories, user-home state, and host-global Docker
resources. The detailed pre-containment rows below are retained as historical capability observations; every
`Policy-conformant` label in them is invalidated for current status by the containment and
natural-architecture amendments alike.

The governed documentation lint and full Phase-0 verifier are sealed. The gate reports every remaining
containment migration as a shrink-only, owner-attributed deferral and writes all of its own state beneath
`.build/**`.

This is a static audit of clean commit `c8870a2` observed on **2026-08-11**. At inspection time it matched
`origin/master`; ignored paths, the effective source-closure boundary, reachable revision history, and
unreachable local objects were inspected separately. A clean or pushed commit is not automatically
policy-conformant. Exact counts, paths, historical findings, and actionable mismatches live in
[legacy_tracking_for_deletion_archive.md](legacy_tracking_for_deletion_archive.md#existing-code-divergence-snapshot--2026-08-11).

| Phase(s) | Progress | Observed state | Required next boundary |
|---|---|---|---|
| 0 | **Observed footprint** | 2026-08-17, resealed against the tree Phase 2 moved: the eleven-sided gate passes on natural `arm64`, untranslated, with 17 clean artifact rules, 49 seeded documentation negatives red at their own checks, and 37 surfaces joined to 77 implemented checks. The deferral total is 314, down from 876, because Phase 2 deleted every `r13` and `r15` row rather than re-owning it. The reseal also resolved the pre-implementation manifest pins and eleven contracts' artifact paths, which had named a pre-amendment ordinal since the ordering re-baseline | None. The next boundary belongs to Phase 26 |
| 1 | **Observed footprint** | 2026-08-17, resealed against the tree Phase 2 moved: the twelve-sided gate passes on natural `arm64`, untranslated. All 17 authored requirements resolve with none expected on the host, two independent resolutions admit the same 260 packages, the same graph resolves from the 1,965-file source snapshot alone, the representative set builds from an empty store, every probe matches its authored expectation, both mutants redden — the `drop-allow-newer` project regained the two sibling `source-repository-package` entries the merged package now needs, so it reddens at the seeded `proto`/`base` conflict rather than at an unknown package — and 40 surfaces join to 62 enumerated items | None. The next boundary belongs to Phase 26 |
| 2 | **Observed footprint** | 2026-08-17: the fourteen-sided gate passes on substrate `none`, lane `none`, natural `arm64`, untranslated. `test/`'s second level is exactly the seven role nouns over 1,084 files; fourteen package declarations are one, and `cabal build all --dry-run` and `cabal test all --dry-run` resolve against it; 468 authored paths, 216 build flags, and 43 `main-is` values carry a capability name rather than a phase ordinal; one mutant registry covers all 411 mutations, 99 of which no file named before; rules `r13` and `r15` report zero findings and the allowlist carries no row for either; all six committed mutants redden their own check and no other; 27 surfaces join to 27 enumerated items. The deferral total falls from 876 to 314. **Reopened by an observation on 2026-08-19**: `questions.txt` is tracked outside the section 2 target tree, so `target-tree-clean` reports one `r13` finding and the gate exits 1 | Untrack `questions.txt`; every other side is green |
| 8 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete twelve-sided gate passes: all owner joins/swaps, the independent flow matrix, three compile loci, six coverage classes, the owner-equality mutant, all ten metrics, and nine constructor-privacy checks pass; 40 surfaces join to 47 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 9 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, all nineteen mutants redden at their own loci, every result is derived from an observation, and 25 surfaces join to 25 run-time items. The rerun found Phase 2's mutant registry had dropped 101 rows whose mutation the owning gate materializes from its own code rather than from a file | None. The next boundary belongs to Phase 11 |
| 11 | **Observed footprint** | 2026-08-17: the ten-sided gate passes on natural `arm64`, untranslated. The JVM and TLC resolve from authored requirements and TLC identifies itself from a live banner probe; all 31 authored metrics match, every model-safety, spec-weakening, renderer-golden, and renderer-differential mutant is caught, 608 emitted `.tla`/`.cfg` files stay beneath `.build/**` and outside the 1,965-file source snapshot, 14 surfaces join to 39 run-time items, and the outside-host inventory is unchanged | None. The next boundary belongs to Phase 51 |
| 16 | **Observed footprint** | 2026-08-17: the thirteen-sided gate passes on natural `arm64`, untranslated. The real and io-sim interpreters agree from one reference reconciler, every authored fake-contract fault holds its outcome, the dropped-partition mutant reddens at its own locus, and 26 surfaces join to 36 run-time items. The rerun made Phase 2's mutant registry carry each capability's own vocabulary rather than flattening eight schemas into two columns | None. The next boundary belongs to Phase 30 |
| 17 | **Observed footprint** | 2026-08-17: the ten-sided gate passes on natural `arm64`, untranslated. All 12 authored results match, every per-invariant, mechanical, fairness, cutoff, and shared-resource mutant reddens, 34 emitted `.tla`/`.cfg` files remain beneath `.build/**` and outside the 1,965-file source snapshot, 15 surfaces join to 17 run-time items, and the outside-host inventory is unchanged | None. The next boundary belongs to Phase 35 |
| 18 | **Planned** | Created 2026-08-17 by the ordering re-baseline; no implementation footprint yet | Author the expected-outcome table, then model-check the DSL surfaces |
| 19 | **Planned** | Created 2026-08-17 by the ordering re-baseline; no implementation footprint yet | Separate the decision core, then replay it under the Phase-29 substrate |
| 25 | **Observed footprint** | 2026-08-17: the ten-sided gate passes on natural `arm64`, untranslated. The dhall-typecheck battery is green and all 18 authored metrics match after canonical normalization; every field-deletion, type-substitution, special-resource, and custom-arm mutant reddens; 18 surfaces join to 21 run-time items; generated results stay beneath `.build/**` and the outside-host inventory is unchanged. The rerun corrected an oracle root (`tests/oracle/dhall-typecheck/`) that named a directory the tree has never had, so the metrics are compared rather than skipped | None. The next boundary belongs to Phase 52 |
| 26 | **Observed footprint** | 2026-08-17: the thirteen-sided gate passes on natural `arm64`, untranslated. `dsl-spec` is green, every recorded metric is derived from an observation, and 24 surfaces join to 27 enumerated items. The `strace` observer is replaced by a substrate-portable argv observer with two mutants of its own; on its first run it caught three call sites reaching `dhall` through an ambient PATH lookup, and four validation-locus thresholds that had drifted from their own registry | None. The next boundary belongs to Phase 53 |
| 27 | **Observed footprint** | 2026-08-17: the twelve-sided gate passes on natural `arm64`, untranslated. 90 catalog entries reconcile to 106 registry subcases, the corpus is green with 14 dhall-typecheck and 13 gadt-decode negatives against 12 positives, and 24 surfaces join to 27 run-time items. The rerun found three of the four registry mutators no longer mutating anything — one pinned to an ordinal the re-baseline renumbered away — and two catalog pins left stale by the one-binary amendment | None. The next boundary belongs to Phase 54 |
| 28 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, the suite is green, all thirty-one mutants redden at their own loci, every result is derived from an observation, and 39 surfaces join to 44 run-time items | None. The next boundary belongs to Phase 17 |
| 29 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, the suite is green, all forty-five mutants redden at their own loci, every result is derived from an observation, and 56 surfaces join to 94 run-time items | None. The next boundary belongs to Phase 25 |
| 30 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, the suite is green, every seeded mutant reddens at its own locus, each result is derived from an observation, and 29 surfaces join to 36 run-time items | None. The next boundary belongs to Phase 26 |
| 31 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, the suite is green, all ten mutants redden at their own loci, and 34 surfaces join to 42 run-time items. The rerun corrected three gates whose item enumerator read the one registry's first column, which is the capability rather than the mutant id | None. The next boundary belongs to Phase 27 |
| 32 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. Every authored oracle holds its declared shape, the suite is green, every seeded mutant reddens at its own locus, and 28 surfaces join to 39 run-time items | None. The next boundary belongs to Phase 9 |
| 33 | **Observed footprint** | 2026-08-17: the eleven-sided gate passes on natural `arm64`, untranslated. The rendered-output goldens match byte for byte, every seeded mutant reddens at its own locus, each result is derived from an observation, and 31 surfaces join to 46 run-time items | None. The next boundary belongs to Phase 28 |
| 34 | **Observed footprint** | 2026-08-17: the thirteen-sided gate passes on natural `arm64`, untranslated. The Part-A kernel and Part-B boundary suites are green, the extension-astcheck AST checker holds its compile-fail seal, every mutant reddens at its own locus, and 40 surfaces join to 40 run-time items. The rerun added a third sanctioned network observer — Darwin's `sandbox-exec`, control-proven before it is trusted — and made the four fake boundary tools portable off Linux | None. The next boundary belongs to Phase 29 |
| 37 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete twelve-sided gate passes: three positives, ten exact negatives, graph/wire oracles, eight coverage classes, the compile seal, network isolation, all six mutants, and all ten metrics pass; 29 surfaces join to 46 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 38 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: registry, access, parity, epoch, independent-reference, closed-union, constructor-privacy, network-isolation, both mutants, and all eleven metrics pass; 40 surfaces join to 57 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 39 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: seven ports, two trusted links, eight exact errors, thirteen coverage classes, all seven mutants, and all twelve metrics pass; four closed sums and the independent handler/capability key sets are checked directly; 55 surfaces join to 85 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 40 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes: four independent projections, four byte-exact canonical artifacts, four independently derived digests, six finite demand cells, two fresh-process determinism checks, all six mutants, and all thirteen metrics pass; 55 surfaces join to 66 enumerated items; generated output, test scratch, Cabal state, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 41 | **Observed footprint** | The offline-language source/test/gate footprint exists; its prior pre-cluster result is invalidated | Migrate and rerun the current Phase-91 gate |
| 42 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete eleven-sided gate passes in resolved Chrome: two plans, five event arms, four independently derived traces, two DOM snapshots, three accessibility rows, five focus rows, four transport rows, CSP and WebSocket checks, all nine mutants, and all sixteen metrics pass; 66 surfaces join to 84 enumerated items; Node, Spago, PureScript, browser, Cabal, and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 43 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete thirteen-sided gate passes: seven HTTP rows, five access rows, five sanitized audit rows, five handler-effect rows, five startup rows, five public assets, five private probes, seven WebSocket rows, loopback-only OS observation, all nine mutants, and all nineteen metrics pass; 77 surfaces join to 94 run-time items; build/test scratch and host state remain contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 44 | **Observed footprint** | Historical, refreshed 2026-08-15: The complete thirteen-sided gate passes in resolved Chrome: two Dhall applications, five interactions, four exact visible states, four ordered effects, three access rows, five zero-leak denials, loopback-only OS observation, all five mutants, and all seventeen metrics pass; 58 surfaces join to 71 run-time items; the legacy `tests/` root is gone and all generated, build, browser, and host state remains contained. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 48, 81–82, 92 | **Known partial** | Browser/offline gate footprints exist; the contracts retain production compiler, broker, identity, object-store, Kubernetes/CNI, rollout, or provider multi-zone gaps | Close the named Register-2/3 gaps and rerun in numeric order |
| 50 | **Observed footprint** | 2026-08-19: the eleven-sided gate passes on substrate `none`, lane `none`, natural `arm64`, untranslated. `pb` is a Poetry distribution with a closed Click topology; `ruff`, `black` and `mypy --strict` with `disallow_any_explicit` pass over it, a token-aware scan finds no `Any`, `cast` or `type: ignore`, and 217 tests cover 1,039 statements and 290 branches at 100%. The absent → present → present replay performs five authored mutations on pass one and none on passes two and three; five refusing shims sat first on `PATH` and recorded no ambient lookup; every substrate's floor is well-formed and each refusal names its remedy; 36 surfaces join to 36 enumerated items and all four mutants redden their own check and no other | None. The next boundary belongs to Phase 51 |
| 51 | **Observed footprint** | 2026-08-19: the twelve-sided gate passes on substrate `none`, lane `none`, natural `arm64`, untranslated. An install step is a typed tool plus an argument vector rather than an uninterpretable string; `HostTool` gained the `Docker` arm so the engine is ensured through the one closed enum; a reconciler is a row whose applicability column is the only statement of its set; the driver re-resolves after every step and verifies with the predicate it probed with; and one `LiftContext` fold produces host, frame and container argv from one step list. 23 surfaces join to 23 enumerated items and all five mutants redden their own check and no other. The run also found `dsl-core` compiling a home module it never declared | None. The next boundary belongs to Phase 35 |
| 55 | **Observed footprint** | Historical, refreshed 2026-08-15: `python3 tools/bootstrap_coordinator_gate.py --execute` passes all eleven sides against a newly materialized pristine Incus guest. All six mutants are independently red, all sixteen metrics match, and 28 surfaces join to 30 run-time items. Tool acquisition, Cabal state, guest transport, build/evidence, production state, and marker-owned test state are repository-contained; the outside-host inventory is unchanged and the guest is destroyed. Attestation `sha256:cf31b7eb39b7419bc51375e18cc24e56aac1b697150029f52257be751dce4b66`, source `sha256:7503a6e8d86c0f95…`. None of it records the architecture it proved, so clause 15 leaves the result UNVERIFIED for every architecture | Rerun the amended gate, recording the substrate, lane, and natural architecture |
| 56 | **Known partial** | The catalog, acquisition ladder, pure/static checks, OCI file oracle, and registry standup have been observed. The bake that was observed is the pre-amendment dual-architecture one, whose non-native half was built and probed under emulation; the single-architecture bake this contract now specifies has never run | Rerun the narrowed gate on one host, natively, after Phase 19 reseals |
| 57 | **No footprint observed** | Authored 2026-08-16 by the natural-architecture amendment. No complementary-architecture bake, attestation, or index join exists | Author the oracles and mutants, then run the gate on an `arm64` host after Phase 37 seals |
| 58 | **Observed footprint** | The prior capability remains historical, but its exact Phase-37 handoff is superseded by the open image amendment. | Revalidate against the amended Phase-37 seal |
| 59 | **Observed footprint** | The prior capability remains historical pending the amended Phase-38 predecessor chain. | Revalidate after Phase 38 |
| 60 | **Observed footprint** | The prior capability remains historical pending the amended Phase-39 predecessor chain. | Revalidate after Phase 39 |
| 61 | **Observed footprint** | The prior capability remains historical pending the amended Phase-40 predecessor and Phase-37 handoff. | Revalidate after Phase 40 |
| 62–69 | **Known partial** | Phase 58's live run found the Phase-42 offloader defect; its registry correction and containment changes remain implemented. Phases 37–50 are blocked behind the open predecessor chain, and no current policy-conformant result exists for the range. | Resume Phase 58 only after Phases 31–36 reseal, then validate each later phase in numeric order |
| 70–73 | **Known partial** | Provider/AWS gate footprints exist, while the phase contracts explicitly record missing authenticated provider materialization, EBS/IAM behavior, node provisioning, audit, and leak-freedom | Complete the provider seams after predecessors close and run the live provider gates |
| 75–79, 83–84, 86, 91 | **Known partial** | Gate and test footprints exist. Phase 77 retains frozen sibling-source hashes and Phase 91 commits reference-program output; the range also retains scoped capability gaps in sibling lift, native transport, production topology, hardware, cleanup, or multi-zone behavior | Remove derived/hash expectations in their owning phases, close each capability gap, and rerun in numeric order on the required lane |
| 80 | **Observed footprint** | Pure and live/cache footprints exist; the prior `linux-cpu` result is invalidated by the artifact-policy amendment | Migrate and rerun the current Phase-70 gate |
| 3–7, 10, 12–15, 20–24, 35–36, 45–47, 49, 52–54, 74, 85, 87–90, 93–95 | **No footprint attributed** | The 2026-08-11 audit predates the generative re-baseline and was keyed to the old sequence. These ordinals are the twenty-one phases the re-baseline created and the twelve whose old ordinal the audit never listed, so no observation in this table was ever attributed to them | Author or re-author the contract, then run its gate in numeric order |
| 96+ | **No footprint observed** | This audit did not attribute an implementation footprint to an unnumbered later phase | Author a phase contract in numeric order before implementation |

The absence of a separately listed phase within a range does not hide its state: every integer in that range
inherits the row, and every ordinal in 0–95 appears in exactly one row.

**This audit is keyed to the current sequence but was taken against the old one.** It observed commit
`c8870a2` on 2026-08-11, before the generative re-baseline moved every ordinal; the `Phase(s)` column has been
re-keyed through the audit map in
[legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#the-audit-map), so a row names the phase that
*now* owns the capability the footprint was observed under. It does not follow that the footprint satisfies
that phase's current contract: every phase is reopened, and each row is an observation awaiting a fresh
attestation rather than a claim about the contract as it now reads. Any later code or plan change that affects
these observations must refresh this audit and the legacy register in the same documentation change.

## Phase overview

The table is an order-and-status index. It is read with the dated progress audit above, not as an assertion
that a blocked phase has no code. The linked phase document owns the phase-specific gate; every gate also
inherits the universal postcondition above.

| Phase | Name | Substrate | Lane | Register | Status | Validation contract |
|---|---|---|---|---|---|---|
| 0 | Documentation suite (whole DSL) | none | `none` | — | 🔄 Active — reopened 2026-08-19 by the generative re-baseline; the suite is being re-authored against it | [phase_0](phase_00_documentation_suite.md) |
| 1 | Toolchain spike | none | `none` | 1 | ⏸️ Blocked pending Phase-0 revalidation | [phase_1](phase_01_toolchain_spike.md) |
| 2 | Repository layout conformance and de-phased naming | none | `none` | 1 | ⏸️ Blocked pending Phase-1 revalidation | [phase_2](phase_02_repository_layout_conformance.md) |
| 3 | The artifact calculus | none | `none` | 1 | ⏸️ Blocked pending Phase-2 revalidation | [phase_3](phase_03_artifact_calculus.md) |
| 4 | The budget calculus | none | `none` | 1 | ⏸️ Blocked pending Phase-3 revalidation | [phase_4](phase_04_budget_calculus.md) |
| 5 | The lift calculus | none | `none` | 1 | ⏸️ Blocked pending Phase-4 revalidation | [phase_5](phase_05_lift_calculus.md) |
| 6 | The workflow calculus | none | `none` | 1 | ⏸️ Blocked pending Phase-5 revalidation | [phase_6](phase_06_workflow_calculus.md) |
| 7 | The evidence calculus | none | `none` | 1 | ⏸️ Blocked pending Phase-6 revalidation | [phase_7](phase_07_evidence_calculus.md) |
| 8 | Scoped identity kernel | none | `none` | 1 | ⏸️ Blocked pending Phase-7 revalidation | [phase_8](phase_08_scope_index.md) |
| 9 | Capacity core fold + topology relation | none | `none` | 1 | ⏸️ Blocked pending Phase-8 revalidation | [phase_9](phase_09_resource_index.md) |
| 10 | Composition across the five calculi | none | `none` | 1 | ⏸️ Blocked pending Phase-9 revalidation | [phase_10](phase_10_calculus_composition.md) |
| 11 | Formal-model EDSL (`Model`/`interpret`/`emitTLA`) | none | `none` | 1 | ⏸️ Blocked pending Phase-10 revalidation | [phase_11](phase_11_formal_model_kernel.md) |
| 12 | The amoebius explicit-state checker | none | `none` | 1 | ⏸️ Blocked pending Phase-11 revalidation | [phase_12](phase_12_explicit_state_checker.md) |
| 13 | The amoebius symbolic checker | none | `none` | 1 | ⏸️ Blocked pending Phase-12 revalidation | [phase_13](phase_13_symbolic_checker.md) |
| 14 | The amoebius refinement checker | none | `none` | 1 | ⏸️ Blocked pending Phase-13 revalidation | [phase_14](phase_14_refinement_checker.md) |
| 15 | The compile-fail fixture harness | none | `none` | 1 | ⏸️ Blocked pending Phase-14 revalidation | [phase_15](phase_15_compile_fail_harness.md) |
| 16 | Deterministic-simulation substrate | none | `none` | 2 | ⏸️ Blocked pending Phase-15 revalidation | [phase_16](phase_16_deterministic_sim_substrate.md) |
| 17 | Gateway-migration model (both branches) | none | `none` | 1 | ⏸️ Blocked pending Phase-16 revalidation | [phase_17](phase_17_gateway_migration_model.md) |
| 18 | DSL formal model | none | `none` | 1 | ⏸️ Blocked pending Phase-17 revalidation | [phase_18](phase_18_dsl_formal_model.md) |
| 19 | Reconcile decision core under deterministic simulation | none | `none` | 2 | ⏸️ Blocked pending Phase-18 revalidation | [phase_19](phase_19_reconcile_core_simulation.md) |
| 20 | The extension declaration | none | `none` | 1 | ⏸️ Blocked pending Phase-19 revalidation | [phase_20](phase_20_extension_declaration.md) |
| 21 | The per-extension laws L1-L5 | none | `none` | 1 | ⏸️ Blocked pending Phase-20 revalidation | [phase_21](phase_21_extension_laws_per_extension.md) |
| 22 | The compositional laws C1-C7 | none | `none` | 1 | ⏸️ Blocked pending Phase-21 revalidation | [phase_22](phase_22_extension_laws_compositional.md) |
| 23 | The security laws S1-S6 | none | `none` | 1 | ⏸️ Blocked pending Phase-22 revalidation | [phase_23](phase_23_extension_security_laws.md) |
| 24 | The generated conformance gate | none | `none` | 1 | ⏸️ Blocked pending Phase-23 revalidation | [phase_24](phase_24_conformance_gate_generator.md) |
| 25 | Dhall dhall-typecheck schema + smart-constructor prelude | none | `none` | 1 | ⏸️ Blocked pending Phase-24 revalidation | [phase_25](phase_25_dhall_schema_generation.md) |
| 26 | GADT-indexed IR + total decoder (gadt-decode) | none | `none` | 1 | ⏸️ Blocked pending Phase-25 revalidation | [phase_26](phase_26_gadt_decode_ir.md) |
| 27 | Illegal-state corpus + validation-locus ledger | none | `none` | 1 | ⏸️ Blocked pending Phase-26 revalidation | [phase_27](phase_27_illegal_state_covering.md) |
| 28 | Logical→physical storage geometry folds | none | `none` | 1 | ⏸️ Blocked pending Phase-27 revalidation | [phase_28](phase_28_storage_geometry_folds.md) |
| 29 | Execution-epoch + scheduler + accelerator + provider-root folds | none | `none` | 1 | ⏸️ Blocked pending Phase-28 revalidation | [phase_29](phase_29_execution_accelerator_folds.md) |
| 30 | Capability union + representational bind | none | `none` | 1 | ⏸️ Blocked pending Phase-29 revalidation | [phase_30](phase_30_capability_bind.md) |
| 31 | Whole-deployment provision seal + expansion | none | `none` | 1 | ⏸️ Blocked pending Phase-30 revalidation | [phase_31](phase_31_provision_seal.md) |
| 32 | InferenceEngine capability + accelerator provision | none | `none` | 1 | ⏸️ Blocked pending Phase-31 revalidation | [phase_32](phase_32_inference_accelerator_provision.md) |
| 33 | Pure `renderAll` + rendered-artifact oracles | none | `none` | 1 | ⏸️ Blocked pending Phase-32 revalidation | [phase_33](phase_33_render_manifest_oracles.md) |
| 34 | chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker | none | `none` | 1/2 | ⏸️ Blocked pending Phase-33 revalidation | [phase_34](phase_34_chain_kernel_boundary.md) |
| 35 | The amoebius image recipe | none | `none` | 1 | ⏸️ Blocked pending Phase-34 revalidation | [phase_35](phase_35_image_recipe_generation.md) |
| 36 | The closed transaction vocabulary | none | `none` | 1 | ⏸️ Blocked pending Phase-35 revalidation | [phase_36](phase_36_transaction_vocabulary.md) |
| 37 | Bounded UI-program schema | none | `none` | 1 | ⏸️ Blocked pending Phase-36 revalidation | [phase_37](phase_37_ui_program_schema.md) |
| 38 | UI authorization kernel | none | `none` | 1 | ⏸️ Blocked pending Phase-37 revalidation | [phase_38](phase_38_ui_authorization_kernel.md) |
| 39 | UI effect binding | none | `none` | 1 | ⏸️ Blocked pending Phase-38 revalidation | [phase_39](phase_39_ui_effect_binding.md) |
| 40 | UI plan compiler | none | `none` | 1 | ⏸️ Blocked pending Phase-39 revalidation | [phase_40](phase_40_ui_plan_compiler.md) |
| 41 | Offline language and paired plans | none | `none` | 1 | ⏸️ Blocked pending Phase-40 revalidation | [phase_41](phase_41_offline_language_plan.md) |
| 42 | Generic browser interpreter | none | `none` | 2 | ⏸️ Blocked pending Phase-41 revalidation | [phase_42](phase_42_ui_browser_interpreter.md) |
| 43 | UI-server boundary | none | `none` | 2 | ⏸️ Blocked pending Phase-42 revalidation | [phase_43](phase_43_ui_server_boundary.md) |
| 44 | Local UI composition | none | `none` | 2 | ⏸️ Blocked pending Phase-43 revalidation | [phase_44](phase_44_ui_local_composition.md) |
| 45 | Encrypted browser offline runtime | none | `none` | 2 | ⏸️ Blocked pending Phase-44 revalidation | [phase_45](phase_45_encrypted_browser_runtime.md) |
| 46 | Generated browser contracts and bundle | none | `none` | 1 | ⏸️ Blocked pending Phase-45 revalidation | [phase_46](phase_46_ui_contract_generation.md) |
| 47 | Generated checking tools and mutants | none | `none` | 1 | ⏸️ Blocked pending Phase-46 revalidation | [phase_47](phase_47_tool_and_mutant_generation.md) |
| 48 | The test-workflow algebra | none | `none` | 1 | ⏸️ Blocked pending Phase-47 revalidation | [phase_48](phase_48_test_workflow_algebra.md) |
| 49 | The self-referential gate suite | none | `none` | 1 | ⏸️ Blocked pending Phase-48 revalidation | [phase_49](phase_49_self_referential_gates.md) |
| 50 | The `pb` host-assertion CLI | none | `none` | 2 | ⏸️ Blocked pending Phase-49 revalidation | [phase_50](phase_50_host_assert_cli.md) |
| 51 | The host-ensure kernel | none | `none` | 2 | ⏸️ Blocked pending Phase-50 revalidation | [phase_51](phase_51_host_ensure_kernel.md) |
| 52 | Linux: sudoless Docker and the native image | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-51 revalidation | [phase_52](phase_52_linux_engine_bringup.md) |
| 53 | Apple: Homebrew, Colima, and the native image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked pending Phase-52 revalidation | [phase_53](phase_53_apple_engine_bringup.md) |
| 54 | Windows: WSL2 and the lifted Linux engine | windows | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-53 revalidation | [phase_54](phase_54_windows_engine_bringup.md) |
| 55 | Python bootstrap coordinator + substrate detect + single kind cluster | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-54 revalidation | [phase_55](phase_55_bootstrap_coordinator_kind.md) |
| 56 | The base image, the jit-build resolver, and the in-cluster registry | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-55 revalidation | [phase_56](phase_56_base_image_registry.md) |
| 57 | The complementary-architecture base image | apple | `linux-cpu/arm64` | 3 | ⏸️ Blocked pending Phase-56 revalidation | [phase_57](phase_57_complementary_arch_child.md) |
| 58 | Typed renderer + object reconciler | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-57 revalidation | [phase_58](phase_58_object_reconciler.md) |
| 59 | amoebius-capacity scheduler + bootstrap cutover | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-58 revalidation | [phase_59](phase_59_capacity_scheduler.md) |
| 60 | No-provisioner retained storage + lossless rebind | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-59 revalidation | [phase_60](phase_60_retained_storage.md) |
| 61 | Root Vault + PKI + built-in Haskell Vault client | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-60 revalidation | [phase_61](phase_61_vault_pki.md) |
| 62 | Platform backbone (MetalLB + MinIO + Pulsar HA) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-61 revalidation | [phase_62](phase_62_platform_backbone.md) |
| 63 | Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-62 revalidation | [phase_63](phase_63_platform_services_2.md) |
| 64 | Keycloak-owned ingress | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-63 revalidation | [phase_64](phase_64_keycloak_ingress.md) |
| 65 | Live DSL deploy via the replicas=1 control-plane daemon | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-64 revalidation | [phase_65](phase_65_live_dsl_deploy.md) |
| 66 | Tenant/provider provisioning | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-65 revalidation | [phase_66](phase_66_app_tenancy.md) |
| 67 | Native Pulsar client (CBOR) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-66 revalidation | [phase_67](phase_67_pulsar_client.md) |
| 68 | Live subject/tenant isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-67 revalidation | [phase_68](phase_68_user_tenant_isolation_live.md) |
| 69 | Content store + workflow runtime (Pulsar-Failover single-writer) | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-68 revalidation | [phase_69](phase_69_content_store_workflow.md) |
| 70 | Owner-scoped UI projection runtime | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-69 revalidation | [phase_70](phase_70_ui_projection_runtime.md) |
| 71 | Release lifecycle | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-70 revalidation | [phase_71](phase_71_release_lifecycle.md) |
| 72 | Atomic immutable UI-program release | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-71 revalidation | [phase_72](phase_72_ui_program_release.md) |
| 73 | WireGuard network fabric | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-72 revalidation | [phase_73](phase_73_network_fabric_wireguard.md) |
| 74 | Multi-cluster spawn + geo-replication | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-73 revalidation | [phase_74](phase_74_multicluster_spawn_georepl.md) |
| 75 | Gateway-migration drills + model-correspondence | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-74 revalidation | [phase_75](phase_75_gateway_migration_drills.md) |
| 76 | Provider Pulumi deploy-from-inside + enveloped checkpoint | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-75 revalidation | [phase_76](phase_76_provider_deploy_checkpoint.md) |
| 77 | Hostless provider child + convergence + Lease handoff | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-76 revalidation | [phase_77](phase_77_provider_child_bringup.md) |
| 78 | Per-PV EBS decoupling + create-vs-delete credential | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-77 revalidation | [phase_78](phase_78_provider_ebs_credential.md) |
| 79 | Dynamic node provisioning by signal + leak-free provider gate | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-78 revalidation | [phase_79](phase_79_provider_dynamic_nodes.md) |
| 80 | Determinism kernel + jit-build CacheBudget cache | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-79 revalidation | [phase_80](phase_80_determinism_jitcache.md) |
| 81 | Single-tenant low-code UI live path | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-80 revalidation | [phase_81](phase_81_ui_single_tenant_live.md) |
| 82 | Multi-tenant low-code UI isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-81 revalidation | [phase_82](phase_82_ui_multi_tenant_live.md) |
| 83 | UI rollout, projection catch-up, and reconnect | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-82 revalidation | [phase_83](phase_83_ui_rollout_reconnect.md) |
| 84 | Initial online UI multi-zone high availability | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-83 revalidation | [phase_84](phase_84_ui_ha_multizone.md) |
| 85 | Offline replay and durable receipts | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-84 revalidation | [phase_85](phase_85_offline_replay_receipts.md) |
| 86 | Offline blobs and partition isolation | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-85 revalidation | [phase_86](phase_86_offline_blobs_isolation.md) |
| 87 | Offline release and schema evolution | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-86 revalidation | [phase_87](phase_87_offline_release_evolution.md) |
| 88 | Offline multi-zone continuity | linux-cpu → provider | `linux-cpu/amd64 → provider` | 3 | ⏸️ Blocked pending Phase-87 revalidation | [phase_88](phase_88_offline_multizone_continuity.md) |
| 89 | Apple-Metal host compute daemon | apple | `metal` | 3 | ⏸️ Blocked pending Phase-88 revalidation | [phase_89](phase_89_apple_metal_host_daemon.md) |
| 90 | The live test topology and elevated harness | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-89 revalidation | [phase_90](phase_90_test_topology_live.md) |
| 91 | The infernix inference core, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-90 revalidation | [phase_91](phase_91_infernix_rederivation.md) |
| 92 | The infernix workflow and artifact contracts, re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-91 revalidation | [phase_92](phase_92_infernix_ui_rederivation.md) |
| 93 | The jitML numerical core, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked pending Phase-92 revalidation | [phase_93](phase_93_jitml_rederivation.md) |
| 94 | The jitML training and checkpoint contracts, re-derived | linux-cuda | `cuda` | 3 | ⏸️ Blocked pending Phase-93 revalidation | [phase_94](phase_94_jitml_ui_rederivation.md) |
| 95 | The multi-tenant web application re-derived | linux-cpu | `linux-cpu/amd64` | 3 | ⏸️ Blocked pending Phase-94 revalidation | [phase_95](phase_95_webapp_rederivation.md) |
| 96+ | Later phases | varies | varies | — | 📋 Planned | [later_phases](later_phases.md) |

## Related Documents

- [Documentation Standards](../documents/documentation_standards.md)
- [Engineering Doctrine Index](../documents/engineering/README.md)
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [Substrates](substrates.md)
- [Legacy Tracking for Deletion](legacy_tracking_for_deletion.md)
