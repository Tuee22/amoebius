# Decision Log

> **Purpose**: Keep the one append-only register of design decisions that change frozen doctrine or the plan, each naming what it decided, what it rejected, and which documents it amends.
> **Read this if**: a doctrine or plan-rulebook sentence must change, or the reason a document says what it says is needed.

This document records decisions. It is not the legacy register, which explains active repository divergence,
and it is not the status tracker, which reports the validation frontier. A reader needs only the
[documentation standards](./documentation_standards.md) to use it.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: AGENTS.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/validation_frame_doctrine.md, documents/glossary.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents

- [1. Entry contract](#1-entry-contract)
- [2. Entries](#2-entries)
- [3. Errata register](#3-errata-register)
- [Related Documents](#related-documents)

## 1. Entry contract

An entry is one `### DL-NNNN — <title>` heading under [§2](#2-entries). Identifiers increase strictly and are
never reused. An entry is appended, never edited after it lands, except to fill its `Replaced by` field when
a later entry supersedes it.

Every entry carries these one-line fields in this order:

1. `**Date**:` the calendar date the decision was taken.
2. `**Decision**:` the rule adopted, in specification voice.
3. `**Rejected alternatives**:` the alternatives considered and the property each could not provide.
4. `**Affected documents**:` at most five repository paths; a deleted path is marked `(deleted)`.
5. `**Replaces**:` an earlier entry identifier, or `N/A`.
6. `**Replaced by**:` a later entry identifier, or `N/A`.

An entry that resolves a contradiction between two documents adds `**Contradiction**:` before `Decision`,
quoting the two conflicting anchors.

A frozen document changes its body only in a change that also lands or amends an entry naming that document,
and the amended passage links the entry. The frozen set is defined by
[`documentation_standards.md` §17](./documentation_standards.md#17-the-doctrine-freeze). Historical prose
elsewhere in the corpus links an entry here rather than a dated audit narrative.

The log itself is exempt from whole-file freeze comparison because entries are individually digested by the
implementing session's plan-decisions module, which is owed by
[Phase 0](../DEVELOPMENT_PLAN/phase_00_documentation_suite.md). Until that module exists, the exemption is a
specification, not an observed property.

## 2. Entries

### DL-0001 — Substrates are a closed catalog with one profile site

**Date**: 2026-09-17
**Contradiction**: [`substrate_doctrine.md` §4](./engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux) treated a new substrate as an extension; [`extension_conformance_doctrine.md` §8](./engineering/extension_conformance_doctrine.md#8-a-hardware-substrate-is-a-catalog-member-with-a-profile) titled a hardware substrate an extension too.
**Decision**: The substrate axis is a closed four-member catalog owned by the substrate doctrine, with exactly one `SubstrateProfile` site that maps a catalog member to its natural architecture, lanes, and host frame. An extension declares the lane it requires through `extRequiresLane`; it never introduces a substrate. Adding a substrate family is a catalog edit plus a new entry here, never an extension.
**Rejected alternatives**: An open substrate-as-extension seam. It could not provide a total `lanesOf`, a decidable natural-architecture refusal, or a closed placement domain for the capacity fold.
**Affected documents**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/extension_conformance_doctrine.md`, `documents/engineering/capability_extension_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0002 — One ExtensionSpec record is the extension seam

**Date**: 2026-09-17
**Contradiction**: [`dsl_doctrine.md` §4](./engineering/dsl_doctrine.md#4-total-composability) spelled an `ExtensionSpec` record while [`capability_extension_doctrine.md` §3](./engineering/capability_extension_doctrine.md#3-the-provide-and-require-contract) and [`extension_conformance_doctrine.md` §2](./engineering/extension_conformance_doctrine.md#2-what-an-extension-is) spelled a different `ExtensionDeclaration` seam and a closed `ExtensionName` enumeration.
**Decision**: The seam is one `ExtensionSpec` record with ten fields: `extId :: ExtensionId`, `extConfig`, `extProvides`, `extRequires`, `extRequiresLane`, `extChain`, `extUiHandlers`, `extMonitoring`, `extDeclaration`, and `extSourceSeal`. The declaration is one field of that record. `ExtensionName` is retired; identity is the `ExtensionId` newtype. The record is spelled once, in the DSL doctrine; every other document links it.
**Rejected alternatives**: Keeping the declaration as the seam and deriving the specification from it. It could not carry a decoder, a chain, handlers, or a source seal, so admission had nothing to link into the shipped binary.
**Affected documents**: `documents/engineering/dsl_doctrine.md`, `documents/engineering/capability_extension_doctrine.md`, `documents/engineering/extension_conformance_doctrine.md`, `documents/engineering/monitoring_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0003 — Business logic is defined

**Date**: 2026-09-17
**Contradiction**: [`app_vs_deployment_doctrine.md` §2](./engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is) named business logic without defining its admissible form; [`low_code_ui_runtime_doctrine.md` §7](./engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates) described an update algebra that no document owned.
**Decision**: Business logic is the set of tenant-parameterised, total, first-order rules over typed application state and events. It is expressed as `UiSource` update rules and expressions over a closed pure-function catalog and realised through the typed effect-port catalog. Anything outside that form is an astcheck-admitted Haskell adapter linked into the binary. The definition is owned by the app-versus-deployment doctrine; the algebra is owed by [Phase 8](../DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md).
**Rejected alternatives**: Leaving logic to linked Haskell only. It could not be authored by an operator or checked by the DSL. A general-purpose embedded language. It could not be total or decidable at check time.
**Affected documents**: `documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/glossary.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0004 — The typed spec records are spelled once

**Date**: 2026-09-17
**Contradiction**: [`dsl_doctrine.md` §4](./engineering/dsl_doctrine.md#4-total-composability) and [`app_vs_deployment_doctrine.md` §11](./engineering/app_vs_deployment_doctrine.md#11-what-this-document-does-not-own) each carried a partial spelling of the root specification, and neither named the record that reaches the shipped binary.
**Decision**: `RootInForceSpec`, `ClusterSpec`, `TopologySpec`, `AppSpec`, and `DeploymentRules` are spelled once, in the DSL doctrine's typed-spec subsection, in specification voice and owed by [Phase 3](../DEVELOPMENT_PLAN/phase_03_typed_spine.md). The app-versus-deployment doctrine links that subsection from its ownership table and restates nothing.
**Rejected alternatives**: A stringly structural node tree as the canonical model. It could not make an illegal topology unrepresentable or give the bind stage a typed input.
**Affected documents**: `documents/engineering/dsl_doctrine.md`, `documents/engineering/app_vs_deployment_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0005 — The documentation checker is a standalone package

**Date**: 2026-09-17
**Decision**: The documentation checker becomes a standalone package with a recorded size cap and no dependency on the validation kernel. Its negatives are Haskell-rendered corpora beneath `.build/docs/**`, never conditional-compilation branches in the checker itself. It checks the decision-log structure, the frozen baseline, the three-mood honesty rule, gate-specification block equality, and the status vector.
**Rejected alternatives**: Keeping the checker inside the validation kernel. Its kernel imports made every kernel deletion a documentation-gate change, and its conditional-compilation mutants measured the checker rather than the corpus.
**Affected documents**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/phase_00_documentation_suite.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0006 — The honesty backlog is struck or re-mooded

**Date**: 2026-09-17
**Decision**: Every passage that asserted built machinery in the indicative without a receipt-backed gate is struck or re-mooded into specification voice with an "owed by" link. The three-mood rule in [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) becomes normative. Implementation ledgers inside doctrine are removed; the tracker's dated audit narrative is replaced by a pointer to this entry and the legacy register.
**Rejected alternatives**: Keeping dated "observed" paragraphs as historical context. Six validation cycles quoted them as evidence, so their presence changed status decisions while their truth was never re-established.
**Affected documents**: `documents/engineering/dsl_doctrine.md`, `documents/engineering/extension_conformance_doctrine.md`, `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/glossary.md`, `DEVELOPMENT_PLAN/README.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0007 — Certification generation 2 replaces the validation kernel

**Date**: 2026-09-17
**Decision**: The validator is replaced by the retained custody core plus one generic gate runner under a fourteen-thousand-line ratchet. A gate is green only when the shipped product binary, fed a runner-perturbed input, produces bytes an independent oracle executable accepts, and runner-generated mutants in shipped modules change those bytes. Generation identifiers are the verifier's content address. Generation-1 stores are archived, never deleted. The executable splits into `amoebius` for the product and `amoebius-validate` for the verifier.
**Rejected alternatives**: Hardening the existing kernel again. Its per-phase runners re-derived every gate row from their own suites' output, so each hardening cycle measured the validator and left the product unmeasured.
**Affected documents**: `documents/engineering/gate_runner_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`, `documents/engineering/conformance_harness_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0008 — Plan re-sequence into a vertical slice

**Date**: 2026-09-17
**Decision**: Phases 3 through 49 are replaced by seven slice phases 3 through 9 over one growing example corpus. Ordinals 10 through 49 are reserved and unoccupied. Phases 50 through 95 keep their ordinals, paths, and slugs. The contracts of Phases 0, 1, 2, 50, 51, 52, 55, 70, and 72 are reopened under [`development_plan_phase_model.md` §N](../DEVELOPMENT_PLAN/development_plan_phase_model.md#n-reopening-and-amending-a-phase). Generation-1 receipts are recorded incompatible. The complete audit map lives in the [legacy register](../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#7-the-audit-map). The typed reset cause is `ResetCause { validatorGap = "gates measured the harness", productGap = LTD-DSL-001 }`. Until the reopened Phase 0 reconciles the checker, the existing checker reports the reserved gap as missing phases, the tracker and identity table as the wrong cardinality, and Phase 50's predecessor edge as non-adjacent; those findings are expected and are the reconciliation target.
**Rejected alternatives**: Renumbering 50 through 95 to close the gap. It would have churned forty-six hardware contracts, their evidence directories, and every inbound link for no semantic gain. Keeping 3 through 49 and adding slices beside them. It would have preserved thirty-four placeholder claims that were sealed six times without the DSL changing.
**Affected documents**: `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/overview.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0009 — Status authority is one human act per transition

**Date**: 2026-09-17
**Decision**: An agent implements sprint seams, runs `amoebius-validate preview phase NN`, which mints nothing, and drafts documents. An agent never edits a status line or applies a status patch. The human runs `sudo amoebius-validate accept --phase NN`, which prints what it is about to sign, signs and applies exactly one phase's patch, and stops. One phase advances per accept. A reset is receipt-bearing and names both a validator gap and a product-gap legacy identifier. The change that lands this entry is the last hand-applied status edit: Phase 0 Active and every other phase Blocked.
**Rejected alternatives**: Automatic continuation through consecutive phases after each pass. It licensed every bulk status flip in the plan's history, because whoever ran the validator held status authority.
**Affected documents**: `AGENTS.md`, `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0010 — Host precondition for agent sessions

**Date**: 2026-09-17
**Decision**: Agent sessions run under a user identity with no sudoers entry and no read access to the issuer key. Receipt issuance, reseed, reset, govern, and demo are human acts from a password-sudo account. The supervisor refuses to issue when agent environment markers are present. A cached sudo timestamp in an agent shell is a host defect the human corrects before any gate is accepted.
**Rejected alternatives**: Relying on the validator's own custody checks under a shared user. A cached timestamp let agent shells run root re-seeds, which superseded nineteen generation-1 stores in three days.
**Affected documents**: `AGENTS.md`, `documents/engineering/validation_frame_doctrine.md`
**Replaces**: N/A
**Replaced by**: DL-0013

### DL-0011 — The honesty rule scope and trigger

**Date**: 2026-09-17
**Decision**: The three-mood rule of [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) measures doctrine, the root guides, and the plan rulebooks and indexes; a phase contract is specification by construction and the two registers exist to name identifiers, so they are outside its scope. A paragraph names machinery when a backticked span is a module of this repository or a concrete repository source file; a layout glob, a bare extension, or a sibling project's path is not a claim, and a sibling path is spelled with that project's prefix so the distinction is visible in the text. The standalone checker of [DL-0005](#dl-0005--the-documentation-checker-is-a-standalone-package) implements exactly this trigger and scope.
**Rejected alternatives**: Measuring every governed paragraph, including phase contracts and registers. A sprint's implementation field and a register row name modules by design, so the rule would flag the documents whose purpose is to name what is owed. Treating every `src/`-rooted span as this repository's path. Sibling projects share that layout, so their evidence paragraphs would be forced into an "owed by" that owes nothing.
**Affected documents**: `documents/documentation_standards.md`, `documents/engineering/manifest_generation_doctrine.md`, `documents/engineering/release_lifecycle_doctrine.md`, `documents/engineering/service_capability_doctrine.md`, `src/doc-check/Amoebius/Doc/Governance.hs`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0012 — The hygiene row's roots, run-module pattern, and run-directory convention

**Date**: 2026-09-18
**Decision**: The kernel budget counts every Haskell line under `src/validation-kernel` and `src/gate-spec`; the documentation checker under `src/doc-check` carries its own recorded cap of seven thousand lines, and the plan-decisions library is data the row observes without a cap. A per-phase run module is a module whose path segment ends in `Run` (`PhaseZeroRun`, `ArtifactCalculusRun/Internal.hs`); the generic `Runner` and its submodules are not run modules. The refusal of a second definition of a vocabulary type measures the validator roots; a duplicate elsewhere under `src/` is observed on the row and owed to the phase that owns the vocabulary library, so the seed gate cannot be blocked by product debt a later phase closes. A suite receives the run's suite directory as its one argument and writes its bytes there; the area's oracle executable receives the same directory and prints its ledger to standard output; the runner reads that ledger and the oracle's exit and holds the verdict.
**Rejected alternatives**: Reading `*Run*` literally, which would refuse the one runner the doctrine requires. Counting the checker inside the kernel budget, which would spend half of it on a package the kernel never links. Letting each area choose its own suite-to-oracle transport, which would leave the runner unable to digest the bytes uniformly.
**Affected documents**: `AGENTS.md`, `documents/engineering/gate_runner_doctrine.md`, `src/validation-kernel/Amoebius/Validation/Runner/Hygiene.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0013 — Validation authority is mechanical and receipts are reproducible

**Date**: 2026-09-18
**Decision**: Every verifier command is agent-run and none requires a privilege the agent lacks. `accept` runs the complete gate and, when every row is green, records the receipt, writes its reproducible digest as `**Receipt**: <digest>` on the line after the Done status in the phase document, and applies exactly one phase's status patch; one phase per accept is a property of the recorded-frontier code, not of the operator. A receipt is a content-addressed record of one runner execution, not a signature: its reproducible digest covers the specification digest, the closure digest, the verifier digest, the governance digest, the ordered row verdicts, the oracle ledger digest, and the kill-table loci and outcomes, and `replay` re-runs the gate of every Done phase whose store record is absent or was recorded under another verifier or governance digest, refreshing the record and the digest beside the status when the re-run is green as an identity status projection; a receipt whose re-run is red is void and the next gate refuses `PredecessorNotReproduced`. The store is the ignored `.build/certification/**` tree with one directory per verifier content address; there is no issuer key, no reseed act, no governance act, and no agent-shell tripwire. A reset stays receipt-bearing and still names a decision identifier and a product-gap legacy identifier with an owning phase. Of DL-0009, the sentences that made `accept` a human act are superseded; the rules that an agent never hand-edits a status line and that a reset names a product gap stand.
**Rejected alternatives**: A root-only issuer key and a password-sudo account, which cost three root commands per phase and a cached-sudo host defect for a signature that proves identity rather than execution. A second unprivileged account, which keeps the ceremony and proves the same thing. A passphrase-protected key, which remains a human act per phase. Each stopped the agent from closing one gate and starting the next, which is the workflow the plan exists to run.
**Affected documents**: `AGENTS.md`, `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
**Replaces**: DL-0010
**Replaced by**: N/A

### DL-0014 — Phase 0 accepted: its owed-by paragraphs become observed implementations

**Date**: 2026-09-18
**Decision**: With Phase 0 recorded Done under a reproducible receipt, every paragraph that said its machinery was owed by Phase 0 is re-mooded into an observed implementation citing `[GateSpec:documentation_suite]`, as [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) requires once the owing phase is Done. The citation resolves only while that phase's status line is Done; the checker refuses a citation of a phase that is not.
**Rejected alternatives**: Leaving the "owed by" wording in place. The rule makes it a finding once the phase is Done, and a paragraph that keeps promising delivered machinery reads as a claim still pending. Rendering the paragraphs as historical results. They describe current machinery under a current receipt, not an invalidated result.
**Affected documents**: `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/system_components.md`
**Replaces**: N/A
**Replaced by**: N/A

## 3. Errata register

Each erratum names the passage corrected and the entry that decided the correction. The corrected passage
links the entry; this table is the index.

| Erratum | Document and section | Correction | Entry |
|---|---|---|---|
| E1 | `substrate_doctrine.md` §4; `extension_conformance_doctrine.md` §8 | A substrate is a catalog member with a profile, never an extension. | [DL-0001](#dl-0001--substrates-are-a-closed-catalog-with-one-profile-site) |
| E2 | `dsl_doctrine.md` §4; `capability_extension_doctrine.md` §3; `extension_conformance_doctrine.md` §2 and §3 | One `ExtensionSpec` record, spelled once; `ExtensionName` retired. | [DL-0002](#dl-0002--one-extensionspec-record-is-the-extension-seam) |
| E3 | `app_vs_deployment_doctrine.md` §2; `low_code_ui_runtime_doctrine.md` §7 | Business logic defined; the algebra owed by Phase 8. | [DL-0003](#dl-0003--business-logic-is-defined) |
| E4 | `dsl_doctrine.md` §4; `app_vs_deployment_doctrine.md` §11 | The typed spec records spelled once, owed by Phase 3. | [DL-0004](#dl-0004--the-typed-spec-records-are-spelled-once) |
| E5 | Implementation ledgers in `dsl_doctrine.md`, `extension_conformance_doctrine.md`, `low_code_ui_runtime_doctrine.md`, and the tracker | Struck. | [DL-0006](#dl-0006--the-honesty-backlog-is-struck-or-re-mooded) |
| E6 | False present tense about unbuilt machinery across the doctrine suite and the glossary | Re-mooded into specification voice with "owed by" links. | [DL-0006](#dl-0006--the-honesty-backlog-is-struck-or-re-mooded) |
| E7 | Sibling-project source paths in `manifest_generation_doctrine.md` §3, `release_lifecycle_doctrine.md` §8, and `service_capability_doctrine.md` §7 | Spelled with the sibling project's prefix; outside the honesty trigger. | [DL-0011](#dl-0011--the-honesty-rule-scope-and-trigger) |

## Related Documents

- [Documentation standards](./documentation_standards.md) — the freeze rule this log serves
- [Legacy register](../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — active divergence and the audit map
- [Development-plan tracker](../DEVELOPMENT_PLAN/README.md) — the validation frontier
- [Gate-runner doctrine](./engineering/gate_runner_doctrine.md) — the validator that DL-0007 specifies
- [Phase 0](../DEVELOPMENT_PLAN/phase_00_documentation_suite.md) — the phase that implements the decisions above
