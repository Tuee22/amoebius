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
**Referenced by**: AGENTS.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_typed_spine.md, DEVELOPMENT_PLAN/phase_04_witness_manifests_capacity_storage.md, DEVELOPMENT_PLAN/phase_05_substrates_lanes_image_recipe.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/phase_08_ui_program_language_binding.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_90_test_topology_live.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/service_capability_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/engineering/validation_frame_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/illegal_state_lifecycle.md, documents/reading_order.md
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

### DL-0015 — Accepted validation records are tracked historical evidence

**Date**: 2026-09-23
**Decision**: A successful `accept` or `replay` publishes one immutable, content-addressed validation bundle under `validation-records/generation-<verifier16>/receipts/phase-NN-<reproducible64>-<bundle64>/`. The bundle digest names the exact final receipt and evidence, so distinct run transcripts with the same reproducible digest occupy distinct directories. The seven admitted files are `receipt.tsv`, `receipt.tsv.sha256`, `candidate.tsv`, `kill-table.tsv`, `outcome.tsv`, `oracle-ledger.tsv`, and `observer.tsv`. These are verifier-issued observations of a completed gate, not behavioral source, a semantic oracle, a generator input, or a substitute for re-execution. The tracked archive is the canonical durable record; `.build/**` contains disposable runs, tools, inputs, and optional receipt caches. A source scan admits only this exact archive class, validates its custody and naming, and excludes its historical bytes from the source closure they describe. Earlier bundles remain immutable when a later replay produces another receipt. The human commits the bundle and status change together.
**Rejected alternatives**: Keeping the only record beneath ignored `.build/**` loses the evidence whenever local scratch is removed. Treating the phase document's digest as the complete record preserves a claim but not its ordered observations. Tracking all run output would turn temporary tools, generated source, and potentially unbounded or sensitive observations into repository inputs.
**Affected documents**: `AGENTS.md`, `documents/documentation_standards.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/generated_artifacts_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0016 — Acceptance and replay publish the archive with the status projection

**Date**: 2026-09-23
**Decision**: A candidate gate still runs against an unchanged tracked source snapshot and writes temporary evidence beneath `.build/**`. After a complete verified pass and final status postimage, `accept` writes the immutable canonical bundle beside its exact status and receipt-line projection; `replay` runs Done gates in numerical order, re-acquires status after each refresh, and writes a new bundle and refreshed receipt line for every successful re-run. Archive publication is a bounded post-gate write, not a permitted candidate mutation. Before using a Done predecessor, the verifier must exact-read and validate its bundle and check its digest and current compatibility; missing or tampered evidence fails closed. A predecessor bundle may be either committed in the current source ancestry or produced by an earlier verified `accept` in the same worktree. An uncommitted bundle is admissible only after the verifier exact-reads it, binds its status postimage and accepted closure to the current source, and fully re-derives that predecessor gate at the current verifier and governance digests; a closure digest comparison alone is insufficient. Human commit makes the series durable but is not an intermediate phase gate. The lost Phase-0 and Phase-1 scratch stores provide no evidence by themselves: fresh Phase-0 and then Phase-1 gate runs produce new receipts. Old phase-document digests remain historical facts only and are replaced by the new receipts after successful replay.
**Rejected alternatives**: Reconstructing the destroyed observations from their digests is impossible. Trusting a committed Done line without an inspectable record repeats the original custody gap. Requiring the entire historical scratch tree in Git would violate the source and containment boundary.
**Affected documents**: `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/phase_00_documentation_suite.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0017 — Phase 1 verifies pinned bytes without an operator keyring

**Date**: 2026-09-23
**Decision**: Phase 1 requires the seven exact `GenesisTrust` files, including three signature files, at their independently authored byte counts and SHA-256 digests. The signature files remain opaque pinned inputs; neither an operator keyring nor `gpgv` is required or invoked, and no signature-verification verdict is claimed. The two pinned publisher-supplied `SHA256SUMS` files must each name the archive digest fixed by the Haskell pins; missing, corrupted, or disagreeing files refuse at their pin or manifest loci. Two contained offline acquisitions must agree on actual executable identities and elaborated plans. This establishes reproducibility and integrity relative to the fixed pins, while publisher identity and the origin of the pins remain explicit unverified assumptions. The former Phase-1 signature-positive and `SignatureMismatch` cases are replaced by pinned-manifest agreement and absence/corruption negatives for the pinned signature bytes. Pre-barrier gates use the pinned, network-independent toolchain without treating a public-key check as an available prerequisite.
**Rejected alternatives**: Requiring an operator keyring makes an unavailable external file a gate prerequisite without establishing how its authority was acquired. Calling a matching `.sig` digest a verified signature would claim publisher identity from opaque bytes. Dropping the signature files from the seven-pin contract would silently change the bootstrap input rather than make their limited role explicit.
**Affected documents**: `AGENTS.md`, `DEVELOPMENT_PLAN/phase_01_toolchain_spike.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0018 — Plan claims follow the keyless gate's observed scope

**Date**: 2026-09-23
**Decision**: The phase plan describes Phase 1 as reproducible relative to seven fixed size-and-digest pins, with publisher identity and pin origin unverified. The ordinary `toolchain-report` command verifies pins, manifest agreement, identities, and probe output; it does not run contained acquisition unless explicitly given `--acquire`. The toolchain suite separately acquires twice and elaborates a dependency plan under each acquired toolchain; those acquisitions do not themselves build the project twice. Phase 0's finite custody contract is the six current record and preflight controls, without an issuer key, agent-marker refusal, or signed-receipt supervisor. Phase 2 does not require a publisher keyring to use the Phase-1 predecessor. General cleanroom requirements retain actual executable-byte and boundary checks without silently promoting fixed-pin integrity into proof of publisher identity.
**Rejected alternatives**: Retaining the former issuer and signature prose would describe commands and trust boundaries absent from the compiled gates. Calling dependency-plan elaboration a second project build would make the Phase-1 claim broader than its observations. Leaving a keyring requirement in Phase 2 would block a gate for an input no current Phase-1 contract admits.
**Affected documents**: `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/phase_00_documentation_suite.md`, `DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0019 — Red replay leaves an immutable revocation record

**Date**: 2026-09-23
**Decision**: A red `replay` appends a verifier-issued, content-addressed void record at `validation-records/generation-<verifier16>/voids/phase-NN-<targetBundle64>-<void64>.tsv`. Its canonical bytes bind the full target bundle's repository-relative path, phase, former reproducible digest, current verifier and governance digests, failure observation digest and reason, and issuance time; `void64` is the SHA-256 of those bytes. A void marker is the second narrowly admitted tracked historical-observation class beside accepted bundles, not semantic source or an oracle. For the current generation, the archive reader selects the unique bundle with the latest `receiptIssuedAt` for each phase before applying void markers. Reader/preflight fails closed on ties or a replay bundle whose issuance is not newer than the current bundle; such a bundle cannot become the current pointer. The verifier exact-reads marker and target, and excludes a voided selected bundle from predecessor use. It may not fall back to an older same-digest bundle. A subsequent complete green replay publishes a distinct bundle with a later issuance time and establishes it as current, even when its reproducible digest equals the old one. The Done status remains until green replay or an explicit verifier `reset`, while the missing reproduced predecessor prevents a later gate from advancing. The human commits void records with the related status or later recovery change for durability.
**Rejected alternatives**: Leaving a red replay only in ignored `.build/**` loses the reason an accepted record ceased to count when scratch is removed. Editing or deleting the old bundle erases historical evidence. Choosing any other bundle with the same receipt digest would silently bypass the failed replay.
**Affected documents**: `AGENTS.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0020 — Revocation observations share the non-source archive boundary

**Date**: 2026-09-23
**Decision**: The narrowly admitted `validation-records/**` historical-evidence class contains both accepted bundles and verifier-issued red-replay void markers. A void marker is an observation of failed reproduction, never a generated behavioral output, semantic oracle, or status transition. The phase model may therefore continue to display Done while the current receipt is void and unavailable as a predecessor; only a later complete green replay or explicit verifier reset resolves that state. The general rule that generated behavioral artifacts remain ignored beneath `.build/**` is unchanged.
**Rejected alternatives**: Describing void markers as ordinary generated run output would put their only copy in disposable scratch. Turning a red replay into a hand-edited status line would bypass the verifier's one-phase status authority.
**Affected documents**: `documents/engineering/generated_artifacts_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/overview.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0021 — Cleanroom input names respect the fixed-pin trust boundary

**Date**: 2026-09-23
**Decision**: Cleanroom contracts name the pre-barrier compiler and package tool as pin-verified inputs, and dependency/package inputs as integrity-checked where the gate actually checks them. The Phase-1 fixed size-and-SHA-256 pins establish byte identity relative to the recorded pins, not publisher authentication. Later phases may bind the same exact bytes and acquired executable identities without calling them publisher-authenticated. Vendor-input identity and transformation claims are limited to the evidence actually checked; an immutable identity alone is not upstream authentication. These input names do not weaken the separate requirement that an effectful gate obtain an external observation and an independent oracle.
**Rejected alternatives**: Continuing to call a pinned toolchain "authenticated" would silently add a publisher-identity claim that the keyless Phase-1 gate cannot establish. Removing input-integrity checks would discard the observable boundary the gate does enforce.
**Affected documents**: `documents/engineering/validation_frame_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md`, `DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md`
**Replaces**: N/A
**Replaced by**: DL-0025

### DL-0022 — Phase 2 accepted: its owed-by paragraphs become observed implementations

**Date**: 2026-09-30
**Decision**: With Phase 2 recorded Done under a reproducible receipt, each paragraph that said the pin of `pb/__main__.py` by its SHA-256, the admitted non-Haskell set, or the compiler-backed source closure was owed by Phase 2 is re-mooded into an observed implementation citing `[GateSpec:repository_layout_conformance]`, as [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) requires once the owing phase is Done. The citation resolves only while that phase's status line is Done. The re-mooded paragraphs keep their limits: a static admission does not establish that an effect or exec occurred, and the runtime handoff stays Phase 50's claim.
**Rejected alternatives**: Leaving the "owed by" wording in place. The rule makes it a finding once the phase is Done, and a paragraph that keeps promising delivered machinery reads as a claim still pending. Rendering the paragraphs as historical results. They describe current machinery under a current receipt, not an invalidated result.
**Affected documents**: `documents/engineering/substrate_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0023 — Phase 3 accepted: its owed-by paragraphs become observed implementations

**Date**: 2026-10-01
**Decision**: With Phase 3 recorded Done under a reproducible receipt, each paragraph that said the typed cluster consumers, the capability binding seam and post-bind planner, or the first corpus module was owed by Phase 3 is re-mooded into an observed implementation citing `[GateSpec:typed_spine]`, as [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) requires once the owing phase is Done. The citation resolves only while that phase's status line is Done. Each re-mooded paragraph states only what the Phase-3 gate observes: the typed host records, the object-store capability bound under both shapes, and the first corpus module. The other capability arms, the remaining planner arms, and runtime accounting stay component diagnostics that no phase gate records, and the paragraphs say so instead of naming a later owner that does not carry them.
**Rejected alternatives**: Leaving the "owed by" wording in place. The rule makes it a finding once the phase is Done, and a paragraph that keeps promising delivered machinery reads as a claim still pending. Keeping the nine-arm contract worded as Phase 3's, which the Phase-3 gate does not observe. Rendering the paragraphs as historical results. They describe current machinery under a current receipt, not an invalidated result.
**Affected documents**: `documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/service_capability_doctrine.md`, `documents/engineering/testing_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0024 — Phase 4 documentation follows its accepted witness scope

**Date**: 2026-10-15
**Decision**: Re-mood the remaining Phase-4 owed-by paragraphs into observed implementations citing `[GateSpec:witness_manifests_capacity_storage]`, bounded to the accepted gate's vector, placement, envelope, volume-identity, claim, and rendering observations. The engine/environment matrix, elastic growth, complete physical storage geometry, runtime accounting, accelerator specialization, and provider readback are not added to that claim by their presence in linked code or component diagnostics. The same capacity introduction describes Phase 3 only within its accepted spine scope. Substrate and rke2 observations remain Phase 5's work, and live enforcement remains unverified. No gate specification, phase status, or receipt changes through this prose correction.
**Rejected alternatives**: Leaving delivery promises attached to a Done phase makes the documentation checker refuse the tree. Calling every linked fold validated would extend the accepted gate beyond its independent oracle and corpus. Removing the distinction between component diagnostics and accepted gate evidence would hide the remaining observation boundary.
**Affected documents**: `documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/resource_capacity_folds.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0025 — Native version checks replace toolchain pins before the DSL barrier

**Date**: 2026-10-15
**Decision**: At the user's direction, remove toolchain byte-pin, archive/signature, publisher-manifest, fixed operating-system, fixed CPU-architecture, and prepared bootstrap-input requirements completely. Toolchain admission checks the versions of GHCup and GHC against the Haskell compatibility requirements; Cabal is an available build tool, with its version recorded rather than digest-pinned. Native installed tool paths are explicit read-only inputs and need not live under `.build/**`. Source, dependency-source integrity, accepted-record, and observation hashes remain separate custody mechanisms and cannot become toolchain admission pins. `GenesisTrust` now means the declared assumption that the version-compatible tools execute correctly, without an opaque seven-file token or compiler/platform proof. Before `DSL_BARRIER`, all platform, lane, architecture, GPU, capacity, and provider observations are supplied Haskell values or fake boundaries: no hardware discovery, real device, container/VM engine, image execution, cluster, privileged account, or specific host is a gate prerequisite. Live portability and physical-hardware enforcement begin only at their later hardware owners. Generic preflight does not probe hardware for a hardware-free gate or before the barrier. The fake-process oracle permits only its transcript key and the explicitly named runtime-added `__CF_USER_TEXT_ENCODING` marker; it rejects every other extra key and retains raw observations. This removes a Darwin runtime prerequisite without authorising application environment configuration. The bounded `pb` bootstrap checks downloaded GHCup and selected GHC versions instead of fixed executable digests; its exact source-boundary digest remains a source-admission check. Existing receipts are immutable historical observations of their prior contracts; new contracts require fresh qualification and verifier-owned replay or reset, never hand-edited status.
**Rejected alternatives**: Requiring Linux x86_64 archives for a hardware-free language gate confuses a compiler execution platform with DSL semantics. Adding a macOS archive pin would preserve the unnecessary byte-pin requirement. Accepting arbitrary versions, ignoring all environment keys, dropping source/receipt hashes, fabricating a passing receipt, or starting a VM before the DSL barrier would exceed or contradict the requested change.
**Affected documents**: `AGENTS.md`, `documents/documentation_standards.md`, `documents/engineering/image_build_doctrine.md`, `documents/engineering/substrate_doctrine.md`, `documents/engineering/validation_frame_doctrine.md`
**Replaces**: DL-0021
**Replaced by**: N/A

### DL-0026 — Plan gates use native version admission without hardware prerequisites

**Date**: 2026-10-15
**Decision**: Apply DL-0025's GHCup/GHC version-only admission to the three plan rulebooks and the bootstrap legacy explanation. Before the DSL barrier, platform and capacity observations are supplied values or fake boundaries. No prepared archive set, signature, fixed compiler bytes, OS/CPU tuple, physical GPU or device, VM/container, privileged account, or particular host may be required. Retain numeric phase order, independent oracles, changed-subject mutants, serial builds, exact source identity, and verifier-owned status transitions. Prior accepted records remain historical; the amended contracts need fresh qualification and replay or reset.
**Rejected alternatives**: Preserving an implicit Linux/x86_64 prerequisite in a gate table would contradict the requested portable DSL boundary. Hand-editing Done status or accepted records would erase their historical scope. Removing actual modelled substrate/architecture values would reduce the DSL rather than remove a validation-host prerequisite.
**Affected documents**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/development_plan_phase_model.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0027 — Native tool inputs and portable fake-process observations

**Date**: 2026-10-15
**Decision**: Apply DL-0025's version-admission policy to repository layout and cleanroom inputs. Native installed GHCup/GHC/Cabal paths may be explicit read-only inputs outside the checkout; generated tools and candidate outputs stay beneath `.build/**`. Later proof-tool inputs, including Java and TLA+, follow the same version-compatibility policy with actual solver execution independently observed; a fake solver cannot establish a proof. Source/dependency-source integrity, source-admitted bootstrap bytes, receipts, and observation hashes keep their distinct custody role and cannot become compiler admission pins. Hardware-free boundary claims use supplied values and fake interpreters until the DSL barrier. The fake-process contract permits only its transcript variable and the named runtime-added `__CF_USER_TEXT_ENCODING` marker, records all raw keys, and rejects every other extra key.
**Rejected alternatives**: Requiring all tools to be extracted from seven Linux archives would reintroduce the retired host restriction. Ignoring arbitrary environment keys or dropping source/receipt hashes would weaken unrelated claims. Treating a fake boundary as proof of physical host isolation would overstate the hardware-free gate.
**Affected documents**: `documents/engineering/gateway_migration_model_doctrine.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0028 — Hardware boundaries follow the DSL barrier role

**Date**: 2026-10-16
**Contradiction**: [AGENTS.md, Validation Outcome and Ordering](../AGENTS.md#validation-outcome-and-ordering) forbids live effects before `DSL_BARRIER`, while [image-build doctrine §9](engineering/image_build_doctrine.md#9-bring-up-ordering--the-registry-chicken-and-egg-dissolves) retained the obsolete phrase "DSL barrier (Phase 4)".
**Decision**: Correct the ten surviving descriptions that called Phase 4 the DSL barrier after the plan rebalance. Every live cluster, image, browser, network, storage, and release observation waits for `DSL_BARRIER` and its predecessors; the compiled phase-identity table currently places that role at Phase 9. References name and link the role instead of preserving a stale ordinal. This changes no phase status, accepted observation, modeled substrate, or live gate owner. Native GHCup/GHC version admission under DL-0025 remains sufficient before the barrier, and no hardware prerequisite is introduced.
**Rejected alternatives**: Treating the obsolete Phase-4 wording as permission for live work would bypass the complete DSL gate. Adding a hardware check to resolve the discrepancy would itself cross the boundary. Rewriting historical accepted bundles would erase the contract they observed.
**Affected documents**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/release_lifecycle_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/illegal_state/illegal_state_lifecycle.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0029 — Phase 5 documentation follows its accepted substrate and recipe scope

**Date**: 2026-10-17
**Decision**: Replace Phase 5's owed-by passages with bounded observed-implementation claims only after its complete gate is accepted. The accepted scope covers the closed substrate/profile/frame catalog, lane and taint observations, payload-bearing rke2 quorum, pure image catalog and Dockerfile rendering, native build argument vectors with architecture-mismatch refusal, and opaque base channels and supplied resolutions. Delete the closed LTD-DSL-004 reader explanation while retaining its Haskell identity and regression checks. Runtime engine realization, VM/provider transitions, registry resolution, live image builds, publication, and the complete service-binary inventory keep their later owners and remain outside this claim. Reconcile the typed-spec introduction with those bounded accepted slices while retaining the complete target spelling and later-owned fields.
**Rejected alternatives**: Leaving completed work described as future work would contradict the accepted gate. Calling pure rendering a live build or a complete cross-substrate validation would exceed its observations. Deleting the Haskell legacy identity or historical receipts would remove regression and custody evidence.
**Affected documents**: `documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/dsl_doctrine.md`, `documents/engineering/image_build_doctrine.md`, `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0030 — Extension admission binds source, scope, and dependency closure

**Date**: 2026-10-18
**Contradiction**: The [DSL source-admission contract](engineering/dsl_doctrine.md#extension-astcheck--the-extension-ast-checker) still describes an unrestricted `stepRun` although the shipped Step algebra is data. The [capability graph](engineering/capability_extension_doctrine.md#5-the-requirement-edges) lists four peers while its introduction calls the link set two-member. The [tracked-tree grammar](engineering/repository_layout_doctrine.md#2-complete-repository-structure) has no entry for a Haskell pre-build admission wire.
**Decision**: Specify one opaque, base-only, ten-field `ExtensionSpec` foundation, specialized by the product to its checked source and typed catalogs. Authored extension requests contain configuration data rather than compiled functions. A configuration-dependent lane requirement uses a supplied target architecture; it introduces no validation-host prerequisite. The initial closure contains the two workload members, infernix and jitML, and their two horizontal peers, jit-build and coordination. Each retains the PROVIDE/REQUIRE edges already stated in the graph; jitML is not the JitBuild provider. The canonical DNS-1123 identity of the project displayed as jitML is `jitml`.

Use the bounded Haskell source-admission driver under the existing source roots, with no root setup wire, additional authored package or metadata exception. Its portable generated compiler transport checks the complete contributed closure before invoking the configured native GHC, including incremental builds. Cabal Custom/Hooks cannot preserve this repository's internal-library build model, and a compile-time-only check can be skipped by an incremental cache. The transport therefore delegates to the same closed GHC-parser checker the product ships before GHC can read compiler options, load plugins or execute Template Haskell. Source discovery covers the driver, checker, contributed closure and actual build dependency. The trusted link boundary binds a checker-issued opaque seal to the actual contributed source, rather than accepting a verdict for a harmless substitute. Generated source and binaries remain beneath `.build/**`; compiler execution is serial. Neither the driver nor the checker discovers hardware, dispatches an operator command or reinstates toolchain digest pins.

Scope introduction consumes an opaque attestation from a verified principal or an actual capability binding. The scope constructor and record-update route remain private, indices carry nominal roles, and re-entry consumes an existing attested scope plus a matching persisted key. The rendered object must carry that attestation. Workflow obligation indices likewise cannot be retagged through `Coerce`; their pure Build/Deploy/Observe output must be consumed by the extension path. The phase's current validation state remains owned by [Phase 6](../DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md). These are contracts for implementation and qualification, not a recorded gate result. Runtime behavior, provider execution, child workflows and the later UI surface retain their named phase owners.

**Rejected alternatives**: A skippable text lint or a seal for a different module would not constrain the linked source. A runtime registry override would not demonstrate a different compiled catalog. Dummy registrations and import-only calculus dependencies would make the link count look complete without consuming the declared behavior. An architecture, GPU, container engine, archive pin or privileged account would contradict the hardware-free DSL boundary. Editing status or historical receipts would replace observations with assertions.
**Affected documents**: `documents/engineering/dsl_doctrine.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/extension_conformance_doctrine.md`, `documents/engineering/workflow_calculus_doctrine.md`, `documents/engineering/capability_extension_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0031 — Unqualified validation claims remain obligations

**Date**: 2026-10-20
**Contradiction**: The [active-only legacy rule](../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#s-universal-source-and-artifact-hygiene-gate) requires a qualified owner transition, but the [reader register](../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#5-dsl-divergence) omitted `LTD-DSL-004` after a now-revoked gate result. Gate-backed descriptions of the runner and corpus likewise cannot establish current qualification after their supporting receipts are void.
**Decision**: State the runner, independent-oracle protocol, source boundary, root layout and corpus as requirements owed by their existing owners. Preserve every acceptance condition, qualification boundary, numerical dependency and explicit limitation. Restore the active `LTD-DSL-004` reader explanation while retaining its Haskell identity and required reintroduction cases. The target component inventory supplies no observed implementation claim or executable legacy value. Replace the remaining stale phrase about a pinned Haskell toolchain with DL-0025's version-compatible native admission; source and receipt hashes retain their distinct custody role. A reset withdraws claims and records an event, not a gate pass. Do not alter historical bundles or derive closure from declarations or prose.
**Rejected alternatives**: Leaving a gate citation as current evidence after revocation would preserve a false completion claim. Removing a required analyzer, reintroduction case or later-owned limitation would weaken the failed contract. Hand-editing status, a receipt or its archive would replace custody with an assertion.
**Affected documents**: `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `DEVELOPMENT_PLAN/system_components.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0032 — Pure DSL claims retain their validation owners

**Date**: 2026-10-20
**Decision**: Express the typed cluster schema, capability binding and seal, witness-driven rendering, structural runtime/storage fold and capacity fit corpus as specification obligations of their existing pure DSL phases. Keep every named subject, exact refusal, independent expectation, bounded corpus and excluded engine/provider/live layer. A module footprint, component result or old receipt supplies no current complete gate claim. Qualification must again follow numerical order after the inherited legacy boundary is repaired; broader folds and live readback retain their later owners.
**Rejected alternatives**: Deleting the bounded requirements would discard delivered behavior that still needs requalification. Treating linked modules or old green rows as proof would bypass the missing legacy authority. Enlarging the pure claim to physical enforcement or provider readback would exceed its observer.
**Affected documents**: `documents/engineering/cluster_topology_doctrine.md`, `documents/engineering/service_capability_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`, `documents/engineering/resource_capacity_folds.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0033 — Image and bootstrap source claims require current qualification

**Date**: 2026-10-20
**Decision**: State pure image catalog/recipe rendering, the corresponding typed-record boundaries and static bootstrap source admission as requirements owed by their existing phases, rather than current gate-backed observations. Keep the native build-argument, lane, resource and recipe checks and the separate later service-binary inventory. A hash of authored `pb` source constrains source admission only; runtime identity, unchanged argv and exec replacement remain owned by the bootstrap handoff. GHCup/GHC version admission stays sufficient before the DSL barrier, with no fixed host, architecture, engine, device, toolchain archive or executable pin introduced. The verifier's durable reset event uses the existing closed seven-file archive shape, records a status action rather than a gate result, and supplies neither a predecessor nor an accepted kernel-count observation. This adds no archive path class. This amendment changes neither the image recipe nor its catalog and supplies no live build or publication result.
**Rejected alternatives**: A source hash cannot prove that the bootstrap ran correctly. A rendered Dockerfile cannot establish a service inventory or live image build. Requiring hardware or pinned compiler bytes to repair an unsupported citation would reverse the DSL barrier and contradict DL-0025.
**Affected documents**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/substrate_doctrine.md`, `documents/engineering/repository_layout_doctrine.md`, `documents/engineering/dsl_doctrine.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0034 — Phase 0 acceptance qualifies the finite seed boundary

**Date**: 2026-10-21
**Decision**: Reconcile Phase 0's newly accepted, source-bound gate with the documentation honesty rule. Its eighteen green rows include the complete forty-five-report inventory join, nine serial owning/scoped qualifications, the finite three-predicate protocol, the six custody controls and observed run-root cleanup. Describe those bounded runner, oracle and package-boundary observations with the current seed citation. Retain the generic product-gate stages as requirements: product mutation and binary qualification begin at Phase 1, complete source closure remains Phase 2's, and the DSL spine and barrier retain their owners. Keep the component inventory as target obligations, with only its bounded governance correspondence backed by the seed. The accepted archive stays immutable; these documentation and baseline changes require fresh predecessor compatibility or replay before the next gate. This amendment adds no hardware prerequisite, toolchain pin, proof of compiler correctness or broader product claim.
**Rejected alternatives**: Leaving an owing-Phase-0 sentence after acceptance violates the honesty rule. Calling every generic runner stage or target component observed would exceed the finite seed. Rewriting the receipt, editing status by hand or skipping predecessor reproduction would erase the accepted run's actual scope.
**Affected documents**: `documents/engineering/gate_runner_doctrine.md`, `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/system_components.md`, `DEVELOPMENT_PLAN/phase_00_documentation_suite.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0035 — Retired legacy checks inherit an exact-source predecessor pass

**Date**: 2026-10-21
**Contradiction**: Phase 0's complete accepted gate (`6d3f2de43060e8f9e0aa4fc39697a7089a47fd23f28d1816550d2108097a5975`) closed its eight owning identities, but their declarations remain Active-only. The next phase therefore correctly refuses their empty findings as an unrecorded transition. A component qualification or an archive digest alone cannot supply the missing owning gate pass.
**Decision**: Record `Retired` for `LTD-VAL-001` through `LTD-VAL-004`, `LTD-VAL-006`, and `LTD-KRN-001` through `LTD-KRN-003`, and remove their closed reader explanations. Keep every identity, owner, analyzer and reintroduction case compiled. The generic runner issues an opaque, non-readable predecessor handle only for a complete green gate. That handle binds the phase and exact captured source to its opaque legacy collection. Custody reproduces the accepted predecessor at the current verifier, governance and closure before passing this handle to the next gate. The next gate inherits only canonical Retired snapshot qualifications, checks the immediate predecessor and exact source, and retains every current finding, missing qualification and unavailable boundary as a failure. A digest without the handle, a red candidate, a component collection, a different source or a different predecessor cannot establish this join. The scoped bootstrap qualification remains separate and cannot retire the whole-snapshot bootstrap obligation. Replays execute the retained checks in numerical order; a retirement declaration grants no pass authority.
**Rejected alternatives**: Leaving accepted identities Active would prevent numerical progress. Dropping their queries, trusting a serialized success label, or treating a component qualification as a complete predecessor would discard required evidence. Moving validator behavior outside the kernel budget would evade the retained-core constraint.
**Affected documents**: `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
**Replaces**: N/A
**Replaced by**: N/A

### DL-0036 — Phase 1 acceptance retires its qualified toolchain bindings

**Date**: 2026-10-21
**Contradiction**: The [active-only register](../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#1-register-contract) still explains three Phase-1 obligations after the verifier accepted the complete [toolchain gate](../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md#phase-status) with receipt `4977db9a54e3234206f37c59a610595337fdc7b281762f55614e1d72c4322f45`. The runner doctrine likewise still describes product use of its oracle protocol as owing.
**Decision**: Record Retired for `LTD-BOOT-001`, `LTD-SRC-007` and `LTD-SRC-009` and remove their closed reader explanations. Retain every compiled identity, owner, analyzer and canonical reintroduction case. Reconcile the plan and runner doctrine with the bounded accepted observations: eighteen green categories, 116 independent clean oracle rows, 32 owning qualification rows, and 36 kills among 38 viable generated mutants with a kill in every subject. Two non-buildable mutants supply no kill. The source-bound predecessor handle and current queries remain mandatory under DL-0035; these source and governance changes require numerical replay before successor acceptance. Native GHCup/GHC version admission remains sufficient. Compiler correctness, publisher identity, complete source closure, DSL validation and live hardware retain their explicit assumptions or later owners. Phase 2's seven owning legacy qualifications remain implementation work; no declaration or documentation edit supplies their verdict.
**Rejected alternatives**: Leaving accepted obligations Active prevents the required successor transition. Deleting their executable guards, changing historical receipts, relaxing mutation qualification or hand-editing status would discard evidence. Calling the DSL or hardware validated would exceed the toolchain gate's scope.
**Affected documents**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`, `DEVELOPMENT_PLAN/phase_01_toolchain_spike.md`, `DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md`, `documents/engineering/gate_runner_doctrine.md`
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
