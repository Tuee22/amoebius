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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md, documents/documentation_standards.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

---

## Ledger Status

🔄 **Active through Phase 0.** The repository contains implementation and generated migration material. The
2026-08-11 doctrine amendment reopened phases 0–64. No row closes merely because a file is absent locally;
the owning phase must enforce the replacement from a clean committed tree and verify external evidence.

Where a row leans on the sibling prodbox/infernix/jitML system as justification, that is **evidence from a sibling system, not proof in amoebius** (the honesty rule, [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

---

## Existing-code divergence snapshot — 2026-08-11

This snapshot applies
[development_plan_standards.md §T](development_plan_standards.md#t-plan-to-implementation-reconciliation) to
the dirty worktree, including committed, modified, untracked, and generated files. Searches covered `tools/`,
`pb/`, `app/`, `src/`, `test/`, `tests/`, `probe/`, and root build/package manifests. Counts are diagnostics,
not generated status, and must be refreshed when a relevant path changes.

| Existing observation | Misalignment with intended plan | Owner and closure |
|---|---|---|
| `tools/doc_lint_verify.py` invokes the legacy ledger checker with `test/golden/phase_00_ledger.json` and `test/enumeration/phase_00_surfaces.txt` | The redesigned Phase-0 gate must generate both under `gen/` and externally attest the run | Phase 0: replace the inputs and make the current two-sided gate pass |
| `tools/ledger_lint.py` requires a repository-resident ledger filename, self-hash, and enumeration | The current doctrine forbids committed/generated ledgers, hashes, and enumerations in authored roots | Phase 0: validate the run-local schema and external binding instead |
| `tools/phase0_artifact_lint.py` still audits `test/phase0_oracle_manifest.tsv` under the old pin/exemption model; its complete ignore-pattern and bytecode-suppression slices are current, but complete provenance, write-guard, effective context, resolution, attestation, and terminology checks remain absent | The partial implementation cannot satisfy the complete Phase-0 gate contract even when its current checks pass | Phase 0: retain the ignore/bytecode policy checks and replace the remaining manifest model with the doctrine's classifier and generator registry |
| Phases 1–64 each have a primary phase-gate script plus test/auxiliary and generated-evidence footprints; Phase 0 has several component linters but no current unified implementation | Footprint is not semantic completeness, numeric-order permission, or current validation | Phase 0 first; then each phase revalidates in order |
| 154 searched files contain 169 references to `DEVELOPMENT_PLAN/evidence`; 2 files reference `DEVELOPMENT_PLAN/ledgers`; 60 reference `test/enumeration`; 61 reference a phase-ledger JSON path | Gates and tests are coupled to generated material in authored roots | Phase 0 supplies the run-local framework; phases 1–64 migrate their consumers |
| 91 searched files contain 167 occurrences of the observed developer-home prefix | Authored code and tests must resolve logical tools and workspace paths at run time | Phase 1 for resolution; each later owner removes inherited consumers |
| `cabal.project.freeze`, `package-lock.json`, and `ui-runtime/spago.lock` exist as ignored, untracked resolver output | Lock/freeze and generated package-checksum files must resolve beneath `gen/` and cannot remain eligible for version control or the Docker context | Phase 1: delete or regenerate them beneath `gen/`; Phase 0 ignore/context pattern coverage is implemented |
| Three formerly tracked Python bytecode paths are deleted in the dirty worktree; ordinary validation may recreate ignored caches beside source | Bytecode may remain locally only when untracked and excluded from every Docker context | Phase 0 bytecode slice: commit the tracked deletions; ignore and policy enforcement are implemented |
| Tracked `notes.txt` contains 74 lines but has no governed-document classification | Every tracked file must be authored source/policy, reviewed external input, or an independently authored fixture; unclassified migration notes cannot remain a fourth class | Phase 0: route unique intent into governed Markdown and delete the text file, or classify and rename it as an authored governed document |
| 64 phase evidence directories, 20 generated ledger Markdown files, 66 phase-ledger JSON files, and 65 enumeration files exist | These projections and run records belong under `gen/` or in external evidence, never authored roots | Phase 0 framework; phases 1–64 migration |
| Phase evidence contains 132 JSON, 128 TSV, 128 log, 44 text, 2 YAML, 2 patch, 2 generated Haskell, 1 compressed archive, and 1 extensionless checksum-list file | File extension does not establish provenance; authored patches are incorrectly mixed with generated evidence | Phase 0 classifies every artifact; Phase 1 relocates reviewed patch inputs and regenerates bindings |
| The dirty-worktree migration renamed the Phase-24 source module, error type, imports, tests, commands, evidence labels, plan filename, and links; invalidated generated records carrying the retired term were discarded rather than hand-edited | The canonical component name is now Bootstrap Coordinator, with `bootstrap_coordinator`/`BootstrapCoordinator` identifiers and no compatibility alias | Phase 24: retain the zero-result whole-repository scan and rerun the current gate after generated-output migration |
| 64 generated phase-ledger JSON files and 40 generated evidence records retain historical bytecode-suppression command text | These are invalidated generated records, not executable policy or authored inputs; hand-editing them would create another snapshot | Phase 0 and each owning phase: discard them during migration and emit fresh records beneath `gen/runs/**` with ordinary Python caching |
| Tests read generated phase evidence directly, and `cabal.project` consumes a patch beneath Phase-1 evidence | Authored tests/build inputs cannot depend on an evidence directory | Phase 1 and each affected phase: move authored inputs to authored roots; generate observations at run time |
| `.gitignore` and `.dockerignore` now cover the complete documented generated, evidence/ledger, enumeration, dependency-resolution, build/cache, runtime, credential, and Python-bytecode pattern set | Pattern coverage is implemented and seeded-negative checked; effective tracked-path, provenance, authored-write, and Docker-context audits are still incomplete | Phase 0: retain pattern enforcement and implement the remaining semantic/context guards from a clean tree |
| The path/component audit records missing or substituted target seams, while phases 44–47, 49–58, and 60–64 explicitly retain provider, specialized-hardware, production-runtime, cleanup, or multi-zone gaps | Existing code and the intended phase contracts are not yet aligned semantically | Follow [system_components.md](system_components.md#reconciliation-state) and close each owning phase in order |

The implementation footprint is predominantly outside a clean committed baseline. Nothing in this snapshot
can close a phase; it exists to make the migration path explicit and reviewable.

---

## Generated-artifact and terminology migration — 2026-08-11

The table is the mandatory implementation path for the documentation redesign. Items are ordered by their
first owning phase; work proceeds in numeric order.

| Legacy surface | Required disposition | Owner | Closure condition |
|---|---|---|---|
| Generated files beneath `DEVELOPMENT_PLAN/evidence/**` | Stop writing there; write run bundles to `gen/runs/**`; upload immutable attestations externally | Phase 0, then each owning phase | No tracked or unignored evidence path; every gate uses external retention |
| Generated Markdown beneath `DEVELOPMENT_PLAN/ledgers/**` | Retain unique human reasoning in the owning phase document; regenerate views under `gen/docs/**` | Phase 0 | No generated ledger Markdown in the plan tree |
| `test/enumeration/**` | Generate surfaces at run time under `gen/test-surfaces/**` | Phase 0 framework; phases 1–64 adoption | No checked-in enumeration; missing/extra joins fail |
| `test/golden/phase_*_ledger.json` and Phase-54 expected-run ledger | Generate per-run ledgers under `gen/runs/**` | Phase 0 framework; phases 1–64 adoption | No ledger JSON under `test/`; schema-checked external attestation exists |
| Generated `phase-results.tsv`, validation-locus ledgers, live/sprint tables, red-before-correction tables, and ambiguous expected-hash/digest/trace TSVs | Relocate generated tables to the owning run bundle; retain a test table only after independent authorship/review is recorded | Phase 0 framework; each owning phase | Every TSV has a provenance classification; no generated TSV is tracked outside `gen/**` |
| `cabal.project.freeze`, `package-lock.json`, `spago.lock`, and every `.lock`/`.freeze` file | Resolve dynamically into `gen/locks/**` | Phase 1 | Repository scan and ignore/context checks reject every lock/freeze file |
| Hard-coded library/package SHA values, package archive checksums, and fixed dependency commits | Replace with authored compatibility requirements and dynamic resolution observations | Phase 1 | Tracked-file scan finds no library/package integrity pin or generated dependency graph |
| Absolute developer-home executable paths and the resolved portion of `toolchain/pins.json` | Resolve logical tool identities into `gen/toolchain/resolved.json` | Phase 1 | Tracked-file scan finds no developer-home path; gates consume run-local resolution |
| Authored patches stored beneath generated evidence directories | Move reviewed patch inputs to an authored `patches/**` or `vendor/**` path and record upstream provenance without a fixed package SHA | Phase 1 | Every retained patch is independently authored/reviewed input; no authored file remains under `gen/**` or an evidence root |
| Generated protobuf Haskell modules and checksum lists beneath Phase-1 evidence | Regenerate from the authored `.proto` beneath `gen/proto/**` or the build tree | Phase 1 | No generated binding or checksum list is tracked |
| Python bytecode | Permit source-adjacent interpreter caches with ordinary Python behavior; never track them or include them in Docker contexts | Phase 0 | Implemented in the dirty worktree: both ignore files and the artifact-policy scan cover directory/suffix forms and reject suppression |
| Package trees, UI output, Cabal output, browser profiles, screenshots, coverage, and reports | Keep beneath ignored build/run roots | Phase 0 | `.gitignore`, `.dockerignore`, and tracked-path scans cover every class |
| Expected files produced by a reference program, including Phase-53 job output | Keep the independent reference program and authored inputs; generate expected bytes during the run | Owning phase | No reference-program output is version-controlled |
| Generated documentation markers and tables inside governed Markdown | Keep governed Markdown authored; write generated views only to `gen/docs/**` | Phase 0 | Every governed document declares `Generated sections: none` |
| Prior oracle-custody claims not established by Git history | Classify as regression fixtures until independent review or replacement | Phase 0 and owning phase | Phase contract records independent author/reviewer provenance |
| `.gitignore` gaps | Implement the complete pattern contract in repository-layout doctrine | Phase 0 | Generated-path audit passes after a clean full gate run |
| `.dockerignore` gaps | Implement the complete container-context contract in repository-layout doctrine | Phase 0 | Context audit contains no derived, evidentiary, cache, secret, or runtime path |
| The term formerly used for the Python Bootstrap Coordinator in Markdown | Replaced with `Bootstrap Coordinator`; the Phase-24 Markdown file and links are renamed | Phase 0 | Implemented in the dirty worktree; retain a case-insensitive zero-result Markdown scan |
| The same obsolete term in Python filenames, identifiers, tests, commands, and generated output | Renamed to `bootstrap_coordinator`/`BootstrapCoordinator` without a compatibility alias; invalidated generated records are discarded | Phase 24 | Terminology scan is implemented; the migrated Phase-24 gate must still pass in numeric order |

The ignore-file changes, gate rewrites, source renames, and file deletions are implementation work. This
documentation change records them but does not perform them.

---

## Pre-implementation Phase Re-baseline — 2026-08-01

This table is the audit map for the approved low-code UI-runtime insertion. The left column is deliberately
historical text, not a live link; the right column records every current destination. Rows 17–42 are mechanical
renames, while the former broad UI phases 16 and 43 are explicit one-to-many splits and the `N/A` rows are new
seams. The renumbering used old-id placeholders before emitting any new id, so overlapping ids could not
cascade (for example, old Phase 17 could not become 31 by being rewritten first to 24 and then rewritten
again). Ubuntu-24.04 was explicitly protected as a non-phase literal.

| Historical id and path | Current id and path |
|------------------------|---------------------|
| 16 — phase_16_spa_composition_representational.md | 16 — phase_16_ui_program_schema.md; 17 — phase_17_scoped_identity_kernel.md; 18 — phase_18_ui_authorization_kernel.md; 19 — phase_19_ui_effect_binding.md; 20 — phase_20_ui_plan_compiler.md; 21 — phase_21_ui_browser_interpreter.md; 22 — phase_22_ui_server_boundary.md; 23 — phase_23_ui_local_composition.md |
| 17 — historical Phase-17 bootstrap-kind document | 24 — phase_24_bootstrap_coordinator_kind.md |
| 18 — phase_18_base_image_registry.md | 25 — phase_25_base_image_registry.md |
| 19 — phase_19_object_reconciler.md | 26 — phase_26_object_reconciler.md |
| 20 — phase_20_capacity_scheduler.md | 27 — phase_27_capacity_scheduler.md |
| 21 — phase_21_retained_storage.md | 28 — phase_28_retained_storage.md |
| 22 — phase_22_vault_pki.md | 29 — phase_29_vault_pki.md |
| 23 — phase_23_platform_backbone.md | 30 — phase_30_platform_backbone.md |
| 24 — phase_24_platform_services_2.md | 31 — phase_31_platform_services_2.md |
| 25 — phase_25_keycloak_ingress.md | 32 — phase_32_keycloak_ingress.md |
| 26 — phase_26_live_dsl_singleton.md | 33 — phase_33_live_dsl_singleton.md |
| 27 — phase_27_app_tenancy.md | 34 — phase_34_app_tenancy.md |
| 28 — phase_28_pulsar_client.md | 35 — phase_35_pulsar_client.md |
| N/A — newly isolated live-enforcement seam | 36 — phase_36_user_tenant_isolation_live.md |
| 29 — phase_29_content_store_workflow.md | 37 — phase_37_content_store_workflow.md |
| N/A — newly isolated owner-projection seam | 38 — phase_38_ui_projection_runtime.md |
| 30 — phase_30_release_lifecycle.md | 39 — phase_39_release_lifecycle.md |
| N/A — newly isolated UI-release seam | 40 — phase_40_ui_program_release.md |
| 31 — phase_31_network_fabric_wireguard.md | 41 — phase_41_network_fabric_wireguard.md |
| 32 — phase_32_multicluster_spawn_georepl.md | 42 — phase_42_multicluster_spawn_georepl.md |
| 33 — phase_33_gateway_migration_drills.md | 43 — phase_43_gateway_migration_drills.md |
| 34 — phase_34_provider_deploy_checkpoint.md | 44 — phase_44_provider_deploy_checkpoint.md |
| 35 — phase_35_provider_child_bringup.md | 45 — phase_45_provider_child_bringup.md |
| 36 — phase_36_provider_ebs_credential.md | 46 — phase_46_provider_ebs_credential.md |
| 37 — phase_37_provider_dynamic_nodes.md | 47 — phase_47_provider_dynamic_nodes.md |
| 38 — phase_38_determinism_jitcache.md | 48 — phase_48_determinism_jitcache.md |
| 39 — phase_39_infernix_lift.md | 49 — phase_49_infernix_lift.md |
| N/A — newly isolated infernix-to-UI seam | 50 — phase_50_infernix_ui_lift.md |
| 40 — phase_40_jitml_lift_cuda.md | 51 — phase_51_jitml_lift_cuda.md |
| N/A — newly isolated jitML-to-UI seam | 52 — phase_52_jitml_ui_lift.md |
| 41 — phase_41_apple_metal_host_daemon.md | 53 — phase_53_apple_metal_host_daemon.md |
| 42 — phase_42_test_topology_dsl.md | 54 — phase_54_test_topology_dsl.md |
| 43 — phase_43_spa_live_deploy.md | 55 — phase_55_ui_single_tenant_live.md; 56 — phase_56_ui_multi_tenant_live.md; 57 — phase_57_ui_rollout_reconnect.md; 58 — phase_58_ui_ha_multizone.md |

Destination phases **36, 38, 40, 50, and 52** are the explicitly mapped new live isolation, projection,
UI-release, infernix-UI, and jitML-UI seams inserted between the mechanically renamed phases. The old Phase 16
and Phase 43 milestone documents were retired only after every split destination was enumerated above. The resulting plan is one
contiguous `0..58` sequence; backlog candidates begin at 59.

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
| **prodbox** as a standalone product / CLI | sibling `prodbox/` — `app/prodbox/Main.hs`, `src/Prodbox/` | prodbox is absorbed as the **root single-node control-plane behaviour** — a library + the in-cluster control-plane singleton (a Deployment `replicas=1`, single-instance from k8s/etcd, no election) under the one amoebius binary, not a separate product; see [`daemon_topology_doctrine.md` §3 — the control-plane singleton](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) and the convergence framing in [README.md](README.md) | [Phase 24](phase_24_bootstrap_coordinator_kind.md) – [Phase 33](phase_33_live_dsl_singleton.md) | 📋 Planned |
| **The shell `bootstrap.sh` igniter** | sibling hostbootstrap `bootstrap.sh` (the substrate shell script) | Retired for the **Python `pb` bootstrap coordinator CLI** — one Python CLI, two modes (bootstrap coordinator bring-up + admin-REST client); amoebius owns no bootstrap shell script; see [`substrate_doctrine.md` §6 — the bootstrap coordinator contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrap-coordinator-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off) | [Phase 24](phase_24_bootstrap_coordinator_kind.md) | ✅ Replacement built; complete pristine-Incus Phase-24 gate passed |
| **infernix** as a standalone product / image | sibling `infernix/` — `Infernix.Runtime.*` | infernix becomes an **ML extension library** linked into the amoebius binary (and a shared library at the app surface), never a separate product; see [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library, the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule) | [Phase 49](phase_49_infernix_lift.md) | 🟡 Scoped gate passed 2026-08-11: one untouched sibling compacted-topic module and the new facade are linked; full sibling inference-engine linkage remains UNVERIFIED |
| **infernix handwritten SPA** as an authority-bearing frontend | sibling infernix PureScript demo client | Replaced by the bounded Dhall module and linked Haskell adapter interpreted through the generic UI runtime; the sibling screen remains UX evidence, never a second executable frontend or authority source. | [Phase 50](phase_50_infernix_ui_lift.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. The test uses loopback UI origins and a reference worker, so full edge/Kubernetes replica/production cutover remains UNVERIFIED. Every hardware substrate can run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows. |
| **jitML** as a standalone product | sibling `jitML/` — `JitML.*` | jitML becomes a linked **ML extension library** behind one scope-bound CUDA-training → pointer-committed-artifact facade; Phase 37 continues to own delegated Pulsar-Failover/CAS coordination and Phase 52 alone owns UI interaction | [Phase 51](phase_51_jitml_lift_cuda.md) | 🟡 Scoped gate passed 2026-08-11; ledger `external-run-reference`. One sibling CUDA generator is linked, but the full trainer/checkpoint graph and Kubernetes owner remain UNVERIFIED. Every hardware substrate can run `linux-cpu`; pristine Linux uses Incus on Linux/Linux-CUDA, Lima on Apple, or WSL2 on Windows. |
| **Baked / Poetry-venv ML engine payloads** | sibling infernix per-engine Poetry venvs + curl-tar-at-image-build (`docker/Dockerfile`, `model_cache.py`) | Retired for the shared **jit-build resolver + `CacheBudget`-bounded content-addressed cache**: each engine is a named catalog identity resolved on first miss, never baked or URL-fetched; see [`content_addressing_doctrine.md` §4.5 — the ML-asset lifecycle](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) and [`image_build_doctrine.md` §7](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 48](phase_48_determinism_jitcache.md) | 🟡 Scoped replacement validated with a pinned engine fixture; production engine payloads remain UNVERIFIED |
| **All third-party Helm charts + the Helm binary** | sibling prodbox chart platform (`Prodbox.Lib.ChartPlatform`, vendored charts); `helm` baked in the hostbootstrap base image | No-Helm: platform and app manifests are **pure typed Haskell rendered and applied by the typed reconciler** (server-side apply, ApplySet prune, wait), so neither charts nor the `helm` dependency survive; see [`manifest_generation_doctrine.md` §1 — why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) | [Phase 30](phase_30_platform_backbone.md) (platform) → [Phase 33](phase_33_live_dsl_singleton.md) (app DSL) | 📋 Planned |
| The **five upstream operator charts** — Harbor, MetalLB, Envoy Gateway, cert-manager, Percona — *as charts* | vendored Helm charts in sibling prodbox | Operators are **generated as typed CRs**, and their binaries **baked into the base container**, not installed via operator charts: no-third-party-charts ≠ no-third-party-software; see [`manifest_generation_doctrine.md` §4 — no third-party charts ≠ no third-party software: operators are generated](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated) and [`image_build_doctrine.md` §7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain) | [Phase 30](phase_30_platform_backbone.md) | 📋 Planned |
| **The per-app container image** | the `app/workload image` class every app shipped as its second artifact | Retired: an app is bounded `UiSource` plus immutable client/server plans interpreted by the generic runtime — no per-app browser or server image, hand-written Dockerfile, or registry publication. Only a reviewed trusted Haskell adapter changes a `Runtime.linkedAdapters` variant; an ordinary UI change mints a `ProgramDigest`/`Release` and reuses the image digest. See [`app_vs_deployment_doctrine.md` §2 — the application-logic surface](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is) and [`image_build_doctrine.md` §5 — the closed `ImageIdentity`](../documents/engineering/image_build_doctrine.md#5-versioning-vs-latest--development_plan-decision-recommended-default-immutable-never-latest) | [Phases 16–23](phase_16_ui_program_schema.md) (language/runtime) → [Phase 40](phase_40_ui_program_release.md) (immutable program release) | 📋 Planned |
| **The hand-authored `docker/base/Dockerfile`** | the committed `ARG`/`RUN … install` template driving the base-image bake | Retired for a **generated** Dockerfile emitted from the typed `BakeCatalog`, on the same ground [`manifest_generation_doctrine.md` §1](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) retires Helm charts: interpolated text that nothing inspects until it runs. See [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) | [Phase 25](phase_25_base_image_registry.md) | 📋 Planned |
| **Harbor** itself (the registry) | sibling prodbox in-cluster Harbor + mirror-into-registry pipeline | Replaced by the single-binary **`distribution` (`registry:2`)** registry — itself a baked binary, no relational DB, no public-registry pulls; see [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster) and [`platform_services_doctrine.md` §3 — the registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source) | [Phase 25](phase_25_base_image_registry.md) | 📋 Planned |
| **jitML Node.js-subprocess WebSocket** Pulsar transport | sibling jitML — the Node subprocess owning the WebSocket client (`JitML.*`) | Retired for the **native `amoebius-pulsar`** TCP binary-protocol client: one client, one wire, **no WebSockets**, no Node runtime; see [`pulsar_client_doctrine.md` §1 — one client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets) and [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 35](phase_35_pulsar_client.md) (native client) → [Phase 51](phase_51_jitml_lift_cuda.md) (jitML cutover) | 📋 Planned: Phase 51's scoped host-CUDA slice does not exercise native CBOR/Pulsar, so transport cutover remains UNVERIFIED. The portable `linux-cpu` lane and Incus/Lima/WSL2 clean-host routing remain available. |
| **infernix in-process WebSocket gateway** Pulsar transport | sibling `Infernix.Runtime.Pulsar` (WebSocket gateway, one-producer-per-publish, base64-in-JSON) | Same native-client replacement; infernix stops shipping its own transport and consumes `amoebius-pulsar`; see [`pulsar_client_doctrine.md` §8 — what this client replaces](../documents/engineering/pulsar_client_doctrine.md#8-what-this-client-replaces) | [Phase 35](phase_35_pulsar_client.md) (native client) → [Phase 49](phase_49_infernix_lift.md) (infernix cutover) | 🟡 Scoped gate passed 2026-08-11: native-CBOR driver and dedup path observed; full command-to-worker cutover remains UNVERIFIED |
| **infernix single-arch (amd64-only)** image publication | sibling infernix image-build pipeline | Replaced by **multi-arch (`amd64` + `arm64`) baked binaries** under one manifest list; see [`image_build_doctrine.md` §3 — buildx multi-arch, amd64 and arm64, one manifest list](../documents/engineering/image_build_doctrine.md#3-buildx-multi-arch--amd64-and-arm64-one-manifest-list) | [Phase 25](phase_25_base_image_registry.md) | 📋 Planned |
| **Per-substrate chart / image re-pins** | sibling prodbox substrate-aware version/image-ref pinning | Forbidden by **substrate equivalence**: one release/image-ref value across every substrate, with a build-time check that no code path re-pins conditionally on the active substrate; see [`platform_services_doctrine.md` §12 — substrate equivalence as a structural invariant](../documents/engineering/platform_services_doctrine.md#12-substrate-equivalence-as-a-structural-invariant). This bars per-substrate divergence of chart **versions** and **image refs** only; per-cluster **shape** divergence (single-node vs distributed) is permitted by [`service_capability_doctrine.md`](../documents/engineering/service_capability_doctrine.md) | [Phase 30](phase_30_platform_backbone.md) | 📋 Planned |

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
  [Phase 35](phase_35_pulsar_client.md), but the sibling transports are only *deleted* when
  each library is migrated onto it — infernix's WebSocket gateway at [Phase 49](phase_49_infernix_lift.md)
  and jitML's Node-subprocess client at [Phase 51](phase_51_jitml_lift_cuda.md), one subsystem at a time
  behind reversible adapter seams. The "client-lands → library-cutover" pair is captured so neither half is
  marked Done prematurely.

- **The substrate-equivalence row is a standing prohibition, not a one-time deletion.** "Per-substrate
  re-pins" is removed in the structural sense that no amoebius code path is allowed to express one; the
  enforcing build-time check is itself a [Phase 30](phase_30_platform_backbone.md) deliverable,
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
- [phase_30_platform_backbone.md](phase_30_platform_backbone.md) — owns the no-Helm platform render, the baked operators, and the substrate-equivalence check (`distribution` and multi-arch are [phase_25_base_image_registry.md](phase_25_base_image_registry.md)'s)
- [phase_35_pulsar_client.md](phase_35_pulsar_client.md) — owns the native `amoebius-pulsar` client that retires the WebSocket transports
- [`manifest_generation_doctrine.md`](../documents/engineering/manifest_generation_doctrine.md) — no-Helm rendering + generated operators
- [`image_build_doctrine.md`](../documents/engineering/image_build_doctrine.md) — baked binaries, `distribution`, multi-arch
- [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md) — the registry and substrate-equivalence invariants
- [`pulsar_client_doctrine.md`](../documents/engineering/pulsar_client_doctrine.md) — the native client and what it replaces
- [`app_vs_deployment_doctrine.md`](../documents/engineering/app_vs_deployment_doctrine.md#6-the-proof-case-a-low-code-workflow-ui-as-application-logic-only) — infernix/jitML-as-library and their interactions expressed through the bounded UI runtime
- [`daemon_topology_doctrine.md`](../documents/engineering/daemon_topology_doctrine.md) — prodbox absorbed as the control-plane singleton
