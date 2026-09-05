{-# LANGUAGE OverloadedStrings #-}

module PhaseSemanticContractOracle (
    runPhaseSemanticContractOracle,
) where

-- Component diagnostics only.  This oracle owns local fixture types and
-- independently frozen literals.  It imports no production contract type,
-- constructor, selector, category list, registry row, or renderer.

import Amoebius.Validation.PhaseSemanticContract (
    phaseSemanticContractDiagnostic,
 )
import Amoebius.Validation.PhaseSemanticJoin (
    phaseSemanticJoinDiagnostic,
 )
import Amoebius.Validation.ResourceProvisionContract (
    resourceProvisionContractDiagnostic,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    Observation (..),
    checkPassed,
 )
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

runPhaseSemanticContractOracle :: IO ()
runPhaseSemanticContractOracle =
    finishDiagnostics
        "PhaseSemanticContractOracle"
        ( concat
            [ oracleLiteralProblems
            , expectExactResult
                "the no-input semantic registry has the complete independent projection and refusal inventory"
                "phase-semantic-contract-diagnostic"
                expectedSemanticObservations
                expectedSemanticFindings
                phaseSemanticContractDiagnostic
            , expectExactResult
                "the no-input resource registry has the exact five-ready, 49-unresolved inventory"
                "resource-provision-contract-diagnostic"
                expectedResourceObservations
                expectedResourceFindings
                resourceProvisionContractDiagnostic
            , expectExactResult
                "the complete independent structural corpus changes no semantic slot"
                "phase-semantic-join-diagnostic"
                expectedJoinObservations
                expectedJoinFindings
                canonicalJoinResult
            , expectExactJoinResult
                "Claim/Subject/Oracle/provider/module/count/Legacy prose is behaviorally inert"
                expectedJoinObservations
                expectedJoinFindings
                (phaseSemanticJoinDiagnostic inertProseCorpus)
            , expectExactJoinResult
                "a dense single-line inventory of HTML comment pairs remains structurally inert"
                expectedJoinObservations
                expectedJoinFindings
                (phaseSemanticJoinDiagnostic denseCommentCorpus)
            , expectExactJoinResult
                "one omitted phase is refused at the exact phase and resource discovery loci"
                omittedPhaseObservations
                omittedPhaseFindings
                omittedPhaseResult
            , expectExactJoinResult
                "one title mutation is refused at the exact phase/title locus"
                expectedJoinObservations
                (semanticMutationFindings [titleMutationFinding])
                titleMutationResult
            , expectExactJoinResult
                "one immediate-predecessor mutation is refused at the exact Phase-52 link locus"
                expectedJoinObservations
                (semanticMutationFindings [predecessorMutationFinding])
                predecessorMutationResult
            , expectExactJoinResult
                "trailing predecessor-link text is refused instead of accepted after the first close"
                expectedJoinObservations
                (semanticMutationFindings [predecessorTrailingFinding])
                predecessorTrailingResult
            , expectExactJoinResult
                "one future-command mutation is refused at the exact Phase-50 command locus"
                expectedJoinObservations
                (semanticMutationFindings [futureCommandMutationFinding])
                futureCommandMutationResult
            , expectExactJoinResult
                "one current-status mutation is refused at the exact Phase-0 status locus"
                expectedJoinObservations
                (semanticMutationFindings [resetStatusMutationFinding])
                resetStatusMutationResult
            , expectExactJoinResult
                "a tab-indented phase status is code and cannot satisfy the current-status projection"
                expectedJoinObservations
                (semanticMutationFindings [tabIndentedStatusFinding])
                tabIndentedStatusResult
            , expectExactJoinResult
                "a phase status hidden inside raw script HTML cannot satisfy the current-status projection"
                expectedJoinObservations
                (semanticMutationFindings [tabIndentedStatusFinding])
                rawHtmlStatusResult
            , expectExactJoinResult
                "one summary-order swap is refused without interpreting either field's prose"
                expectedJoinObservations
                (semanticMutationFindings [summaryOrderMutationFinding])
                summaryOrderMutationResult
            , expectExactJoinResult
                "removing one exact UNRESOLVED marker cannot turn a gap into a draft"
                expectedJoinObservations
                (semanticMutationFindings [unresolvedMarkerMutationFinding])
                unresolvedMarkerMutationResult
            , expectExactJoinResult
                "an incidental UNRESOLVED substring cannot satisfy the exact unresolved gate prefix"
                expectedJoinObservations
                (semanticMutationFindings [unresolvedSubstringMutationFinding])
                unresolvedSubstringMutationResult
            , expectExactJoinResult
                "a four-space-indented real gate row is code and cannot satisfy either gate inventory"
                expectedJoinObservations
                (semanticMutationFindings indentedGateRowMutationFindings)
                indentedGateRowMutationResult
            , expectExactJoinResult
                "a complete two-space list-contained Phase-1 gate table cannot become the governed top-level table"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                listContainedGateTableResult
            , expectExactJoinResult
                "a complete Phase-1 gate table inside list-item raw script HTML is structurally hidden"
                expectedJoinObservations
                hiddenGateTableResultFindings
                listRawHtmlGateTableResult
            , expectExactJoinResult
                "a complete Phase-1 gate table inside a list-item fenced block is structurally hidden"
                expectedJoinObservations
                hiddenGateTableResultFindings
                listFencedGateTableResult
            , expectExactJoinResult
                "a list-looking fence inside an open top-level fence cannot reveal the Phase-1 gate table"
                expectedJoinObservations
                hiddenGateTableResultFindings
                alternatingFenceGateTableResult
            , expectExactJoinResult
                "a physical blockquote marker cannot end raw div HTML before the Phase-1 gate table"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                blockquoteAlternatingHtmlGateTableResult
            , expectExactJoinResult
                "a physical list marker cannot end raw div HTML before the Phase-1 gate table"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                listAlternatingHtmlGateTableResult
            , expectExactJoinResult
                "a comment-masked delimiter-looking suffix cannot precede and stitch the real Phase-1 gate delimiter"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                commentBeforeGateDelimiterResult
            , expectExactJoinResult
                "a four-space-indented Phase-1 gate delimiter is code and cannot frame a gate table"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                indentedGateDelimiterResult
            , expectExactJoinResult
                "a top-level fenced block between Phase-1 gate rows prevents fragment stitching"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                fenceSplitGateRowsResult
            , expectExactJoinResult
                "a same-line comment delimiter-looking suffix between Phase-1 gate rows prevents fragment stitching"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                commentSplitGateRowsResult
            , expectExactJoinResult
                "a four-space-indented delimiter-looking line between Phase-1 gate rows prevents fragment stitching"
                expectedJoinObservations
                (semanticMutationFindings hiddenGateTableFindings)
                indentedSplitGateRowsResult
            , expectExactJoinResult
                "one resource-heading state mutation is refused at the exact required phase"
                expectedJoinObservations
                resourceHeadingMutationFindings
                resourceHeadingMutationResult
            , expectExactJoinResult
                "a four-space-indented required resource blocker is code and cannot authorize mutation"
                expectedJoinObservations
                indentedResourceBlockerFindings
                indentedResourceBlockerResult
            , expectExactJoinResult
                "a tab-indented required resource blocker is code and cannot authorize mutation"
                expectedJoinObservations
                indentedResourceBlockerFindings
                tabIndentedResourceBlockerResult
            , expectExactJoinResult
                "a required resource blocker hidden inside raw script HTML cannot authorize mutation"
                expectedJoinObservations
                indentedResourceBlockerFindings
                rawHtmlResourceBlockerResult
            , expectExactJoinResult
                "a required resource blocker inside blockquote raw script HTML cannot authorize mutation"
                expectedJoinObservations
                indentedResourceBlockerFindings
                blockquoteRawHtmlResourceResult
            , expectExactJoinResult
                "a required resource blocker inside a blockquote fenced block cannot authorize mutation"
                expectedJoinObservations
                indentedResourceBlockerFindings
                blockquoteFencedResourceResult
            , expectExactJoinResult
                "a list-looking fence inside an open top-level fence cannot reveal a required resource blocker"
                expectedJoinObservations
                indentedResourceBlockerFindings
                alternatingFenceResourceResult
            , expectExactJoinResult
                "a physical blockquote marker cannot end raw div HTML before a required resource blocker"
                expectedJoinObservations
                indentedResourceBlockerFindings
                blockquoteAlternatingHtmlResourceResult
            , expectExactJoinResult
                "a physical list marker cannot end raw div HTML before a required resource blocker"
                expectedJoinObservations
                indentedResourceBlockerFindings
                listAlternatingHtmlResourceResult
            , expectExactJoinResult
                "one structurally valid tracker-target mutation is refused at the exact Phase-84 join"
                expectedJoinObservations
                (semanticMutationFindings [trackerTargetMutationFinding])
                trackerTargetMutationResult
            , expectExactJoinResult
                "a four-space-indented canonical tracker row is code and remains a malformed raw candidate"
                expectedJoinObservations
                indentedTrackerRowFindings
                indentedTrackerRowResult
            , expectExactJoinResult
                "a complete two-space list-contained tracker cannot become the governed top-level tracker table"
                expectedJoinObservations
                noTrackerFindings
                listContainedTrackerResult
            , expectExactJoinResult
                "altering the exact tracker Name header cell hides no wildcard-admitted table"
                expectedJoinObservations
                noTrackerFindings
                alteredTrackerNameHeaderResult
            , expectExactJoinResult
                "altering the exact tracker Validation contract header cell hides no wildcard-admitted table"
                expectedJoinObservations
                noTrackerFindings
                alteredTrackerContractHeaderResult
            , expectExactJoinResult
                "an exact tracker header without its immediate delimiter is refused at the header locus"
                expectedJoinObservations
                missingTrackerDelimiterFindings
                missingTrackerDelimiterResult
            , expectExactJoinResult
                "multiple-colon tracker delimiter cells do not equal the canonical delimiter"
                expectedJoinObservations
                missingTrackerDelimiterFindings
                multiColonTrackerDelimiterResult
            , expectExactJoinResult
                "a complete canonical tracker hidden inside raw script HTML cannot be parsed"
                expectedJoinObservations
                noTrackerFindings
                rawHtmlTrackerResult
            , expectExactJoinResult
                "a complete two-space-prefixed tracker inside list-item raw script HTML cannot be parsed"
                expectedJoinObservations
                noTrackerFindings
                listRawHtmlTrackerResult
            , expectExactJoinResult
                "a complete two-space-prefixed tracker inside a list-item fenced block cannot be parsed"
                expectedJoinObservations
                noTrackerFindings
                listFencedTrackerResult
            , expectExactJoinResult
                "a list-looking fence inside an open top-level fence cannot reveal exact tracker rows"
                expectedJoinObservations
                noTrackerFindings
                alternatingFenceTrackerResult
            , expectExactJoinResult
                "a physical blockquote marker cannot end raw div HTML before exact tracker rows"
                expectedJoinObservations
                noTrackerFindings
                blockquoteAlternatingHtmlTrackerResult
            , expectExactJoinResult
                "a physical list marker cannot end raw div HTML before exact tracker rows"
                expectedJoinObservations
                noTrackerFindings
                listAlternatingHtmlTrackerResult
            , expectExactJoinResult
                "an ASCII space-only physical line ends top-level raw div HTML before exact tracker rows"
                expectedJoinObservations
                expectedJoinFindings
                spaceBlankTerminatedHtmlTrackerResult
            , expectExactJoinResult
                "an ASCII tab-only physical line ends top-level raw div HTML before exact tracker rows"
                expectedJoinObservations
                expectedJoinFindings
                tabBlankTerminatedHtmlTrackerResult
            , expectExactJoinResult
                "a non-ASCII-whitespace tracker body line is a malformed candidate rather than a blank terminator"
                expectedJoinObservations
                nonAsciiWhitespaceTrackerFindings
                nonAsciiWhitespaceTrackerResult
            , expectExactJoinResult
                "a top-level fenced block splits the canonical tracker after row 47 without stitching rows 48 through 95"
                expectedJoinObservations
                splitTrackerFenceFindings
                splitTrackerFenceResult
            , expectExactJoinResult
                "one malformed phase-like path is reported instead of silently discarded"
                extraPathObservations
                malformedPathFindings
                malformedPathResult
            , expectExactJoinResult
                "one unknown canonical-ordinal slug is reported instead of silently discarded"
                extraPathObservations
                unknownPathFindings
                unknownPathResult
            , expectExactJoinResult
                "one duplicated canonical phase path is refused by every affected cardinality seam"
                duplicatePathObservations
                duplicatePathFindings
                duplicatePathResult
            , expectExactJoinResult
                "one malformed raw tracker row remains visible at its physical line"
                expectedJoinObservations
                malformedTrackerFindings
                malformedTrackerResult
            , expectExactJoinResult
                "one out-of-range raw tracker row remains visible at its physical line"
                expectedJoinObservations
                outOfRangeTrackerFindings
                outOfRangeTrackerResult
            , expectExactJoinResult
                "one extra raw tracker row is counted before its duplicate ordinal is joined"
                expectedJoinObservations
                extraTrackerFindings
                extraTrackerResult
            , expectExactJoinResult
                "a pseudo fence closer cannot reveal the canonical tracker table"
                expectedJoinObservations
                noTrackerFindings
                pseudoFenceCloserResult
            , expectExactJoinResult
                "a four-space-indented fence decoy cannot hide the canonical tracker table"
                expectedJoinObservations
                expectedJoinFindings
                indentedFenceDecoyResult
            , expectExactJoinResult
                "an HTML-comment fence decoy cannot hide the canonical tracker table"
                expectedJoinObservations
                expectedJoinFindings
                htmlFenceDecoyResult
            , expectExactJoinResult
                "an HTML comment cannot splice the canonical tracker header token"
                expectedJoinObservations
                noTrackerFindings
                htmlHeaderSpliceResult
            , concatMap exactBoundaryProblems inputBoundaryCases
            ]
        )

data OraclePhase = OraclePhase
    { oracleOrdinal :: Int
    , oracleCapability :: Text
    , oracleTitle :: Text
    , oracleSubstrate :: Text
    , oracleLane :: Text
    , oracleRegister :: Text
    }
    deriving (Eq, Show)

data OraclePhaseVector = OraclePhaseVector
    { vectorOrdinal :: Int
    , vectorStage :: Text
    , vectorSlotBitmap :: Text
    , vectorResourceProjection :: Text
    , vectorCriticalGuard :: Text
    }
    deriving (Eq, Show)

data ExpectedFinding = ExpectedFinding
    { expectedCode :: Text
    , expectedSubject :: FilePath
    , expectedDetail :: Text
    }
    deriving (Eq, Show)

phase :: Int -> Text -> Text -> Text -> Text -> Text -> OraclePhase
phase = OraclePhase

oraclePhases :: [OraclePhase]
oraclePhases =
    [ phase 0 "documentation_suite" "Documentation, source policy, and validation baseline" "none" "none" "—"
    , phase 1 "toolchain_spike" "Haskell toolchain and probe-source closure" "none" "none" "1"
    , phase 2 "repository_layout_conformance" "Repository layout conformance and de-phased naming" "none" "none" "1"
    , phase 3 "artifact_calculus" "The artifact calculus" "none" "none" "1"
    , phase 4 "budget_calculus" "The budget calculus" "none" "none" "1"
    , phase 5 "lift_calculus" "The lift calculus" "none" "none" "1"
    , phase 6 "workflow_calculus" "The workflow calculus" "none" "none" "1"
    , phase 7 "evidence_calculus" "The evidence calculus" "none" "none" "1"
    , phase 8 "scope_index" "Scoped identity kernel" "none" "none" "1"
    , phase 9 "resource_index" "Capacity core fold + topology relation" "none" "none" "1"
    , phase 10 "calculus_composition" "Composition across the five calculi" "none" "none" "1"
    , phase 11 "formal_model_kernel" "Formal-model EDSL (`Model`/`interpret`/`emitTLA`)" "none" "none" "1"
    , phase 12 "explicit_state_checker" "The amoebius explicit-state checker" "none" "none" "1"
    , phase 13 "symbolic_checker" "The amoebius symbolic checker" "none" "none" "1"
    , phase 14 "refinement_checker" "The amoebius refinement checker" "none" "none" "1"
    , phase 15 "compile_fail_harness" "The compile-fail fixture harness" "none" "none" "1"
    , phase 16 "deterministic_sim_substrate" "Deterministic-simulation substrate" "none" "none" "2"
    , phase 17 "gateway_migration_model" "Gateway-migration model (both branches)" "none" "none" "1"
    , phase 18 "dsl_formal_model" "DSL formal model" "none" "none" "1"
    , phase 19 "reconcile_core_simulation" "Reconcile decision core under deterministic simulation" "none" "none" "2"
    , phase 20 "extension_declaration" "The extension declaration" "none" "none" "1"
    , phase 21 "extension_laws_per_extension" "The per-extension laws L1-L5" "none" "none" "1"
    , phase 22 "extension_laws_compositional" "The compositional laws C1-C7" "none" "none" "1"
    , phase 23 "extension_security_laws" "The security laws S1-S6" "none" "none" "1"
    , phase 24 "conformance_gate_generator" "The generated conformance gate" "none" "none" "1"
    , phase 25 "dhall_schema_generation" "Haskell-derived Dhall projection and smart-constructor prelude" "none" "none" "1"
    , phase 26 "gadt_decode_ir" "Haskell protocol declarations, GADT-indexed IR, and total decoder" "none" "none" "1"
    , phase 27 "illegal_state_covering" "Illegal-state corpus + validation-locus ledger" "none" "none" "1"
    , phase 28 "storage_geometry_folds" "Logical→physical storage geometry folds" "none" "none" "1"
    , phase 29 "execution_accelerator_folds" "Execution-epoch + scheduler + accelerator + provider-root folds" "none" "none" "1"
    , phase 30 "capability_bind" "Capability union + representational bind" "none" "none" "1"
    , phase 31 "provision_seal" "Whole-deployment provision seal + expansion" "none" "none" "1"
    , phase 32 "inference_accelerator_provision" "InferenceEngine capability + accelerator provision" "none" "none" "1"
    , phase 33 "render_manifest_oracles" "Pure `renderAll` + rendered-artifact oracles" "none" "none" "1"
    , phase 34 "chain_kernel_boundary" "chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker" "none" "none" "2"
    , phase 35 "image_recipe_generation" "The amoebius image recipe" "none" "none" "1"
    , phase 36 "transaction_vocabulary" "The closed transaction vocabulary" "none" "none" "1"
    , phase 37 "ui_program_schema" "Bounded UI-program schema" "none" "none" "1"
    , phase 38 "ui_authorization_kernel" "UI authorization kernel" "none" "none" "1"
    , phase 39 "ui_effect_binding" "UI effect binding" "none" "none" "1"
    , phase 40 "ui_plan_compiler" "UI plan compiler" "none" "none" "1"
    , phase 41 "offline_language_plan" "Offline language and paired plans" "none" "none" "1"
    , phase 42 "ui_browser_interpreter" "Haskell browser-interpreter semantics and projection" "none" "none" "1"
    , phase 43 "ui_server_boundary" "Haskell UI-server boundary" "none" "none" "2"
    , phase 44 "ui_local_composition" "Hardware-free Haskell UI composition" "none" "none" "2"
    , phase 45 "encrypted_browser_runtime" "Haskell offline-state semantics and runtime projection" "none" "none" "1"
    , phase 46 "ui_contract_generation" "Haskell-generated browser contracts and bundle" "none" "none" "1"
    , phase 47 "tool_and_mutant_generation" "Foreign-source generator closure, checking tools, and mutants" "none" "none" "1"
    , phase 48 "test_workflow_algebra" "The test-workflow algebra" "none" "none" "1"
    , phase 49 "self_referential_gates" "No-hardware DSL gate barrier + self-referential gate suite" "none" "none" "2"
    , phase 50 "host_assert_cli" "Validate the bounded `pb` → Haskell handoff" "none" "none" "2"
    , phase 51 "host_ensure_kernel" "The host-ensure kernel" "none" "none" "2"
    , phase 52 "linux_engine_bringup" "Linux: sudoless Docker and the native image" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 53 "apple_engine_bringup" "Apple: Homebrew, Colima, and the native image" "apple" "linux-cpu/arm64" "3"
    , phase 54 "windows_engine_bringup" "Windows: WSL2 and the lifted Linux engine" "windows" "linux-cpu/amd64" "3"
    , phase 55 "bootstrap_coordinator_kind" "Haskell substrate coordinator + single kind cluster" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 56 "base_image_registry" "The base image, the jit-build resolver, and the in-cluster registry" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 57 "complementary_arch_child" "The complementary-architecture base image" "apple" "linux-cpu/arm64" "3"
    , phase 58 "object_reconciler" "Typed renderer + object reconciler" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 59 "capacity_scheduler" "amoebius-capacity scheduler + bootstrap cutover" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 60 "retained_storage" "No-provisioner retained storage + lossless rebind" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 61 "vault_pki" "Root Vault + PKI + built-in Haskell Vault client" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 62 "platform_backbone" "Platform backbone (MetalLB + MinIO + Pulsar HA)" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 63 "platform_services_2" "Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG)" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 64 "keycloak_ingress" "Keycloak-owned ingress" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 65 "live_dsl_deploy" "Live DSL deploy via the replicas=1 control-plane daemon" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 66 "app_tenancy" "Tenant/provider provisioning" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 67 "pulsar_client" "Native Pulsar client (CBOR)" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 68 "user_tenant_isolation_live" "Live subject/tenant isolation" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 69 "content_store_workflow" "Content store + workflow runtime (Pulsar-Failover single-writer)" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 70 "ui_projection_runtime" "Owner-scoped UI projection runtime" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 71 "release_lifecycle" "Release lifecycle" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 72 "ui_program_release" "Atomic immutable UI-program release" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 73 "network_fabric_wireguard" "WireGuard network fabric" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 74 "multicluster_spawn_georepl" "Multi-cluster spawn + geo-replication" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 75 "gateway_migration_drills" "Gateway-migration drills + model-correspondence" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 76 "provider_deploy_checkpoint" "Haskell-derived provider Pulumi program and enveloped checkpoint" "linux-cpu" "provider" "3"
    , phase 77 "provider_child_bringup" "Hostless provider child + convergence + Lease handoff" "linux-cpu" "provider" "3"
    , phase 78 "provider_ebs_credential" "Per-PV EBS decoupling + create-vs-delete credential" "linux-cpu" "provider" "3"
    , phase 79 "provider_dynamic_nodes" "Dynamic node provisioning by signal + leak-free provider gate" "linux-cpu" "provider" "3"
    , phase 80 "determinism_jitcache" "Determinism kernel + jit-build CacheBudget cache" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 81 "ui_single_tenant_live" "Single-tenant low-code UI live path" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 82 "ui_multi_tenant_live" "Multi-tenant low-code UI isolation" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 83 "ui_rollout_reconnect" "UI rollout, projection catch-up, and reconnect" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 84 "ui_ha_multizone" "Initial online UI multi-zone high availability" "linux-cpu" "provider" "3"
    , phase 85 "offline_replay_receipts" "Offline replay and durable receipts" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 86 "offline_blobs_isolation" "Offline blobs and partition isolation" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 87 "offline_release_evolution" "Offline release and schema evolution" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 88 "offline_multizone_continuity" "Offline multi-zone continuity" "linux-cpu" "provider" "3"
    , phase 89 "apple_metal_host_daemon" "Apple-Metal host compute daemon" "apple" "metal" "3"
    , phase 90 "test_topology_live" "The live test topology and elevated harness" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 91 "infernix_rederivation" "The infernix inference core, re-derived" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 92 "infernix_ui_rederivation" "The infernix workflow and artifact contracts, re-derived" "linux-cpu" "linux-cpu/amd64" "3"
    , phase 93 "jitml_rederivation" "The jitML numerical core, re-derived" "linux-cuda" "cuda" "3"
    , phase 94 "jitml_ui_rederivation" "The jitML training and checkpoint contracts, re-derived" "linux-cuda" "cuda" "3"
    , phase 95 "webapp_rederivation" "The multi-tenant web application re-derived" "linux-cpu" "linux-cpu/amd64" "3"
    ]

invalidOraclePhase :: OraclePhase
invalidOraclePhase =
    phase
        (-1)
        "INVALID-ORACLE-PHASE"
        "INVALID ORACLE PHASE"
        "invalid"
        "invalid"
        "invalid"

oraclePhaseMap :: Map.Map Int OraclePhase
oraclePhaseMap = Map.fromList [(oracleOrdinal row, row) | row <- oraclePhases]

oraclePhaseFor :: Int -> OraclePhase
oraclePhaseFor ordinal = Map.findWithDefault invalidOraclePhase ordinal oraclePhaseMap

-- This is an intentionally repetitive, independent 96-row contract vector.
-- Do not replace any column with an ordinal range or stage/resource branch:
-- each row is a checkable expectation that must move explicitly.
phaseVector :: Int -> Text -> Text -> Text -> Text -> OraclePhaseVector
phaseVector = OraclePhaseVector

oraclePhaseVectors :: [OraclePhaseVector]
oraclePhaseVectors =
    [ phaseVector 0 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 1 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 2 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 3 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 4 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 5 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 6 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 7 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 8 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 9 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 10 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 11 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 12 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 13 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 14 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 15 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 16 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 17 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 18 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 19 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 20 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 21 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 22 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 23 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 24 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 25 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 26 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 27 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 28 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 29 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 30 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 31 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 32 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 33 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 34 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "required|GATE-READY" ""
    , phaseVector 35 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 36 "DirectSourceBoundHaskell" "BBBBBBBBBBBBBBBBBB" "not-required|ABSENT" ""
    , phaseVector 37 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 38 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 39 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 40 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 41 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 42 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 43 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 44 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 45 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 46 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 47 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 48 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
    , phaseVector 49 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase49:requires=all-source-migration-queries-zero,all-owners-at-or-before-49-zero"
    , phaseVector 50 "PbChildUnderDirectHaskellSupervisor" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase50:requires=no-source-migration-ownership,phase49-gate-pass-source-snapshot,direct-haskell-supervisor-with-pb-child,identity-argv-exec-handoff,public-target-not-self-supervising"
    , phaseVector 51 "GatePassBoundHaskellFakeBoundary" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase51:requires=hardware-free-execution,haskell-fake-boundaries-only"
    , phaseVector 52 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase52:requires=first-hardware-validation"
    , phaseVector 53 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 54 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 55 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 56 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase56:provider=DistributionRegistry2;image=registry:2;requires=distribution-registry2-only"
    , phaseVector 57 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 58 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 59 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 60 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 61 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 62 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 63 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 64 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 65 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 66 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 67 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 68 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 69 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 70 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 71 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 72 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 73 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 74 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 75 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 76 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 77 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 78 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 79 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 80 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 81 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 82 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 83 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 84 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 85 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 86 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 87 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 88 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 89 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 90 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 91 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 92 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 93 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 94 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    , phaseVector 95 "GatePassBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
    ]

oraclePhaseVectorMap :: Map.Map Int OraclePhaseVector
oraclePhaseVectorMap = Map.fromList [(vectorOrdinal row, row) | row <- oraclePhaseVectors]

invalidOraclePhaseVector :: OraclePhaseVector
invalidOraclePhaseVector =
    phaseVector
        (-1)
        "INVALID-ORACLE-STAGE"
        "??????????????????"
        "invalid|INVALID"
        "INVALID-ORACLE-GUARD"

oraclePhaseVectorFor :: Int -> OraclePhaseVector
oraclePhaseVectorFor ordinal =
    Map.findWithDefault invalidOraclePhaseVector ordinal oraclePhaseVectorMap

summaryFields :: [Text]
summaryFields = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

gateCategories :: [Text]
gateCategories =
    [ "Claim"
    , "Subject"
    , "Command"
    , "Oracle"
    , "Positive controls"
    , "Paired negatives"
    , "Mutants"
    , "Discovery"
    , "Challenge"
    , "Observer"
    , "Authority/bypass"
    , "Freshness"
    , "Qualification"
    , "Cleanroom"
    , "Legacy closure"
    , "Predecessor"
    , "Residue"
    , "Pass criterion"
    ]

resourceFields :: [Text]
resourceFields =
    [ "owner-marker"
    , "preflight"
    , "allowed-mutations"
    , "forbidden-mutations"
    , "external-observer"
    , "scoped-cleanup"
    , "zero-owned-residue"
    ]

resourceRequiredOrdinals :: [Int]
resourceRequiredOrdinals =
    [ vectorOrdinal row
    | row <- oraclePhaseVectors
    , "required|" `Text.isPrefixOf` vectorResourceProjection row
    ]

unresolvedResourceOrdinals :: [Int]
unresolvedResourceOrdinals =
    [ vectorOrdinal row
    | row <- oraclePhaseVectors
    , vectorResourceProjection row == "required|UNRESOLVED"
    ]

localGapCategoryNames :: Int -> [Text]
localGapCategoryNames ordinal =
    [ category
    | (category, marker) <- zip gateCategories (Text.unpack (vectorSlotBitmap (oraclePhaseVectorFor ordinal)))
    , marker == 'G'
    ]

expectedSemanticObservations :: [(Text, Text)]
expectedSemanticObservations =
    [ ("semantic.phase-count", "96")
    , ("semantic.slot-count", "1728")
    , ("semantic.gap-count", "1062")
    , ("semantic.bound-count", "666")
    , ("semantic.target-phase", "none")
    , ("semantic.deferred-gap-count", "0")
    , ("semantic.legacy-count", "26")
    ]
        <> [("semantic.phase", localPhaseProjection row) | row <- oraclePhases]
        <> [("semantic.bound-slot", slot) | slot <- expectedBoundSlots]

expectedBoundSlots :: [Text]
expectedBoundSlots =
    [ "phase-00-claim=governed-corpus-and-source-policy-closure"
    , "phase-00-subject=exact-source-bound-phase-zero-dispatcher"
    , "phase-00-command=direct-pinned-offline-haskell-invocation"
    , "phase-00-oracle=independent-phase-zero-oracle-set"
    , "phase-00-positive-controls=closed-phase-zero-positive-corpus"
    , "phase-00-paired-negatives=minimally-different-phase-zero-negatives"
    , "phase-00-mutants=finite-bootstrap-changed-production-matrix"
    , "phase-00-discovery=complete-runtime-discovery-equality"
    , "phase-00-challenge=freshness-and-independent-challenge"
    , "phase-00-observer=raw-independent-observation"
    , "phase-00-authority-bypass=authority-and-bypass-rejection"
    , "phase-00-freshness=start-end-source-and-run-freshness"
    , "phase-00-qualification=finite-bootstrap-qualification-sequence"
    , "phase-00-cleanroom=run-scoped-cleanroom-and-residue-containment"
    , "phase-00-legacy-closure=structural-legacy-inventory-with-no-phase-zero-owner"
    , "phase-00-predecessor=genesis-predecessor"
    , "phase-00-residue=no-phase-zero-residue-and-typed-forward-deferrals"
    , "phase-00-pass-criterion=qualified-gate-pass"
    , "phase-01-claim=authenticated-reproducible-toolchain-and-probe-closure"
    , "phase-01-subject=acquired-toolchain-spike-supervisor"
    , "phase-01-command=direct-offline-serial-toolchain-invocation"
    , "phase-01-oracle=independent-toolchain-probe-oracle"
    , "phase-01-positive-controls=complete-representative-probe-controls"
    , "phase-01-paired-negatives=toolchain-probe-paired-negatives"
    , "phase-01-mutants=applied-toolchain-policy-mutants"
    , "phase-01-discovery=exact-dependency-and-probe-discovery"
    , "phase-01-challenge=post-start-probe-challenge"
    , "phase-01-observer=process-exit-stdout-and-digest-observation"
    , "phase-01-authority-bypass=no-network-hardware-or-auth-bypass"
    , "phase-01-freshness=two-fresh-build-roots-and-stable-source"
    , "phase-01-qualification=qualified-toolchain-harness"
    , "phase-01-cleanroom=run-scoped-generated-products-and-cleanup"
    , "phase-01-legacy-closure=phase-one-legacy-families-closed"
    , "phase-01-predecessor=exact-phase-zero-receipt"
    , "phase-01-residue=genesis-assumption-and-later-claims-explicit"
    , "phase-01-pass-criterion=qualified-phase-one-gate-pass"
    , "phase-02-claim=compiler-backed-repository-layout-closure"
    , "phase-02-subject=acquired-repository-layout-supervisor"
    , "phase-02-command=direct-offline-serial-repository-build"
    , "phase-02-oracle=independent-repository-layout-oracle"
    , "phase-02-positive-controls=clean-repository-layout-controls"
    , "phase-02-paired-negatives=repository-layout-paired-negatives"
    , "phase-02-mutants=applied-repository-layout-mutants"
    , "phase-02-discovery=two-way-source-and-component-discovery"
    , "phase-02-challenge=post-start-repository-challenge"
    , "phase-02-observer=compiler-process-and-graph-observation"
    , "phase-02-authority-bypass=no-pb-network-hardware-or-ambient-bypass"
    , "phase-02-freshness=opening-closing-source-and-fresh-build-root"
    , "phase-02-qualification=qualified-repository-layout-harness"
    , "phase-02-cleanroom=generated-products-contained-below-build"
    , "phase-02-legacy-closure=phase-two-legacy-families-closed"
    , "phase-02-predecessor=exact-phase-one-receipt"
    , "phase-02-residue=only-typed-later-source-debt"
    , "phase-02-pass-criterion=qualified-phase-two-gate-pass"
    , "phase-03-claim=complete-artifact-calculus"
    , "phase-03-subject=acquired-artifact-calculus-supervisor"
    , "phase-03-command=direct-serial-artifact-compiler-matrix"
    , "phase-03-oracle=independent-artifact-calculus-oracle"
    , "phase-03-positive-controls=artifact-calculus-positive-controls"
    , "phase-03-paired-negatives=artifact-calculus-paired-negatives"
    , "phase-03-mutants=applied-artifact-calculus-mutants"
    , "phase-03-discovery=exact-artifact-calculus-discovery"
    , "phase-03-challenge=post-acquisition-artifact-challenge"
    , "phase-03-observer=artifact-process-observation"
    , "phase-03-authority-bypass=no-pb-network-hardware-or-compiler-parallelism"
    , "phase-03-freshness=fresh-artifact-build-roots-and-stable-source"
    , "phase-03-qualification=qualified-artifact-calculus-harness"
    , "phase-03-cleanroom=artifact-products-contained-below-build"
    , "phase-03-legacy-closure=no-phase-three-legacy-debt"
    , "phase-03-predecessor=exact-phase-two-receipt"
    , "phase-03-residue=later-artifact-consumers-explicit"
    , "phase-03-pass-criterion=qualified-phase-three-gate-pass"
    , "phase-04-claim=complete-budget-calculus"
    , "phase-04-subject=acquired-budget-calculus-supervisor"
    , "phase-04-command=direct-serial-budget-compiler-matrix"
    , "phase-04-oracle=independent-budget-calculus-oracle"
    , "phase-04-positive-controls=budget-calculus-positive-controls"
    , "phase-04-paired-negatives=budget-calculus-paired-negatives"
    , "phase-04-mutants=applied-budget-calculus-mutants"
    , "phase-04-discovery=exact-budget-calculus-discovery"
    , "phase-04-challenge=post-acquisition-budget-challenge"
    , "phase-04-observer=budget-process-observation"
    , "phase-04-authority-bypass=no-pb-network-hardware-or-budget-compiler-parallelism"
    , "phase-04-freshness=fresh-budget-build-roots-and-stable-source"
    , "phase-04-qualification=qualified-budget-calculus-harness"
    , "phase-04-cleanroom=budget-products-contained-below-build"
    , "phase-04-legacy-closure=no-phase-four-legacy-debt"
    , "phase-04-predecessor=exact-phase-three-receipt"
    , "phase-04-residue=later-budget-consumers-explicit"
    , "phase-04-pass-criterion=qualified-phase-four-gate-pass"
    , "phase-05-claim=complete-lift-calculus"
    , "phase-05-subject=acquired-lift-calculus-supervisor"
    , "phase-05-command=direct-serial-lift-compiler-matrix"
    , "phase-05-oracle=independent-lift-calculus-oracle"
    , "phase-05-positive-controls=lift-calculus-positive-controls"
    , "phase-05-paired-negatives=lift-calculus-paired-negatives"
    , "phase-05-mutants=applied-lift-calculus-mutants"
    , "phase-05-discovery=exact-lift-calculus-discovery"
    , "phase-05-challenge=post-acquisition-lift-challenge"
    , "phase-05-observer=lift-process-observation"
    , "phase-05-authority-bypass=no-pb-network-hardware-or-lift-compiler-parallelism"
    , "phase-05-freshness=fresh-lift-build-roots-and-stable-source"
    , "phase-05-qualification=qualified-lift-calculus-harness"
    , "phase-05-cleanroom=lift-products-contained-below-build"
    , "phase-05-legacy-closure=no-phase-five-legacy-debt"
    , "phase-05-predecessor=exact-phase-four-receipt"
    , "phase-05-residue=later-lift-consumers-explicit"
    , "phase-05-pass-criterion=qualified-phase-five-gate-pass"
    , "phase-06-claim=complete-workflow-calculus"
    , "phase-06-subject=acquired-workflow-calculus-supervisor"
    , "phase-06-command=direct-serial-workflow-compiler-matrix"
    , "phase-06-oracle=independent-workflow-calculus-oracle"
    , "phase-06-positive-controls=workflow-calculus-positive-controls"
    , "phase-06-paired-negatives=workflow-calculus-paired-negatives"
    , "phase-06-mutants=applied-workflow-calculus-mutants"
    , "phase-06-discovery=exact-workflow-calculus-discovery"
    , "phase-06-challenge=post-acquisition-workflow-challenge"
    , "phase-06-observer=workflow-process-observation"
    , "phase-06-authority-bypass=no-pb-network-hardware-or-workflow-compiler-parallelism"
    , "phase-06-freshness=fresh-workflow-build-roots-and-stable-source"
    , "phase-06-qualification=qualified-workflow-calculus-harness"
    , "phase-06-cleanroom=workflow-products-contained-below-build"
    , "phase-06-legacy-closure=no-phase-six-legacy-debt"
    , "phase-06-predecessor=exact-phase-five-receipt"
    , "phase-06-residue=later-workflow-consumers-explicit"
    , "phase-06-pass-criterion=qualified-phase-six-gate-pass"
    , "phase-07-claim=complete-evidence-calculus"
    , "phase-07-subject=acquired-evidence-calculus-supervisor"
    , "phase-07-command=direct-serial-evidence-compiler-matrix"
    , "phase-07-oracle=independent-evidence-calculus-oracle"
    , "phase-07-positive-controls=evidence-calculus-positive-controls"
    , "phase-07-paired-negatives=evidence-calculus-paired-negatives"
    , "phase-07-mutants=applied-evidence-calculus-mutants"
    , "phase-07-discovery=exact-evidence-calculus-discovery"
    , "phase-07-challenge=post-acquisition-evidence-challenge"
    , "phase-07-observer=evidence-process-observation"
    , "phase-07-authority-bypass=no-pb-network-hardware-or-evidence-compiler-parallelism"
    , "phase-07-freshness=fresh-evidence-build-roots-and-stable-source"
    , "phase-07-qualification=qualified-evidence-calculus-harness"
    , "phase-07-cleanroom=evidence-products-contained-below-build"
    , "phase-07-legacy-closure=no-phase-seven-legacy-debt"
    , "phase-07-predecessor=exact-phase-six-receipt"
    , "phase-07-residue=later-evidence-consumers-explicit"
    , "phase-07-pass-criterion=qualified-phase-seven-gate-pass"
    , "phase-08-claim=complete-scoped-identity-kernel"
    , "phase-08-subject=acquired-scope-index-supervisor"
    , "phase-08-command=direct-serial-scope-compiler-matrix"
    , "phase-08-oracle=independent-scope-index-oracle"
    , "phase-08-positive-controls=scope-index-positive-controls"
    , "phase-08-paired-negatives=scope-index-paired-negatives"
    , "phase-08-mutants=applied-scope-index-mutants"
    , "phase-08-discovery=exact-scope-index-discovery"
    , "phase-08-challenge=post-acquisition-scope-challenge"
    , "phase-08-observer=scope-process-observation"
    , "phase-08-authority-bypass=no-pb-network-hardware-or-scope-compiler-parallelism"
    , "phase-08-freshness=fresh-scope-build-roots-and-stable-source"
    , "phase-08-qualification=qualified-scope-index-harness"
    , "phase-08-cleanroom=scope-products-contained-below-build"
    , "phase-08-legacy-closure=no-phase-eight-legacy-debt"
    , "phase-08-predecessor=exact-phase-seven-receipt"
    , "phase-08-residue=later-scope-consumers-explicit"
    , "phase-08-pass-criterion=qualified-phase-eight-gate-pass"
    , "phase-09-claim=complete-resource-index"
    , "phase-09-subject=acquired-resource-index-supervisor"
    , "phase-09-command=direct-serial-resource-compiler-matrix"
    , "phase-09-oracle=independent-resource-index-oracle"
    , "phase-09-positive-controls=resource-index-positive-controls"
    , "phase-09-paired-negatives=resource-index-paired-negatives"
    , "phase-09-mutants=applied-resource-index-mutants"
    , "phase-09-discovery=exact-resource-index-discovery"
    , "phase-09-challenge=post-acquisition-resource-challenge"
    , "phase-09-observer=resource-process-observation"
    , "phase-09-authority-bypass=no-pb-network-hardware-or-resource-compiler-parallelism"
    , "phase-09-freshness=fresh-resource-build-roots-and-stable-source"
    , "phase-09-qualification=qualified-resource-index-harness"
    , "phase-09-cleanroom=resource-products-contained-below-build"
    , "phase-09-legacy-closure=no-phase-nine-legacy-debt"
    , "phase-09-predecessor=exact-phase-eight-receipt"
    , "phase-09-residue=later-resource-consumers-explicit"
    , "phase-09-pass-criterion=qualified-phase-nine-gate-pass"
    , "phase-10-claim=complete-calculus-composition"
    , "phase-10-subject=acquired-calculus-composition-supervisor"
    , "phase-10-command=direct-serial-composition-compiler-matrix"
    , "phase-10-oracle=independent-calculus-composition-oracle"
    , "phase-10-positive-controls=calculus-composition-positive-controls"
    , "phase-10-paired-negatives=calculus-composition-paired-negatives"
    , "phase-10-mutants=applied-calculus-composition-mutants"
    , "phase-10-discovery=exact-calculus-composition-discovery"
    , "phase-10-challenge=post-acquisition-composition-challenge"
    , "phase-10-observer=composition-process-observation"
    , "phase-10-authority-bypass=no-pb-network-hardware-or-composition-compiler-parallelism"
    , "phase-10-freshness=fresh-composition-build-roots-and-stable-source"
    , "phase-10-qualification=qualified-calculus-composition-harness"
    , "phase-10-cleanroom=composition-products-contained-below-build"
    , "phase-10-legacy-closure=no-phase-ten-legacy-debt"
    , "phase-10-predecessor=exact-phase-nine-receipt"
    , "phase-10-residue=later-composition-consumers-explicit"
    , "phase-10-pass-criterion=qualified-phase-ten-gate-pass"
    , "phase-11-claim=complete-formal-model-kernel"
    , "phase-11-subject=acquired-formal-model-kernel-supervisor"
    , "phase-11-command=direct-serial-formal-model-compiler-matrix"
    , "phase-11-oracle=independent-formal-model-semantic-oracle"
    , "phase-11-positive-controls=formal-model-positive-controls"
    , "phase-11-paired-negatives=formal-model-paired-negatives"
    , "phase-11-mutants=applied-formal-model-production-mutants"
    , "phase-11-discovery=exact-formal-model-source-discovery"
    , "phase-11-challenge=post-acquisition-formal-model-challenge"
    , "phase-11-observer=formal-model-process-observation"
    , "phase-11-authority-bypass=no-pb-network-jvm-hardware-or-formal-model-compiler-parallelism"
    , "phase-11-freshness=fresh-formal-model-build-roots-and-stable-source"
    , "phase-11-qualification=qualified-formal-model-harness"
    , "phase-11-cleanroom=formal-model-products-contained-below-build"
    , "phase-11-legacy-closure=retired-formal-model-behavioral-sources-absent"
    , "phase-11-predecessor=exact-phase-ten-receipt"
    , "phase-11-residue=later-checker-and-runtime-claims-explicit"
    , "phase-11-pass-criterion=qualified-phase-eleven-gate-pass"
    , "phase-12-claim=complete-explicit-state-checker"
    , "phase-12-subject=acquired-explicit-state-checker-supervisor"
    , "phase-12-command=direct-serial-explicit-state-compiler-matrix"
    , "phase-12-oracle=independent-explicit-state-semantic-oracle"
    , "phase-12-positive-controls=explicit-state-positive-controls"
    , "phase-12-paired-negatives=explicit-state-paired-negatives"
    , "phase-12-mutants=applied-explicit-state-production-mutants"
    , "phase-12-discovery=exact-explicit-state-source-discovery"
    , "phase-12-challenge=post-acquisition-explicit-state-challenge"
    , "phase-12-observer=explicit-state-process-observation"
    , "phase-12-authority-bypass=no-pb-network-jvm-hardware-or-explicit-state-compiler-parallelism"
    , "phase-12-freshness=fresh-explicit-state-build-roots-and-stable-source"
    , "phase-12-qualification=qualified-explicit-state-harness"
    , "phase-12-cleanroom=explicit-state-products-contained-below-build"
    , "phase-12-legacy-closure=retired-explicit-state-behavioral-sources-absent"
    , "phase-12-predecessor=exact-phase-eleven-receipt"
    , "phase-12-residue=later-checker-simulation-and-runtime-claims-explicit"
    , "phase-12-pass-criterion=qualified-phase-twelve-gate-pass"
    , "phase-13-claim=complete-symbolic-checker"
    , "phase-13-subject=acquired-symbolic-checker-supervisor"
    , "phase-13-command=direct-serial-symbolic-compiler-matrix"
    , "phase-13-oracle=independent-symbolic-semantic-oracle"
    , "phase-13-positive-controls=symbolic-positive-controls"
    , "phase-13-paired-negatives=symbolic-paired-negatives"
    , "phase-13-mutants=applied-symbolic-production-mutants"
    , "phase-13-discovery=exact-symbolic-source-discovery"
    , "phase-13-challenge=post-acquisition-symbolic-challenge"
    , "phase-13-observer=symbolic-process-observation"
    , "phase-13-authority-bypass=no-pb-network-host-hardware-or-symbolic-compiler-parallelism"
    , "phase-13-freshness=fresh-symbolic-build-roots-and-stable-source"
    , "phase-13-qualification=qualified-symbolic-harness"
    , "phase-13-cleanroom=symbolic-products-contained-below-build"
    , "phase-13-legacy-closure=retired-symbolic-behavioral-sources-absent"
    , "phase-13-predecessor=exact-phase-twelve-receipt"
    , "phase-13-residue=later-refinement-simulation-and-runtime-claims-explicit"
    , "phase-13-pass-criterion=qualified-phase-thirteen-gate-pass"
    , "phase-14-claim=complete-refinement-checker"
    , "phase-14-subject=acquired-refinement-checker-supervisor"
    , "phase-14-command=direct-serial-refinement-compiler-matrix"
    , "phase-14-oracle=independent-refinement-semantic-oracle"
    , "phase-14-positive-controls=refinement-positive-controls"
    , "phase-14-paired-negatives=refinement-paired-negatives"
    , "phase-14-mutants=applied-refinement-production-mutants"
    , "phase-14-discovery=exact-refinement-source-discovery"
    , "phase-14-challenge=post-acquisition-refinement-challenge"
    , "phase-14-observer=refinement-process-observation"
    , "phase-14-authority-bypass=no-pb-network-host-hardware-or-refinement-compiler-parallelism"
    , "phase-14-freshness=fresh-refinement-build-roots-and-stable-source"
    , "phase-14-qualification=qualified-refinement-harness"
    , "phase-14-cleanroom=refinement-products-contained-below-build"
    , "phase-14-legacy-closure=retired-refinement-behavioral-sources-absent"
    , "phase-14-predecessor=exact-phase-thirteen-receipt"
    , "phase-14-residue=later-compile-fail-simulation-and-runtime-claims-explicit"
    , "phase-14-pass-criterion=qualified-phase-fourteen-gate-pass"
    , "phase-15-claim=complete-compile-fail-harness"
    , "phase-15-subject=acquired-compile-fail-harness-supervisor"
    , "phase-15-command=direct-serial-compile-fail-compiler-matrix"
    , "phase-15-oracle=independent-compile-fail-corpus-oracle"
    , "phase-15-positive-controls=compile-fail-legal-twin-controls"
    , "phase-15-paired-negatives=compile-fail-pinned-illegal-twins"
    , "phase-15-mutants=applied-compile-fail-production-mutants"
    , "phase-15-discovery=exact-compile-fail-source-discovery"
    , "phase-15-challenge=post-acquisition-compile-fail-challenge"
    , "phase-15-observer=compile-fail-process-observation"
    , "phase-15-authority-bypass=no-pb-network-host-hardware-or-compile-fail-parallelism"
    , "phase-15-freshness=fresh-compile-fail-build-roots-and-stable-source"
    , "phase-15-qualification=qualified-compile-fail-harness"
    , "phase-15-cleanroom=compile-fail-products-contained-below-build"
    , "phase-15-legacy-closure=retired-compile-fail-behavioral-sources-absent"
    , "phase-15-predecessor=exact-phase-fourteen-receipt"
    , "phase-15-residue=later-simulation-and-runtime-claims-explicit"
    , "phase-15-pass-criterion=qualified-phase-fifteen-gate-pass"
    , "phase-16-claim=complete-deterministic-simulation-substrate"
    , "phase-16-subject=acquired-deterministic-simulation-supervisor"
    , "phase-16-command=direct-offline-serial-simulation-matrix"
    , "phase-16-oracle=independent-deterministic-simulation-oracle"
    , "phase-16-positive-controls=two-interpreter-simulation-controls"
    , "phase-16-paired-negatives=fault-knob-and-schedule-paired-negatives"
    , "phase-16-mutants=applied-deterministic-simulation-production-mutants"
    , "phase-16-discovery=exact-deterministic-simulation-source-discovery"
    , "phase-16-challenge=post-acquisition-deterministic-simulation-challenge"
    , "phase-16-observer=deterministic-simulation-process-observation"
    , "phase-16-authority-bypass=no-pb-network-host-hardware-or-simulation-parallelism"
    , "phase-16-freshness=fresh-simulation-build-root-and-stable-source"
    , "phase-16-qualification=qualified-deterministic-simulation-harness"
    , "phase-16-cleanroom=simulation-products-contained-below-build"
    , "phase-16-legacy-closure=retired-simulation-behavioral-sources-absent"
    , "phase-16-predecessor=exact-phase-fifteen-receipt"
    , "phase-16-residue=later-models-runtimes-and-hardware-explicit"
    , "phase-16-pass-criterion=qualified-phase-sixteen-gate-pass"
    , "phase-17-claim=complete-gateway-migration-model"
    , "phase-17-subject=acquired-gateway-migration-model-supervisor"
    , "phase-17-command=direct-offline-serial-gateway-model-matrix"
    , "phase-17-oracle=independent-gateway-migration-oracle"
    , "phase-17-positive-controls=gateway-explorer-tlc-and-schedule-controls"
    , "phase-17-paired-negatives=gateway-invariant-fairness-and-cutoff-negatives"
    , "phase-17-mutants=applied-gateway-migration-production-mutants"
    , "phase-17-discovery=exact-gateway-migration-source-discovery"
    , "phase-17-challenge=post-acquisition-gateway-migration-challenge"
    , "phase-17-observer=gateway-migration-process-observation"
    , "phase-17-authority-bypass=no-pb-network-host-hardware-or-gateway-parallelism"
    , "phase-17-freshness=fresh-gateway-build-root-and-stable-source"
    , "phase-17-qualification=qualified-gateway-migration-harness"
    , "phase-17-cleanroom=gateway-products-contained-below-build"
    , "phase-17-legacy-closure=retired-gateway-behavioral-sources-absent"
    , "phase-17-predecessor=exact-phase-sixteen-receipt"
    , "phase-17-residue=gateway-runtime-fidelity-and-decomposition-explicit"
    , "phase-17-pass-criterion=qualified-phase-seventeen-gate-pass"
    , "phase-18-claim=complete-dsl-formal-model"
    , "phase-18-subject=acquired-dsl-formal-model-supervisor"
    , "phase-18-command=direct-offline-serial-dsl-formal-matrix"
    , "phase-18-oracle=independent-dsl-formal-oracle"
    , "phase-18-positive-controls=dsl-model-capacity-calculus-and-protocol-controls"
    , "phase-18-paired-negatives=dsl-safety-fairness-and-decision-negatives"
    , "phase-18-mutants=applied-dsl-formal-production-mutants"
    , "phase-18-discovery=exact-dsl-formal-source-discovery"
    , "phase-18-challenge=post-acquisition-dsl-formal-challenge"
    , "phase-18-observer=dsl-formal-process-observation"
    , "phase-18-authority-bypass=no-pb-network-host-hardware-or-dsl-formal-parallelism"
    , "phase-18-freshness=fresh-dsl-formal-build-root-and-stable-source"
    , "phase-18-qualification=qualified-dsl-formal-harness"
    , "phase-18-cleanroom=dsl-formal-products-contained-below-build"
    , "phase-18-legacy-closure=retired-dsl-formal-behavioral-sources-absent"
    , "phase-18-predecessor=exact-phase-seventeen-receipt"
    , "phase-18-residue=later-dsl-runtime-and-projection-owners-explicit"
    , "phase-18-pass-criterion=qualified-phase-eighteen-gate-pass"
    , "phase-19-claim=complete-reconcile-core-simulation"
    , "phase-19-subject=acquired-reconcile-core-supervisor"
    , "phase-19-command=direct-offline-serial-reconcile-core-matrix"
    , "phase-19-oracle=independent-reconcile-core-oracle"
    , "phase-19-positive-controls=reconcile-core-schedule-protocol-and-formal-controls"
    , "phase-19-paired-negatives=reconcile-core-paired-negatives"
    , "phase-19-mutants=applied-reconcile-core-production-mutants"
    , "phase-19-discovery=exact-reconcile-core-source-discovery"
    , "phase-19-challenge=post-acquisition-reconcile-core-challenge"
    , "phase-19-observer=reconcile-core-process-observation"
    , "phase-19-authority-bypass=no-pb-network-host-hardware-or-reconcile-core-parallelism"
    , "phase-19-freshness=fresh-reconcile-core-build-root-and-stable-source"
    , "phase-19-qualification=qualified-reconcile-core-harness"
    , "phase-19-cleanroom=reconcile-core-products-contained-below-build"
    , "phase-19-legacy-closure=retired-reconcile-core-behavioral-sources-absent"
    , "phase-19-predecessor=exact-phase-eighteen-receipt"
    , "phase-19-residue=later-effectful-reconcile-runtime-explicit"
    , "phase-19-pass-criterion=qualified-phase-nineteen-gate-pass"
    , "phase-20-claim=complete-indexed-extension-declaration"
    , "phase-20-subject=acquired-extension-declaration-supervisor"
    , "phase-20-command=direct-offline-serial-extension-declaration-matrix"
    , "phase-20-oracle=independent-extension-declaration-oracle"
    , "phase-20-positive-controls=declaration-reader-resource-and-digest-controls"
    , "phase-20-paired-negatives=declaration-semantic-and-compile-negatives"
    , "phase-20-mutants=applied-extension-declaration-production-mutants"
    , "phase-20-discovery=exact-extension-declaration-source-discovery"
    , "phase-20-challenge=post-acquisition-extension-declaration-challenge"
    , "phase-20-observer=extension-declaration-process-observation"
    , "phase-20-authority-bypass=no-pb-network-host-hardware-or-extension-declaration-parallelism"
    , "phase-20-freshness=fresh-extension-declaration-build-root-and-stable-source"
    , "phase-20-qualification=qualified-extension-declaration-harness"
    , "phase-20-cleanroom=extension-declaration-products-contained-below-build"
    , "phase-20-legacy-closure=retired-extension-declaration-behavioral-sources-absent"
    , "phase-20-predecessor=exact-phase-nineteen-receipt"
    , "phase-20-residue=later-extension-law-and-runtime-owners-explicit"
    , "phase-20-pass-criterion=qualified-phase-twenty-gate-pass"
    , "phase-21-claim=complete-per-extension-law-evaluator"
    , "phase-21-subject=acquired-extension-laws-supervisor"
    , "phase-21-command=direct-offline-serial-extension-laws-matrix"
    , "phase-21-oracle=independent-extension-laws-oracle"
    , "phase-21-positive-controls=lawful-operation-render-budget-and-evidence-controls"
    , "phase-21-paired-negatives=single-law-and-claim-compile-negatives"
    , "phase-21-mutants=applied-extension-laws-production-mutants"
    , "phase-21-discovery=exact-extension-laws-source-discovery"
    , "phase-21-challenge=post-acquisition-extension-laws-challenge"
    , "phase-21-observer=extension-laws-process-observation"
    , "phase-21-authority-bypass=no-pb-network-host-hardware-or-extension-laws-parallelism"
    , "phase-21-freshness=fresh-extension-laws-build-root-and-stable-source"
    , "phase-21-qualification=qualified-extension-laws-harness"
    , "phase-21-cleanroom=extension-laws-products-contained-below-build"
    , "phase-21-legacy-closure=retired-extension-laws-behavioral-sources-absent"
    , "phase-21-predecessor=exact-phase-twenty-receipt"
    , "phase-21-residue=later-compositional-security-conformance-and-runtime-owners-explicit"
    , "phase-21-pass-criterion=qualified-phase-twenty-one-gate-pass"
    , "phase-22-claim=complete-normalized-composite-and-c1-c7-evaluator"
    , "phase-22-subject=acquired-extension-composition-supervisor"
    , "phase-22-command=direct-offline-serial-extension-composition-matrix"
    , "phase-22-oracle=independent-extension-composition-oracle"
    , "phase-22-positive-controls=lawful-composition-identity-association-budget-and-address-controls"
    , "phase-22-paired-negatives=composition-law-and-request-scope-negatives"
    , "phase-22-mutants=applied-extension-composition-production-mutants"
    , "phase-22-discovery=exact-extension-composition-source-discovery"
    , "phase-22-challenge=post-acquisition-extension-composition-challenge"
    , "phase-22-observer=extension-composition-process-observation"
    , "phase-22-authority-bypass=no-pb-network-host-hardware-or-extension-composition-parallelism"
    , "phase-22-freshness=fresh-extension-composition-build-root-and-stable-source"
    , "phase-22-qualification=qualified-extension-composition-harness"
    , "phase-22-cleanroom=extension-composition-products-contained-below-build"
    , "phase-22-legacy-closure=retired-extension-composition-behavioral-sources-absent"
    , "phase-22-predecessor=exact-phase-twenty-one-receipt"
    , "phase-22-residue=later-security-conformance-proof-and-runtime-owners-explicit"
    , "phase-22-pass-criterion=qualified-phase-twenty-two-gate-pass"
    , "phase-23-claim=bounded-typed-security-kernel-and-s1-s6-evaluator"
    , "phase-23-subject=acquired-extension-security-supervisor"
    , "phase-23-command=direct-offline-serial-extension-security-matrix"
    , "phase-23-oracle=independent-extension-security-oracle"
    , "phase-23-positive-controls=identity-operation-refusal-namespace-and-policy-controls"
    , "phase-23-paired-negatives=security-law-and-four-compiler-barrier-negatives"
    , "phase-23-mutants=applied-extension-security-production-mutants"
    , "phase-23-discovery=exact-extension-security-source-discovery"
    , "phase-23-challenge=post-acquisition-extension-security-challenge"
    , "phase-23-observer=extension-security-process-observation"
    , "phase-23-authority-bypass=no-pb-network-host-hardware-or-extension-security-parallelism"
    , "phase-23-freshness=fresh-extension-security-build-root-and-stable-source"
    , "phase-23-qualification=qualified-extension-security-harness"
    , "phase-23-cleanroom=extension-security-products-contained-below-build"
    , "phase-23-legacy-closure=retired-extension-security-behavioral-sources-absent"
    , "phase-23-predecessor=exact-phase-twenty-two-receipt"
    , "phase-23-residue=later-security-closure-conformance-crypto-timing-and-runtime-owners-explicit"
    , "phase-23-pass-criterion=qualified-phase-twenty-three-gate-pass"
    , "phase-24-claim=declaration-derived-conformance-plan-verdict-and-admission"
    , "phase-24-subject=acquired-conformance-gate-supervisor"
    , "phase-24-command=direct-offline-serial-conformance-gate-matrix"
    , "phase-24-oracle=independent-conformance-gate-oracle"
    , "phase-24-positive-controls=suite-coverage-verdict-and-admission-controls"
    , "phase-24-paired-negatives=conformance-refusal-and-compiler-barrier-negatives"
    , "phase-24-mutants=applied-conformance-gate-production-mutants"
    , "phase-24-discovery=exact-conformance-gate-source-discovery"
    , "phase-24-challenge=post-acquisition-conformance-gate-challenge"
    , "phase-24-observer=conformance-gate-process-observation"
    , "phase-24-authority-bypass=no-pb-network-host-hardware-or-conformance-gate-parallelism"
    , "phase-24-freshness=fresh-conformance-gate-build-root-and-stable-source"
    , "phase-24-qualification=qualified-conformance-gate-harness"
    , "phase-24-cleanroom=conformance-gate-products-contained-below-build"
    , "phase-24-legacy-closure=retired-conformance-gate-behavioral-sources-absent"
    , "phase-24-predecessor=exact-phase-twenty-three-receipt"
    , "phase-24-residue=later-transaction-observer-semantic-closure-and-runtime-owners-explicit"
    , "phase-24-pass-criterion=qualified-phase-twenty-four-gate-pass"
    , "phase-25-claim=haskell-derived-dhall-structural-language"
    , "phase-25-subject=acquired-dhall-schema-supervisor"
    , "phase-25-command=direct-offline-serial-dhall-schema-matrix"
    , "phase-25-oracle=independent-dhall-schema-oracle"
    , "phase-25-positive-controls=schema-module-and-positive-typecheck-controls"
    , "phase-25-paired-negatives=paired-dhall-structural-and-import-negatives"
    , "phase-25-mutants=applied-dhall-schema-production-mutants"
    , "phase-25-discovery=exact-dhall-schema-source-discovery"
    , "phase-25-challenge=post-acquisition-dhall-schema-challenge"
    , "phase-25-observer=dhall-schema-process-observation"
    , "phase-25-authority-bypass=no-pb-network-host-hardware-or-dhall-schema-parallelism"
    , "phase-25-freshness=fresh-dhall-schema-build-root-and-stable-source"
    , "phase-25-qualification=qualified-dhall-schema-harness"
    , "phase-25-cleanroom=dhall-schema-products-contained-below-build"
    , "phase-25-legacy-closure=retired-dhall-behavioral-sources-absent"
    , "phase-25-predecessor=exact-phase-twenty-four-receipt"
    , "phase-25-residue=later-binding-decode-provision-runtime-owners-explicit"
    , "phase-25-pass-criterion=qualified-phase-twenty-five-gate-pass"
    , "phase-26-claim=haskell-protocol-and-indexed-decode-boundary"
    , "phase-26-subject=acquired-gadt-decode-supervisor"
    , "phase-26-command=direct-offline-serial-gadt-decode-matrix"
    , "phase-26-oracle=independent-gadt-decode-oracle"
    , "phase-26-positive-controls=controller-indexed-positive-decode-controls"
    , "phase-26-paired-negatives=paired-gadt-decode-negatives"
    , "phase-26-mutants=applied-gadt-decode-production-mutants"
    , "phase-26-discovery=exact-gadt-decode-source-discovery"
    , "phase-26-challenge=post-acquisition-gadt-decode-challenge"
    , "phase-26-observer=gadt-decode-process-observation"
    , "phase-26-authority-bypass=no-pb-network-host-hardware-or-gadt-decode-parallelism"
    , "phase-26-freshness=fresh-gadt-decode-build-root-and-stable-source"
    , "phase-26-qualification=qualified-gadt-decode-harness"
    , "phase-26-cleanroom=gadt-decode-products-contained-below-build"
    , "phase-26-legacy-closure=retired-proto-and-gadt-decode-authorities-absent"
    , "phase-26-predecessor=exact-phase-twenty-five-receipt"
    , "phase-26-residue=later-capacity-binding-provision-runtime-owners-explicit"
    , "phase-26-pass-criterion=qualified-phase-twenty-six-gate-pass"
    , "phase-27-claim=closed-haskell-illegal-state-coverage-ledger"
    , "phase-27-subject=acquired-illegal-state-covering-supervisor"
    , "phase-27-command=direct-offline-serial-illegal-state-covering-matrix"
    , "phase-27-oracle=independent-illegal-state-covering-oracle"
    , "phase-27-positive-controls=dhall-decode-compile-and-property-positive-controls"
    , "phase-27-paired-negatives=paired-illegal-state-foreclosure-negatives"
    , "phase-27-mutants=applied-illegal-state-covering-production-mutants"
    , "phase-27-discovery=exact-illegal-state-covering-source-discovery"
    , "phase-27-challenge=post-acquisition-illegal-state-covering-challenge"
    , "phase-27-observer=illegal-state-covering-process-observation"
    , "phase-27-authority-bypass=no-pb-network-host-hardware-or-illegal-state-parallelism"
    , "phase-27-freshness=fresh-illegal-state-build-root-and-stable-source"
    , "phase-27-qualification=qualified-illegal-state-covering-harness"
    , "phase-27-cleanroom=illegal-state-products-contained-below-build"
    , "phase-27-legacy-closure=retired-behavioral-document-authorities-absent"
    , "phase-27-predecessor=exact-phase-twenty-six-receipt"
    , "phase-27-residue=later-provision-render-runtime-owners-explicit"
    , "phase-27-pass-criterion=qualified-phase-twenty-seven-gate-pass"
    , "phase-28-claim=pure-storage-geometry-fold-boundary"
    , "phase-28-subject=acquired-storage-geometry-supervisor"
    , "phase-28-command=direct-offline-serial-storage-geometry-matrix"
    , "phase-28-oracle=independent-storage-geometry-oracle"
    , "phase-28-positive-controls=storage-geometry-positive-controls"
    , "phase-28-paired-negatives=paired-storage-geometry-negatives"
    , "phase-28-mutants=applied-storage-geometry-production-mutants"
    , "phase-28-discovery=exact-storage-geometry-source-discovery"
    , "phase-28-challenge=post-acquisition-storage-geometry-challenge"
    , "phase-28-observer=storage-geometry-process-observation"
    , "phase-28-authority-bypass=no-pb-network-host-hardware-or-storage-parallelism"
    , "phase-28-freshness=fresh-storage-geometry-build-root-and-stable-source"
    , "phase-28-qualification=qualified-storage-geometry-harness"
    , "phase-28-cleanroom=storage-geometry-products-contained-below-build"
    , "phase-28-legacy-closure=retired-storage-geometry-authorities-absent"
    , "phase-28-predecessor=exact-phase-twenty-seven-receipt"
    , "phase-28-residue=later-binding-provision-runtime-storage-owners-explicit"
    , "phase-28-pass-criterion=qualified-phase-twenty-eight-gate-pass"
    , "phase-29-claim=pure-execution-accelerator-fold-boundary"
    , "phase-29-subject=acquired-execution-accelerator-supervisor"
    , "phase-29-command=direct-offline-serial-execution-accelerator-matrix"
    , "phase-29-oracle=independent-execution-accelerator-oracle"
    , "phase-29-positive-controls=execution-accelerator-positive-controls"
    , "phase-29-paired-negatives=paired-execution-accelerator-negatives"
    , "phase-29-mutants=applied-execution-accelerator-production-mutants"
    , "phase-29-discovery=exact-execution-accelerator-source-discovery"
    , "phase-29-challenge=post-acquisition-execution-accelerator-challenge"
    , "phase-29-observer=execution-accelerator-process-observation"
    , "phase-29-authority-bypass=no-pb-network-host-hardware-or-execution-parallelism"
    , "phase-29-freshness=fresh-execution-accelerator-build-root-and-stable-source"
    , "phase-29-qualification=qualified-execution-accelerator-harness"
    , "phase-29-cleanroom=execution-accelerator-products-contained-below-build"
    , "phase-29-legacy-closure=retired-execution-accelerator-authorities-absent"
    , "phase-29-predecessor=exact-phase-twenty-eight-receipt"
    , "phase-29-residue=later-binding-provision-runtime-execution-owners-explicit"
    , "phase-29-pass-criterion=qualified-phase-twenty-nine-gate-pass"
    , "phase-30-claim=pure-capability-bind-boundary"
    , "phase-30-subject=acquired-capability-bind-supervisor"
    , "phase-30-command=direct-offline-serial-capability-bind-matrix"
    , "phase-30-oracle=independent-capability-bind-oracle"
    , "phase-30-positive-controls=capability-bind-positive-controls"
    , "phase-30-paired-negatives=paired-capability-bind-negatives"
    , "phase-30-mutants=applied-capability-bind-production-mutants"
    , "phase-30-discovery=exact-capability-bind-source-discovery"
    , "phase-30-challenge=post-acquisition-capability-bind-challenge"
    , "phase-30-observer=capability-bind-process-observation"
    , "phase-30-authority-bypass=no-pb-network-host-hardware-or-capability-bind-parallelism"
    , "phase-30-freshness=fresh-capability-bind-build-root-and-stable-source"
    , "phase-30-qualification=qualified-capability-bind-harness"
    , "phase-30-cleanroom=capability-bind-products-contained-below-build"
    , "phase-30-legacy-closure=retired-capability-bind-authorities-absent"
    , "phase-30-predecessor=exact-phase-twenty-nine-receipt"
    , "phase-30-residue=later-provision-render-runtime-capability-owners-explicit"
    , "phase-30-pass-criterion=qualified-phase-thirty-gate-pass"
    , "phase-31-claim=complete-provision-seal-boundary"
    , "phase-31-subject=acquired-provision-seal-supervisor"
    , "phase-31-command=direct-offline-serial-provision-seal-matrix"
    , "phase-31-oracle=independent-provision-seal-oracle"
    , "phase-31-positive-controls=provision-seal-positive-controls"
    , "phase-31-paired-negatives=paired-provision-seal-negatives"
    , "phase-31-mutants=applied-provision-seal-production-mutants"
    , "phase-31-discovery=exact-provision-seal-source-discovery"
    , "phase-31-challenge=post-acquisition-provision-seal-challenge"
    , "phase-31-observer=provision-seal-process-observation"
    , "phase-31-authority-bypass=no-pb-network-host-hardware-or-provision-seal-parallelism"
    , "phase-31-freshness=fresh-provision-seal-build-root-and-stable-source"
    , "phase-31-qualification=qualified-provision-seal-harness"
    , "phase-31-cleanroom=provision-seal-products-contained-below-build"
    , "phase-31-legacy-closure=retired-provision-seal-authorities-absent"
    , "phase-31-predecessor=exact-phase-thirty-receipt"
    , "phase-31-residue=later-render-runtime-live-provision-owners-explicit"
    , "phase-31-pass-criterion=qualified-phase-thirty-one-gate-pass"
    , "phase-32-claim=closed-inference-accelerator-provision-boundary"
    , "phase-32-subject=acquired-inference-accelerator-supervisor"
    , "phase-32-command=direct-offline-serial-inference-accelerator-matrix"
    , "phase-32-oracle=independent-inference-accelerator-oracle"
    , "phase-32-positive-controls=inference-accelerator-positive-controls"
    , "phase-32-paired-negatives=paired-inference-accelerator-negatives"
    , "phase-32-mutants=applied-inference-accelerator-production-mutants"
    , "phase-32-discovery=exact-inference-accelerator-source-discovery"
    , "phase-32-challenge=post-acquisition-inference-accelerator-challenge"
    , "phase-32-observer=inference-accelerator-process-observation"
    , "phase-32-authority-bypass=no-pb-network-host-hardware-or-inference-accelerator-parallelism"
    , "phase-32-freshness=fresh-inference-accelerator-build-root-and-stable-source"
    , "phase-32-qualification=qualified-inference-accelerator-harness"
    , "phase-32-cleanroom=inference-accelerator-products-contained-below-build"
    , "phase-32-legacy-closure=retired-inference-accelerator-authorities-absent"
    , "phase-32-predecessor=exact-phase-thirty-one-receipt"
    , "phase-32-residue=later-render-runtime-live-engine-owners-explicit"
    , "phase-32-pass-criterion=qualified-phase-thirty-two-gate-pass"
    , "phase-33-claim=pure-total-render-all-boundary"
    , "phase-33-subject=acquired-render-manifest-supervisor"
    , "phase-33-command=direct-offline-serial-render-manifest-matrix"
    , "phase-33-oracle=independent-render-manifest-oracle"
    , "phase-33-positive-controls=render-manifest-positive-controls"
    , "phase-33-paired-negatives=paired-render-manifest-negatives"
    , "phase-33-mutants=applied-render-manifest-production-mutants"
    , "phase-33-discovery=exact-render-manifest-source-discovery"
    , "phase-33-challenge=post-acquisition-render-manifest-challenge"
    , "phase-33-observer=render-manifest-process-observation"
    , "phase-33-authority-bypass=no-pb-network-host-hardware-or-render-manifest-parallelism"
    , "phase-33-freshness=fresh-render-manifest-build-root-and-stable-source"
    , "phase-33-qualification=qualified-render-manifest-harness"
    , "phase-33-cleanroom=render-manifest-products-contained-below-build"
    , "phase-33-legacy-closure=retired-render-manifest-authorities-absent"
    , "phase-33-predecessor=exact-phase-thirty-two-receipt"
    , "phase-33-residue=later-actions-dry-run-runtime-live-owners-explicit"
    , "phase-33-pass-criterion=qualified-phase-thirty-three-gate-pass"
    , "phase-34-claim=pure-chain-and-fake-boundary"
    , "phase-34-subject=acquired-chain-boundary-supervisor"
    , "phase-34-command=direct-offline-serial-chain-boundary-matrix"
    , "phase-34-oracle=independent-chain-boundary-oracle"
    , "phase-34-positive-controls=chain-boundary-positive-controls"
    , "phase-34-paired-negatives=paired-chain-boundary-negatives"
    , "phase-34-mutants=applied-chain-boundary-production-mutants"
    , "phase-34-discovery=exact-chain-boundary-source-discovery"
    , "phase-34-challenge=post-acquisition-chain-boundary-challenge"
    , "phase-34-observer=chain-boundary-process-observation"
    , "phase-34-authority-bypass=no-pb-network-live-host-hardware-or-parallelism"
    , "phase-34-freshness=fresh-chain-boundary-build-root-and-stable-source"
    , "phase-34-qualification=qualified-chain-boundary-harness"
    , "phase-34-cleanroom=chain-boundary-products-contained-below-build"
    , "phase-34-legacy-closure=retired-chain-boundary-authorities-absent"
    , "phase-34-predecessor=exact-phase-thirty-three-receipt"
    , "phase-34-residue=live-interpreter-runtime-and-hardware-owners-explicit"
    , "phase-34-pass-criterion=qualified-phase-thirty-four-gate-pass"
    , "phase-35-claim=pure-total-image-recipe-boundary"
    , "phase-35-subject=acquired-image-recipe-supervisor"
    , "phase-35-command=direct-offline-serial-image-recipe-matrix"
    , "phase-35-oracle=independent-image-recipe-oracle"
    , "phase-35-positive-controls=image-recipe-positive-controls"
    , "phase-35-paired-negatives=paired-image-recipe-negatives"
    , "phase-35-mutants=applied-image-recipe-production-mutants"
    , "phase-35-discovery=exact-image-recipe-source-discovery"
    , "phase-35-challenge=post-acquisition-image-recipe-challenge"
    , "phase-35-observer=image-recipe-process-observation"
    , "phase-35-authority-bypass=no-pb-network-engine-host-hardware-or-parallelism"
    , "phase-35-freshness=fresh-image-recipe-build-root-and-stable-source"
    , "phase-35-qualification=qualified-image-recipe-harness"
    , "phase-35-cleanroom=image-recipe-products-contained-below-build"
    , "phase-35-legacy-closure=retired-image-recipe-authorities-absent"
    , "phase-35-predecessor=exact-phase-thirty-four-receipt"
    , "phase-35-residue=live-resolution-build-publication-runtime-owners-explicit"
    , "phase-35-pass-criterion=qualified-phase-thirty-five-gate-pass"
    , "phase-36-claim=pure-closed-transaction-vocabulary"
    , "phase-36-subject=acquired-transaction-vocabulary-supervisor"
    , "phase-36-command=direct-offline-serial-transaction-vocabulary-matrix"
    , "phase-36-oracle=independent-transaction-vocabulary-oracle"
    , "phase-36-positive-controls=transaction-vocabulary-positive-controls"
    , "phase-36-paired-negatives=transaction-vocabulary-compiler-negatives"
    , "phase-36-mutants=applied-transaction-vocabulary-production-mutants"
    , "phase-36-discovery=exact-transaction-vocabulary-source-discovery"
    , "phase-36-challenge=post-acquisition-transaction-vocabulary-challenge"
    , "phase-36-observer=transaction-vocabulary-process-observation"
    , "phase-36-authority-bypass=no-pb-network-database-host-hardware-or-parallelism"
    , "phase-36-freshness=fresh-transaction-vocabulary-build-root-and-stable-source"
    , "phase-36-qualification=qualified-transaction-vocabulary-harness"
    , "phase-36-cleanroom=transaction-vocabulary-products-contained-below-build"
    , "phase-36-legacy-closure=retired-transaction-vocabulary-authorities-absent"
    , "phase-36-predecessor=exact-phase-thirty-five-receipt"
    , "phase-36-residue=live-database-policy-runtime-owners-explicit"
    , "phase-36-pass-criterion=qualified-phase-thirty-six-gate-pass"
    ]

expectedSemanticFindings :: [ExpectedFinding]
expectedSemanticFindings =
    concatMap localSlotFindings oraclePhases
        <> [ ExpectedFinding
                "PLAN-SEMANTIC-DIAGNOSTIC-ONLY"
                planRoot
                "the nullary registry view names no phase under validation and cannot pass a phase"
           ]

localSlotFindings :: OraclePhase -> [ExpectedFinding]
localSlotFindings row = concat (zipWith findingFor gateCategories slotMarkers)
  where
    ordinal = oracleOrdinal row
    slotMarkers = Text.unpack (vectorSlotBitmap (oraclePhaseVectorFor ordinal))
    findingFor category marker
        | marker == 'G' =
            [ ExpectedFinding
                "PLAN-SEMANTIC-CONTRACT-GAP"
                (oraclePath row)
                ( "phase="
                    <> renderOrdinal ordinal
                    <> " category="
                    <> category
                    <> " gap=phase-"
                    <> renderOrdinal ordinal
                    <> "-"
                    <> categorySlug category
                )
            ]
        | marker == 'D' =
            [ ExpectedFinding
                "PLAN-SEMANTIC-GATE-EVIDENCE-MISSING"
                (oraclePath row)
                ( "phase="
                    <> renderOrdinal ordinal
                    <> " category="
                    <> category
                    <> " draft=phase-"
                    <> renderOrdinal ordinal
                    <> "-"
                    <> categorySlug category
                    <> " gate-evidence=missing"
                )
            ]
        | marker == 'B' = []
        | otherwise =
            [ ExpectedFinding
                "ORACLE-UNEXPECTED-SLOT-MARKER"
                (oraclePath row)
                ("phase=" <> renderOrdinal ordinal <> " marker=" <> Text.singleton marker)
            ]

localPhaseProjection :: OraclePhase -> Text
localPhaseProjection row =
    Text.intercalate
        "|"
        [ renderOrdinal ordinal
        , oracleCapability row
        , Text.pack (oraclePath row)
        , oracleTitle row
        , oracleSubstrate row
        , oracleLane row
        , oracleRegister row
        , vectorStage contractVector
        , if ordinal == 0 then "genesis" else "phase-" <> renderOrdinal (ordinal - 1)
        , Text.intercalate "," (localLegacyIds ordinal)
        , vectorSlotBitmap contractVector
        , vectorCriticalGuard contractVector
        ]
  where
    ordinal = oracleOrdinal row
    contractVector = oraclePhaseVectorFor ordinal

localLegacyIds :: Int -> [Text]
localLegacyIds ordinal = Map.findWithDefault [] ordinal localLegacyReverseMap

localLegacyReverseMap :: Map.Map Int [Text]
localLegacyReverseMap =
    Map.fromList
        [ (1, ["LTD-SRC-007", "LTD-SRC-009", "LTD-BOOT-001"])
        , (2, ["LTD-SRC-000", "LTD-SRC-008", "LTD-META-001", "LTD-NAME-001"])
        , (25, ["LTD-SRC-002"])
        , (26, ["LTD-SRC-003"])
        , (27, ["LTD-DOC-001"])
        , (46, ["LTD-SRC-004"])
        , (47, ["LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006"])
        , (49, ["LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004", "LTD-VAL-005", "LTD-VAL-006"])
        , (51, ["LTD-HOST-001", "LTD-HOST-002"])
        , (55, ["LTD-RUN-001"])
        , (56, ["LTD-IMG-001"])
        , (91, ["LTD-SEED-001"])
        , (93, ["LTD-SEED-002"])
        ]

expectedResourceObservations :: [(Text, Text)]
expectedResourceObservations =
    [ ("resource.phase-domain-count", "96")
    , ("resource.required-phase-count", "53")
    , ("resource.slot-count", "371")
    , ("resource.gap-count", "329")
    , ("resource.draft-count", "0")
    , ("resource.gate-ready-count", "42")
    , ("resource.target-phase", "none")
    , ("resource.deferred-gap-count", "0")
    ]
        <> [ ( "resource.phase"
             , renderOrdinal ordinal
                <> "|"
                <> vectorResourceProjection (oraclePhaseVectorFor ordinal)
             )
           | ordinal <- [0 .. 95]
           ]

expectedResourceFindings :: [ExpectedFinding]
expectedResourceFindings =
    [ ExpectedFinding
        "PLAN-RESOURCE-CONTRACT-GAP"
        (oraclePath (oraclePhaseFor ordinal))
        ("gap=phase-" <> renderOrdinal ordinal <> "-" <> field)
    | ordinal <- unresolvedResourceOrdinals
    , field <- resourceFields
    ]
        <> [ ExpectedFinding
                "PLAN-RESOURCE-DIAGNOSTIC-ONLY"
                planRoot
                "the nullary resource view cannot authorize a run; Phases 1, 13, 14, 15, 25, and 34 are gate-ready and 47 later contracts remain unresolved"
           ]

canonicalCorpus :: [(FilePath, Text)]
canonicalCorpus =
    [(trackerPath, trackerDocument oraclePhases)]
        <> [(oraclePath row, phaseDocument row) | row <- oraclePhases]

inertProseCorpus :: [(FilePath, Text)]
inertProseCorpus =
    [ ( path
      , Text.replace
            inertProseNeedle
            "provider/module/count/Legacy-looking natural language remains inert."
            contents
      )
    | (path, contents) <- canonicalCorpus
    ]

inertProseNeedle :: Text
inertProseNeedle = "natural-language capability draft is inert."

inertProseReplacementCount :: Int
inertProseReplacementCount =
    sum [Text.count inertProseNeedle contents | (_, contents) <- canonicalCorpus]

denseCommentPairCount :: Int
denseCommentPairCount = 50000

denseCommentLine :: Text
denseCommentLine = Text.replicate denseCommentPairCount "<!--x-->" <> "\n"

denseCommentCorpus :: [(FilePath, Text)]
denseCommentCorpus =
    modifyPath (oraclePath phase0) (denseCommentLine <>) canonicalCorpus

denseCommentFixtureIsExact :: Bool
denseCommentFixtureIsExact =
    Text.count "<!--x-->" denseCommentLine == denseCommentPairCount
        && length (Text.lines denseCommentLine) == 1
        && case lookup (oraclePath phase0) denseCommentCorpus of
            Nothing -> False
            Just contents ->
                corpusUtf8Bytes [(oraclePath phase0, contents)] <= 524288
                    && length (Text.lines contents) <= 8192
                    && corpusUtf8Bytes denseCommentCorpus <= 16777216

canonicalJoinResult :: CheckResult
canonicalJoinResult = phaseSemanticJoinDiagnostic canonicalCorpus

expectedJoinObservations :: [(Text, Text)]
expectedJoinObservations = joinObservations 97 96 1 96

extraPathObservations, duplicatePathObservations, omittedPhaseObservations :: [(Text, Text)]
extraPathObservations = joinObservations 98 96 1 96
duplicatePathObservations = joinObservations 98 97 1 96
omittedPhaseObservations = joinObservations 96 95 1 95

joinObservations :: Int -> Int -> Int -> Int -> [(Text, Text)]
joinObservations suppliedCount parsedCount trackerCount distinctCount =
    [ ("semantic.join.supplied-path-count", showText suppliedCount)
    , ("semantic.join.parsed-phase-count", showText parsedCount)
    , ("semantic.join.tracker-candidate-count", showText trackerCount)
    , ("semantic.join.phase-count", showText parsedCount)
    , ("semantic.join.distinct-ordinal-count", showText distinctCount)
    , ("resource.join.phase-count", showText parsedCount)
    , ("resource.join.distinct-ordinal-count", showText distinctCount)
    ]

expectedJoinFindings :: [ExpectedFinding]
expectedJoinFindings =
    [semanticJoinRefusal, resourceJoinRefusal, markdownJoinRefusal]

semanticJoinRefusal, resourceJoinRefusal, markdownJoinRefusal :: ExpectedFinding
semanticJoinRefusal =
    ExpectedFinding
        "PLAN-SEMANTIC-JOIN-DIAGNOSTIC-ONLY"
        planRoot
        "caller-supplied structural projections cannot populate or pass a semantic contract slot"
resourceJoinRefusal =
    ExpectedFinding
        "PLAN-RESOURCE-JOIN-DIAGNOSTIC-ONLY"
        planRoot
        "Markdown headings cannot authorize mutation or populate the Haskell ResourceProvisionContract"
markdownJoinRefusal =
    ExpectedFinding
        "PLAN-SEMANTIC-MARKDOWN-DIAGNOSTIC-ONLY"
        planRoot
        "Markdown contributes only a narrow structural projection; its prose cannot satisfy a Haskell semantic slot"

phaseDocument :: OraclePhase -> Text
phaseDocument row =
    Text.unlines
        ( [ "# Phase " <> showText ordinal <> ": " <> oracleTitle row
          , ""
          , "## Phase Status"
          , localStatus row <> "."
          , ""
          , "## Phase Summary"
          , "**Phase scope:** natural-language capability draft is inert."
          , "**Substrate:** `" <> oracleSubstrate row <> "`"
          , "**Lane:** `" <> oracleLane row <> "`"
          , "**Register:** " <> oracleRegister row
          , "**Depends on:** " <> localDependsOn row
          , "**Gate:** `pb validate phase " <> renderOrdinal ordinal <> "`; future public spelling only."
          , ""
          , "## Gate integrity"
          , "| Key | Contract |"
          , "|---|---|"
          ]
            <> map (gateRow ordinal) gateCategories
            <> resourceSection ordinal
            <> ["", "## Doctrine adopted", "", "Inert doctrine prose."]
        )
  where
    ordinal = oracleOrdinal row

gateRow :: Int -> Text -> Text
gateRow ordinal category =
    "| `"
        <> category
        <> "` | "
        <> if category `elem` localGapCategoryNames ordinal
            then
                if category == "Subject"
                    then "UNRESOLVED — blocks validation: independent subject missing. |"
                    else "UNRESOLVED — blocks validation: independent " <> Text.toLower category <> " missing. |"
            else "draft prose. |"

resourceSection :: Int -> [Text]
resourceSection ordinal
    | ordinal `elem` [1, 13, 14, 15, 25, 34] =
        [ ""
        , "## Resource provision"
        , "> Run-local owner, preflight, allowed/forbidden write boundary, observer, cleanup, and zero-residue evidence are acquired by the Haskell gate."
        ]
    | ordinal `elem` resourceRequiredOrdinals =
        [ ""
        , "## Resource provision — UNRESOLVED"
        , "> **UNRESOLVED — blocks validation.** No live mutation may begin. Fixture-only inventory."
        ]
    | otherwise = []

trackerDocument :: [OraclePhase] -> Text
trackerDocument rows =
    Text.unlines
        ( [ "# Development Plan"
          , ""
          , trackerHeaderLine
          , trackerDelimiterLine
          ]
            <> map trackerRow rows
        )

trackerHeaderLine, trackerDelimiterLine :: Text
trackerHeaderLine =
    "| Phase | Name | Substrate | Lane | Register | Status | Validation contract |"
trackerDelimiterLine = "|---:|---|---|---|---:|---|---|"

trackerRow :: OraclePhase -> Text
trackerRow row =
    "| "
        <> showText (oracleOrdinal row)
        <> " | "
        <> oracleTitle row
        <> " | "
        <> oracleSubstrate row
        <> " | `"
        <> oracleLane row
        <> "` | "
        <> oracleRegister row
        <> " | "
        <> localStatus row
        <> " | [phase_"
        <> showText (oracleOrdinal row)
        <> "]("
        <> Text.drop (Text.length "DEVELOPMENT_PLAN/") (Text.pack (oraclePath row))
        <> ") |"

localDependsOn :: OraclePhase -> Text
localDependsOn row
    | oracleOrdinal row == 0 = "genesis"
    | otherwise =
        let predecessor = oraclePhaseFor (oracleOrdinal row - 1)
         in "[Phase "
                <> showText (oracleOrdinal predecessor)
                <> "]("
                <> Text.drop (Text.length "DEVELOPMENT_PLAN/") (Text.pack (oraclePath predecessor))
                <> ")"

localStatus :: OraclePhase -> Text
localStatus row = if oracleOrdinal row == 0 then activeStatus else blockedStatus

localTrackerProjection :: OraclePhase -> Text
localTrackerProjection row =
    Text.intercalate
        "|"
        [ oracleTitle row
        , oracleSubstrate row
        , oracleLane row
        , oracleRegister row
        , localStatus row
        , Text.pack (oraclePath row)
        ]

semanticMutationFindings :: [ExpectedFinding] -> [ExpectedFinding]
semanticMutationFindings mutations = mutations <> expectedJoinFindings

omittedPhaseResult, titleMutationResult, predecessorMutationResult, predecessorTrailingResult :: CheckResult
futureCommandMutationResult, resetStatusMutationResult, tabIndentedStatusResult, rawHtmlStatusResult :: CheckResult
summaryOrderMutationResult :: CheckResult
unresolvedMarkerMutationResult, unresolvedSubstringMutationResult, indentedGateRowMutationResult :: CheckResult
listContainedGateTableResult :: CheckResult
listRawHtmlGateTableResult, listFencedGateTableResult :: CheckResult
alternatingFenceGateTableResult :: CheckResult
blockquoteAlternatingHtmlGateTableResult, listAlternatingHtmlGateTableResult :: CheckResult
commentBeforeGateDelimiterResult, indentedGateDelimiterResult :: CheckResult
fenceSplitGateRowsResult, commentSplitGateRowsResult, indentedSplitGateRowsResult :: CheckResult
resourceHeadingMutationResult, indentedResourceBlockerResult, tabIndentedResourceBlockerResult :: CheckResult
rawHtmlResourceBlockerResult, blockquoteRawHtmlResourceResult, blockquoteFencedResourceResult :: CheckResult
alternatingFenceResourceResult :: CheckResult
blockquoteAlternatingHtmlResourceResult, listAlternatingHtmlResourceResult :: CheckResult
trackerTargetMutationResult, indentedTrackerRowResult, listContainedTrackerResult :: CheckResult
alteredTrackerNameHeaderResult, alteredTrackerContractHeaderResult, missingTrackerDelimiterResult :: CheckResult
multiColonTrackerDelimiterResult, rawHtmlTrackerResult, listRawHtmlTrackerResult, listFencedTrackerResult :: CheckResult
alternatingFenceTrackerResult :: CheckResult
blockquoteAlternatingHtmlTrackerResult, listAlternatingHtmlTrackerResult :: CheckResult
spaceBlankTerminatedHtmlTrackerResult, tabBlankTerminatedHtmlTrackerResult :: CheckResult
nonAsciiWhitespaceTrackerResult, splitTrackerFenceResult :: CheckResult
omittedPhaseResult =
    phaseSemanticJoinDiagnostic (omitPath (oraclePath phase95) canonicalCorpus)
titleMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase52)
            ("# Phase 52: " <> oracleTitle phase52)
            "# Phase 52: Linux: sudoless Docker and the native image altered"
            canonicalCorpus
        )
predecessorMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase52)
            "[Phase 51](phase_51_host_ensure_kernel.md)"
            "[Phase 50](phase_50_host_assert_cli.md)"
            canonicalCorpus
        )
predecessorTrailingResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase52)
            "[Phase 51](phase_51_host_ensure_kernel.md)"
            "[Phase 51](phase_51_host_ensure_kernel.md) trailing"
            canonicalCorpus
        )
futureCommandMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase50)
            "`pb validate phase 50`"
            "`pb validate phase 49`"
            canonicalCorpus
        )
resetStatusMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase0)
            (activeStatus <> ".")
            (blockedStatus <> ".")
            canonicalCorpus
        )
tabIndentedStatusResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase0)
            (activeStatus <> ".")
            ("\t" <> activeStatus <> ".")
            canonicalCorpus
        )
rawHtmlStatusResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase0)
            (activeStatus <> ".")
            (rawScriptBlock (activeStatus <> "."))
            canonicalCorpus
        )
summaryOrderMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase34)
            "**Substrate:** `none`\n**Lane:** `none`"
            "**Lane:** `none`\n**Substrate:** `none`"
            canonicalCorpus
        )
unresolvedMarkerMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath (oraclePhaseFor 36))
            phase11SubjectGateRow
            "| `Subject` | blocks validation: independent subject missing. |"
            canonicalCorpus
        )
unresolvedSubstringMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath (oraclePhaseFor 36))
            phase11SubjectGateRow
            "| `Subject` | incidental prose mentions UNRESOLVED without the governed prefix. |"
            canonicalCorpus
        )
indentedGateRowMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            phase1SubjectGateRow
            ("    " <> phase1SubjectGateRow)
            canonicalCorpus
        )
listContainedGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (listContainedBlock (phaseGateTable 1))
            canonicalCorpus
        )
listRawHtmlGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (listItemRawScriptBlock (phaseGateTable 1))
            canonicalCorpus
        )
listFencedGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (listItemFencedBlock (phaseGateTable 1))
            canonicalCorpus
        )
alternatingFenceGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (alternatingFenceBlock (phaseGateTable 1))
            canonicalCorpus
        )
blockquoteAlternatingHtmlGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (alternatingRawHtmlBlock ">" (phaseGateTable 1))
            canonicalCorpus
        )
listAlternatingHtmlGateTableResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (alternatingRawHtmlBlock "- " (phaseGateTable 1))
            canonicalCorpus
        )
commentBeforeGateDelimiterResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (phaseGateTableWithPrefixDelimiter "<!-- inert -->|---|---|" 1)
            canonicalCorpus
        )
indentedGateDelimiterResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (phaseGateTableWithDelimiter "    |---|---|" 1)
            canonicalCorpus
        )
fenceSplitGateRowsResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (splitPhaseGateTable ["```", "inert", "```"] 1)
            canonicalCorpus
        )
commentSplitGateRowsResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (splitPhaseGateTable ["<!-- inert -->|---|---|"] 1)
            canonicalCorpus
        )
indentedSplitGateRowsResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase1)
            (phaseGateTable 1)
            (splitPhaseGateTable ["    |---|---|"] 1)
            canonicalCorpus
        )
resourceHeadingMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            "## Resource provision — UNRESOLVED"
            "## Resource provision — DRAFTED"
            canonicalCorpus
        )
indentedResourceBlockerResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            ("    " <> resourceBlockerLine)
            canonicalCorpus
        )
tabIndentedResourceBlockerResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            ("\t" <> resourceBlockerLine)
            canonicalCorpus
        )
rawHtmlResourceBlockerResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (rawScriptBlock resourceBlockerLine)
            canonicalCorpus
        )
blockquoteRawHtmlResourceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (blockquoteRawScriptBlock resourceBlockerLine)
            canonicalCorpus
        )
blockquoteFencedResourceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (blockquoteFencedBlock resourceBlockerLine)
            canonicalCorpus
        )
alternatingFenceResourceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (alternatingFenceBlock resourceBlockerLine)
            canonicalCorpus
        )
blockquoteAlternatingHtmlResourceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (alternatingRawHtmlBlock ">" resourceBlockerLine)
            canonicalCorpus
        )
listAlternatingHtmlResourceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            (oraclePath phase43)
            resourceBlockerLine
            (alternatingRawHtmlBlock "- " resourceBlockerLine)
            canonicalCorpus
        )
trackerTargetMutationResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            "phase_84_ui_ha_multizone.md"
            "phase_84_ui_ha_multizone.md-altered"
            canonicalCorpus
        )
indentedTrackerRowResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            (trackerRow phase84)
            ("    " <> trackerRow phase84)
            canonicalCorpus
        )
listContainedTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (const (listContainedBlock (trackerTable oraclePhases)))
            canonicalCorpus
        )
alteredTrackerNameHeaderResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            trackerHeaderLine
            "| Phase | Capability | Substrate | Lane | Register | Status | Validation contract |"
            canonicalCorpus
        )
alteredTrackerContractHeaderResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            trackerHeaderLine
            "| Phase | Name | Substrate | Lane | Register | Status | Contract |"
            canonicalCorpus
        )
missingTrackerDelimiterResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            (trackerHeaderLine <> "\n" <> trackerDelimiterLine <> "\n")
            (trackerHeaderLine <> "\n")
            canonicalCorpus
        )
multiColonTrackerDelimiterResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            trackerDelimiterLine
            multiColonTrackerDelimiterLine
            canonicalCorpus
        )
rawHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (\contents -> "<script>\n" <> contents <> "</script>\n")
            canonicalCorpus
        )
listRawHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath listItemRawScriptBlock canonicalCorpus)
listFencedTrackerResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath listItemFencedBlock canonicalCorpus)
alternatingFenceTrackerResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath (const (alternatingFenceBlock (trackerTable oraclePhases))) canonicalCorpus)
blockquoteAlternatingHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (const (alternatingRawHtmlBlock ">" (trackerTable oraclePhases)))
            canonicalCorpus
        )
listAlternatingHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (const (alternatingRawHtmlBlock "- " (trackerTable oraclePhases)))
            canonicalCorpus
        )
spaceBlankTerminatedHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (const (htmlUntilBlankThenTracker spaceOnlyPhysicalLine))
            canonicalCorpus
        )
tabBlankTerminatedHtmlTrackerResult =
    phaseSemanticJoinDiagnostic
        ( modifyPath
            trackerPath
            (const (htmlUntilBlankThenTracker tabOnlyPhysicalLine))
            canonicalCorpus
        )
nonAsciiWhitespaceTrackerResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath (<> (nonAsciiWhitespaceLine <> "\n")) canonicalCorpus)
splitTrackerFenceResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath (const splitTrackerFenceDocument) canonicalCorpus)

rawScriptBlock :: Text -> Text
rawScriptBlock contents = "<script>\n" <> contents <> "\n</script>"

listItemRawScriptBlock :: Text -> Text
listItemRawScriptBlock contents =
    Text.unlines
        ("- <script>" : map ("  " <>) (Text.lines contents) <> ["  </script>"])

listItemFencedBlock :: Text -> Text
listItemFencedBlock contents =
    Text.unlines
        ("- ```" : map ("  " <>) (Text.lines contents) <> ["  ```"])

listContainedBlock :: Text -> Text
listContainedBlock contents =
    Text.unlines ("- governed structure:" : map ("  " <>) (Text.lines contents))

blockquoteRawScriptBlock :: Text -> Text
blockquoteRawScriptBlock contents =
    Text.unlines ["> <script>", "> " <> contents, "> </script>"]

blockquoteFencedBlock :: Text -> Text
blockquoteFencedBlock contents =
    Text.unlines ["> ```", "> " <> contents, "> ```"]

alternatingFenceBlock :: Text -> Text
alternatingFenceBlock contents = "```\n- ```\n" <> contents

alternatingRawHtmlBlock :: Text -> Text -> Text
alternatingRawHtmlBlock physicalContainerMarker contents =
    "<div>\n" <> physicalContainerMarker <> "\n" <> contents <> "\n"

phaseGateTable :: Int -> Text
phaseGateTable ordinal =
    phaseGateTableWithDelimiter gateDelimiterLine ordinal

gateHeaderLine, gateDelimiterLine :: Text
gateHeaderLine = "| Key | Contract |"
gateDelimiterLine = "|---|---|"

phaseGateRows :: Int -> [Text]
phaseGateRows ordinal = map (gateRow ordinal) gateCategories

phaseGateTableWithDelimiter :: Text -> Int -> Text
phaseGateTableWithDelimiter delimiter ordinal =
    Text.unlines (gateHeaderLine : delimiter : phaseGateRows ordinal)

phaseGateTableWithPrefixDelimiter :: Text -> Int -> Text
phaseGateTableWithPrefixDelimiter prefix ordinal =
    Text.unlines (gateHeaderLine : prefix : gateDelimiterLine : phaseGateRows ordinal)

gateSplitRowCount :: Int
gateSplitRowCount = 9

splitPhaseGateTable :: [Text] -> Int -> Text
splitPhaseGateTable spliceLines ordinal =
    Text.unlines
        ( [gateHeaderLine, gateDelimiterLine]
            <> take gateSplitRowCount rows
            <> spliceLines
            <> drop gateSplitRowCount rows
        )
  where
    rows = phaseGateRows ordinal

trackerTable :: [OraclePhase] -> Text
trackerTable rows =
    Text.unlines (trackerHeaderLine : trackerDelimiterLine : map trackerRow rows)

splitTrackerFenceDocument :: Text
splitTrackerFenceDocument =
    Text.unlines
        ( [trackerHeaderLine, trackerDelimiterLine]
            <> map trackerRow lowerRows
            <> ["```", "inert", "```"]
            <> map trackerRow upperRows
        )
  where
    lowerRows = filter ((<= 47) . oracleOrdinal) oraclePhases
    upperRows = filter ((>= 48) . oracleOrdinal) oraclePhases

gateSpliceFixturesAreExact :: Bool
gateSpliceFixturesAreExact =
    gateSplitRowCount == 9
        && length (phaseGateRows 1) == 18
        && all
            ((== 9) . length)
            [ take gateSplitRowCount (phaseGateRows 1)
            , drop gateSplitRowCount (phaseGateRows 1)
            ]
        && length (Text.lines (phaseGateTableWithPrefixDelimiter "<!-- inert -->|---|---|" 1)) == 21
        && length (Text.lines (phaseGateTableWithDelimiter "    |---|---|" 1)) == 20
        && length (Text.lines (splitPhaseGateTable ["```", "inert", "```"] 1)) == 23
        && length (Text.lines (splitPhaseGateTable ["<!-- inert -->|---|---|"] 1)) == 21
        && length (Text.lines (splitPhaseGateTable ["    |---|---|"] 1)) == 21
        && all
            (not . any (Text.null . Text.strip) . Text.lines)
            [ phaseGateTableWithPrefixDelimiter "<!-- inert -->|---|---|" 1
            , phaseGateTableWithDelimiter "    |---|---|" 1
            , splitPhaseGateTable ["```", "inert", "```"] 1
            , splitPhaseGateTable ["<!-- inert -->|---|---|"] 1
            , splitPhaseGateTable ["    |---|---|"] 1
            ]
        && case lookup (oraclePath phase1) canonicalCorpus of
            Nothing -> False
            Just contents -> Text.count (phaseGateTable 1) contents == 1

trackerSplitFixtureIsExact :: Bool
trackerSplitFixtureIsExact =
    length (filter ((<= 47) . oracleOrdinal) oraclePhases) == 48
        && length (filter ((>= 48) . oracleOrdinal) oraclePhases) == 48
        && length (Text.lines splitTrackerFenceDocument) == 101
        && not (any (Text.null . Text.strip) (Text.lines splitTrackerFenceDocument))
        && Text.count trackerHeaderLine splitTrackerFenceDocument == 1
        && Text.count trackerDelimiterLine splitTrackerFenceDocument == 1
        && Text.count "```" splitTrackerFenceDocument == 2

listContainedFixturesAreExact :: Bool
listContainedFixturesAreExact =
    exactListFixture (phaseGateTable 1) 20
        && exactListFixture (trackerTable oraclePhases) 98
  where
    exactListFixture source expectedStructuralLines =
        case Text.lines (listContainedBlock source) of
            marker : structuralLines ->
                marker == "- governed structure:"
                    && length structuralLines == expectedStructuralLines
                    && all (Text.isPrefixOf "  |") structuralLines
            [] -> False

htmlUntilBlankThenTracker :: Text -> Text
htmlUntilBlankThenTracker physicalBlank =
    "<div>\nopaque raw HTML\n"
        <> physicalBlank
        <> "\n"
        <> trackerTable oraclePhases

spaceOnlyPhysicalLine, tabOnlyPhysicalLine, nonAsciiWhitespaceLine :: Text
spaceOnlyPhysicalLine = "   "
tabOnlyPhysicalLine = "\t"
nonAsciiWhitespaceLine = "\x00a0"

multiColonTrackerDelimiterLine :: Text
multiColonTrackerDelimiterLine =
    "|:::---:::|:::---:::|:::---:::|:::---:::|:::---:::|:::---:::|:::---:::|"

phase1SubjectGateRow, phase11SubjectGateRow, resourceBlockerLine :: Text
phase1SubjectGateRow =
    "| `Subject` | draft prose. |"
phase11SubjectGateRow =
    "| `Subject` | UNRESOLVED — blocks validation: independent subject missing. |"
resourceBlockerLine =
    "> **UNRESOLVED — blocks validation.** No live mutation may begin. Fixture-only inventory."

phase0, phase1, phase34, phase43, phase50, phase52, phase84, phase95 :: OraclePhase
phase0 = oraclePhaseFor 0
phase1 = oraclePhaseFor 1
phase34 = oraclePhaseFor 34
phase43 = oraclePhaseFor 43
phase50 = oraclePhaseFor 50
phase52 = oraclePhaseFor 52
phase84 = oraclePhaseFor 84
phase95 = oraclePhaseFor 95

omittedPhaseFindings :: [ExpectedFinding]
omittedPhaseFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-PHASE-PATH-MISSING"
        (oraclePath phase95)
        "canonical phase path was not supplied; phase=95"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-UNJOINED"
        trackerPath
        "phase=95 tracker row has no phase contract"
    , ExpectedFinding
        "PLAN-SEMANTIC-JOIN-CARDINALITY"
        planRoot
        "expected exactly 96 phase projections; observed 95"
    , ExpectedFinding
        "PLAN-SEMANTIC-JOIN-MISSING"
        (oraclePath phase95)
        "phase=95 structural projection is absent"
    , semanticJoinRefusal
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-CARDINALITY"
        planRoot
        "expected exactly 96 phase resource projections; observed 95"
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-MISSING"
        (oraclePath phase95)
        "phase=95 resource projection is absent"
    , resourceJoinRefusal
    , markdownJoinRefusal
    ]

titleMutationFinding, predecessorMutationFinding, predecessorTrailingFinding :: ExpectedFinding
futureCommandMutationFinding, resetStatusMutationFinding, summaryOrderMutationFinding :: ExpectedFinding
unresolvedMarkerMutationFinding, trackerTargetMutationFinding :: ExpectedFinding
titleMutationFinding =
    semanticMismatch 52 "title" (oracleTitle phase52) "Linux: sudoless Docker and the native image altered"
predecessorMutationFinding =
    semanticMismatch
        52
        "predecessor-link"
        ("Phase 51|DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md" :: Text)
        ("Phase 50|DEVELOPMENT_PLAN/phase_50_host_assert_cli.md" :: Text)
predecessorTrailingFinding =
    semanticMismatch
        52
        "predecessor-link"
        ("Phase 51|DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md" :: Text)
        ("MALFORMED" :: Text)
futureCommandMutationFinding =
    semanticMismatch 50 "future-command" ("pb validate phase 50" :: Text) ("pb validate phase 49" :: Text)
resetStatusMutationFinding = semanticMismatch 0 "current-status" activeStatus blockedStatus
tabIndentedStatusFinding :: ExpectedFinding
tabIndentedStatusFinding =
    semanticMismatch 0 "current-status" activeStatus ("MISSING" :: Text)
summaryOrderMutationFinding =
    semanticMismatch
        34
        "summary-field-order"
        summaryFields
        ["Phase scope", "Lane", "Substrate", "Register", "Depends on", "Gate"]
unresolvedMarkerMutationFinding =
    semanticMismatch
        36
        "unresolved-shape"
        (localGapCategoryNames 36)
        (filter (/= "Subject") (localGapCategoryNames 36))
unresolvedSubstringMutationFinding :: ExpectedFinding
unresolvedSubstringMutationFinding = unresolvedMarkerMutationFinding

indentedGateRowMutationFindings :: [ExpectedFinding]
indentedGateRowMutationFindings = hiddenGateTableFindings

hiddenGateTableFindings :: [ExpectedFinding]
hiddenGateTableFindings =
    [ semanticMismatch
        1
        "gate-row-order"
        gateCategories
        ([] :: [Text])
    ]

hiddenGateTableResultFindings :: [ExpectedFinding]
hiddenGateTableResultFindings =
    hiddenGateTableFindings
        <> [ semanticJoinRefusal
           , ExpectedFinding
                "PLAN-RESOURCE-JOIN-MISMATCH"
                (oraclePath phase1)
                ( "phase=01 field=heading expected="
                    <> showText ("Resource provision" :: Text)
                    <> " actual="
                    <> showText ("ABSENT" :: Text)
                )
           , resourceJoinRefusal
           , markdownJoinRefusal
           ]
trackerTargetMutationFinding =
    semanticMismatch
        84
        "tracker-row"
        (localTrackerProjection phase84)
        (localTrackerProjection phase84 <> "-altered")

resourceHeadingMutationFindings :: [ExpectedFinding]
resourceHeadingMutationFindings =
    [ semanticJoinRefusal
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-MISMATCH"
        (oraclePath phase43)
        ( "phase=43 field=heading expected="
            <> showText ("Resource provision — UNRESOLVED" :: Text)
            <> " actual="
            <> showText ("Resource provision — DRAFTED" :: Text)
        )
    , resourceJoinRefusal
    , markdownJoinRefusal
    ]

indentedResourceBlockerFindings :: [ExpectedFinding]
indentedResourceBlockerFindings =
    [ semanticJoinRefusal
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-MISMATCH"
        (oraclePath phase43)
        "phase=43 field=unresolved-blocker expected=True actual=False"
    , resourceJoinRefusal
    , markdownJoinRefusal
    ]

malformedPhasePath, unknownPhasePath :: FilePath
malformedPhasePath = "DEVELOPMENT_PLAN/phaseX.md"
unknownPhasePath = "DEVELOPMENT_PLAN/phase_52_wrong.md"

malformedPathResult, unknownPathResult, duplicatePathResult :: CheckResult
malformedPathResult = phaseSemanticJoinDiagnostic (canonicalCorpus <> [(malformedPhasePath, "")])
unknownPathResult = phaseSemanticJoinDiagnostic (canonicalCorpus <> [(unknownPhasePath, "")])
duplicatePathResult =
    phaseSemanticJoinDiagnostic (canonicalCorpus <> [(oraclePath phase52, phaseDocument phase52)])

malformedPathFindings, unknownPathFindings, duplicatePathFindings :: [ExpectedFinding]
malformedPathFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-PHASE-PATH-MALFORMED"
        malformedPhasePath
        "phase-like path must be DEVELOPMENT_PLAN/phase_NN_<canonical-slug>.md with exactly two decimal ordinal digits"
    ]
        <> expectedJoinFindings
unknownPathFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-PHASE-PATH-UNKNOWN"
        unknownPhasePath
        ( "phase-like path does not equal the canonical path for ordinal=52; canonical="
            <> Text.pack (oraclePath phase52)
        )
    ]
        <> expectedJoinFindings
duplicatePathFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-PHASE-PATH-DUPLICATE"
        (oraclePath phase52)
        "phase-like supplied path occurs more than once; observed=2"
    , ExpectedFinding
        "PLAN-SEMANTIC-JOIN-CARDINALITY"
        planRoot
        "expected exactly 96 phase projections; observed 97"
    , ExpectedFinding
        "PLAN-SEMANTIC-JOIN-DUPLICATE"
        planRoot
        "phase=52 has 2 projections"
    , semanticJoinRefusal
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-CARDINALITY"
        planRoot
        "expected exactly 96 phase resource projections; observed 97"
    , ExpectedFinding
        "PLAN-RESOURCE-JOIN-DUPLICATE"
        planRoot
        "phase=52 has 2 projections"
    , resourceJoinRefusal
    , markdownJoinRefusal
    ]

malformedTrackerResult, outOfRangeTrackerResult, extraTrackerResult :: CheckResult
malformedTrackerResult =
    phaseSemanticJoinDiagnostic (replaceInPath trackerPath "| 84 |" "| 84+ |" canonicalCorpus)
outOfRangeTrackerResult =
    phaseSemanticJoinDiagnostic (replaceInPath trackerPath "| 84 |" "| 96 |" canonicalCorpus)
extraTrackerResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath (<> (trackerRow phase0 <> "\n")) canonicalCorpus)

malformedTrackerFindings, outOfRangeTrackerFindings, extraTrackerFindings :: [ExpectedFinding]
malformedTrackerFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        trackerPath
        "locus=line:89 reason=tracker ordinal must contain a representable decimal integer"
    ]
        <> missingTrackerRowFindings 84
outOfRangeTrackerFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-OUT-OF-RANGE"
        trackerPath
        "locus=line:89 ordinal=96 reason=tracker ordinals are closed to the canonical 0..95 domain"
    ]
        <> missingTrackerRowFindings 84
extraTrackerFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-EXTRA"
        trackerPath
        "locus=canonical-tracker-table expected=96 observed=97 reason=raw tracker accounting found rows beyond the closed canonical phase inventory"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        trackerPath
        "expected exactly 96 tracker rows; observed 97"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-DUPLICATE"
        trackerPath
        "phase=0 has 2 tracker rows"
    , semanticMismatch 0 "tracker-row" (localTrackerProjection phase0) ("AMBIGUOUS:2" :: Text)
    ]
        <> expectedJoinFindings

indentedTrackerRowFindings :: [ExpectedFinding]
indentedTrackerRowFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        trackerPath
        "locus=line:89 reason=tracker candidate must have outer pipes and exactly seven cells"
    ]
        <> missingTrackerRowFindings 84

nonAsciiWhitespaceTrackerFindings :: [ExpectedFinding]
nonAsciiWhitespaceTrackerFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        trackerPath
        "locus=line:101 reason=tracker candidate must have outer pipes and exactly seven cells"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-EXTRA"
        trackerPath
        "locus=canonical-tracker-table expected=96 observed=97 reason=raw tracker accounting found rows beyond the closed canonical phase inventory"
    ]
        <> expectedJoinFindings

splitTrackerFenceFindings :: [ExpectedFinding]
splitTrackerFenceFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        trackerPath
        "expected exactly 96 tracker rows; observed 48"
    ]
        <> [ ExpectedFinding
                "PLAN-SEMANTIC-TRACKER-MISSING"
                (oraclePath row)
                ("phase=" <> showText (oracleOrdinal row) <> " has no tracker row")
           | row <- missingRows
           ]
        <> [ semanticMismatch
                (oracleOrdinal row)
                "tracker-row"
                (localTrackerProjection row)
                ("MISSING" :: Text)
           | row <- missingRows
           ]
        <> expectedJoinFindings
  where
    missingRows = filter ((>= 48) . oracleOrdinal) oraclePhases

missingTrackerRowFindings :: Int -> [ExpectedFinding]
missingTrackerRowFindings ordinal =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        trackerPath
        "expected exactly 96 tracker rows; observed 95"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-MISSING"
        (oraclePath row)
        ("phase=" <> showText ordinal <> " has no tracker row")
    , semanticMismatch ordinal "tracker-row" (localTrackerProjection row) ("MISSING" :: Text)
    ]
        <> expectedJoinFindings
  where
    row = oraclePhaseFor ordinal

pseudoFenceCloserResult, indentedFenceDecoyResult, htmlFenceDecoyResult, htmlHeaderSpliceResult :: CheckResult
pseudoFenceCloserResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath (Text.unlines ["```", "``` trailing"] <>) canonicalCorpus)
indentedFenceDecoyResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath ("    ```\n" <>) canonicalCorpus)
htmlFenceDecoyResult =
    phaseSemanticJoinDiagnostic
        (modifyPath trackerPath ("<!-- ``` -->\n" <>) canonicalCorpus)
htmlHeaderSpliceResult =
    phaseSemanticJoinDiagnostic
        ( replaceInPath
            trackerPath
            "| Phase | Name |"
            "| Ph<!-- inert -->ase | Name |"
            canonicalCorpus
        )

missingTrackerDelimiterFindings :: [ExpectedFinding]
missingTrackerDelimiterFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        trackerPath
        "locus=line:3 reason=canonical tracker header must be followed immediately by a seven-cell Markdown delimiter row"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        trackerPath
        "expected exactly 96 tracker rows; observed 0"
    ]
        <> [ ExpectedFinding
                "PLAN-SEMANTIC-TRACKER-MISSING"
                (oraclePath row)
                ("phase=" <> showText (oracleOrdinal row) <> " has no tracker row")
           | row <- oraclePhases
           ]
        <> [ semanticMismatch
                (oracleOrdinal row)
                "tracker-row"
                (localTrackerProjection row)
                ("MISSING" :: Text)
           | row <- oraclePhases
           ]
        <> expectedJoinFindings

noTrackerFindings :: [ExpectedFinding]
noTrackerFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-TABLE-CARDINALITY"
        trackerPath
        "locus=canonical-tracker-table expected=1 observed=0 reason=the canonical tracker header must identify exactly one raw row inventory"
    , ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        trackerPath
        "expected exactly 96 tracker rows; observed 0"
    ]
        <> [ ExpectedFinding
                "PLAN-SEMANTIC-TRACKER-MISSING"
                (oraclePath row)
                ("phase=" <> showText (oracleOrdinal row) <> " has no tracker row")
           | row <- oraclePhases
           ]
        <> [ semanticMismatch
                (oracleOrdinal row)
                "tracker-row"
                (localTrackerProjection row)
                ("MISSING" :: Text)
           | row <- oraclePhases
           ]
        <> expectedJoinFindings

data InputBoundaryCase = InputBoundaryCase
    { inputBoundaryLabel :: String
    , inputBoundaryObservations :: [(Text, Text)]
    , inputBoundaryFindings :: [ExpectedFinding]
    , inputBoundaryResult :: CheckResult
    }

exactBoundaryProblems :: InputBoundaryCase -> [String]
exactBoundaryProblems boundary =
    expectExactJoinResult
        (inputBoundaryLabel boundary)
        (inputBoundaryObservations boundary)
        (inputBoundaryFindings boundary)
        (inputBoundaryResult boundary)

inputBoundaryCases :: [InputBoundaryCase]
inputBoundaryCases =
    [ InputBoundaryCase
        "the exact 384-entry boundary remains admitted"
        (joinObservations 384 96 1 96)
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic entryBoundaryCorpus)
    , InputBoundaryCase
        "the 385th supplied entry refuses before semantic parsing"
        (inputLimitObservations 385 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-INPUT-ENTRY-LIMIT"
            planRoot
            "supplied-entry-count"
            384
            385
            "the structural join refuses before parsing when the supplied document corpus exceeds its configured entry bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic entryOneOverCorpus)
    , InputBoundaryCase
        "the exact 256-character supplied path remains admitted"
        (joinObservations 98 96 1 96)
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic pathLengthBoundaryCorpus)
    , InputBoundaryCase
        "the 257th supplied-path character refuses before semantic parsing"
        (inputLimitObservations 98 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-INPUT-PATH-LENGTH-LIMIT"
            pathLengthOneOver
            "supplied-path-characters"
            256
            257
            "the supplied path exceeds the configured character-length bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic pathLengthOneOverCorpus)
    , InputBoundaryCase
        "the exact 524288-byte per-document boundary remains admitted"
        (joinObservations 98 96 1 96)
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic documentByteBoundaryCorpus)
    , InputBoundaryCase
        "the 524289th per-document byte refuses before semantic parsing"
        (inputLimitObservations 98 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-INPUT-DOCUMENT-BYTE-LIMIT"
            documentBytePath
            "document-utf8-bytes"
            524288
            524289
            "the supplied document exceeds the configured UTF-8 byte bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic documentByteOneOverCorpus)
    , InputBoundaryCase
        "the exact 16777216-byte aggregate boundary remains admitted"
        (joinObservations (length totalByteBoundaryCorpus) 96 1 96)
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic totalByteBoundaryCorpus)
    , InputBoundaryCase
        "the 16777217th aggregate byte refuses before semantic parsing"
        (inputLimitObservations (length totalByteOneOverCorpus) 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-INPUT-TOTAL-BYTE-LIMIT"
            planRoot
            "supplied-total-utf8-bytes"
            16777216
            16777217
            "the structural join refuses before parsing when aggregate supplied UTF-8 bytes exceed the configured bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic totalByteOneOverCorpus)
    , InputBoundaryCase
        "the exact 8192-line document boundary remains admitted"
        (joinObservations 98 96 1 96)
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic documentLineBoundaryCorpus)
    , InputBoundaryCase
        "the 8193rd document line refuses before semantic parsing"
        (inputLimitObservations 98 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-INPUT-DOCUMENT-LINE-LIMIT"
            documentLinePath
            "document-lines"
            8192
            8193
            "the supplied document exceeds the configured physical-line bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic documentLineOneOverCorpus)
    , InputBoundaryCase
        "exactly 128 raw tracker candidates are parsed and every malformed row remains visible"
        expectedJoinObservations
        trackerRawBoundaryFindings
        (phaseSemanticJoinDiagnostic trackerRawBoundaryCorpus)
    , InputBoundaryCase
        "the 129th non-pipe raw tracker candidate refuses before semantic parsing"
        (inputLimitObservations 97 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-TRACKER-ROW-LIMIT"
            trackerPath
            "tracker-raw-candidate-rows"
            128
            129
            "the tracker exceeds its configured pre-parse raw candidate-row bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic trackerRawOneOverCorpus)
    , InputBoundaryCase
        "overlapping repeated tracker headers saturate at 129 candidates and refuse before semantic parsing"
        (inputLimitObservations 97 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-TRACKER-ROW-LIMIT"
            trackerPath
            "tracker-raw-candidate-rows"
            128
            129
            "the tracker exceeds its configured pre-parse raw candidate-row bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic repeatedTrackerHeaderCorpus)
    , InputBoundaryCase
        "exactly 32 visible phase pipe rows remain admitted and inert outside governed sections"
        expectedJoinObservations
        expectedJoinFindings
        (phaseSemanticJoinDiagnostic phaseRowBoundaryCorpus)
    , InputBoundaryCase
        "the 33rd visible phase pipe row refuses before semantic parsing"
        (inputLimitObservations 97 1)
        [ inputLimitFinding
            "PLAN-SEMANTIC-PHASE-ROW-LIMIT"
            (oraclePath phase0)
            "phase-visible-pipe-rows"
            32
            33
            "the phase-like document exceeds its configured pre-parse visible table-row bound"
        , markdownJoinRefusal
        ]
        (phaseSemanticJoinDiagnostic phaseRowOneOverCorpus)
    ]

inputLimitObservations :: Int -> Int -> [(Text, Text)]
inputLimitObservations suppliedCount trackerCount =
    [ ("semantic.join.supplied-path-count", showText suppliedCount)
    , ("semantic.join.parsed-phase-count", "0")
    , ("semantic.join.tracker-candidate-count", showText trackerCount)
    , ("semantic.join.input-preflight", "refused-before-semantic-parsing")
    ]

inputLimitFinding :: Text -> FilePath -> Text -> Integer -> Integer -> Text -> ExpectedFinding
inputLimitFinding code subject locus limit observed reason =
    ExpectedFinding
        code
        subject
        ( "locus="
            <> locus
            <> " limit="
            <> showText limit
            <> " observed="
            <> showText observed
            <> " reason="
            <> reason
        )

entryBoundaryCorpus, entryOneOverCorpus :: [(FilePath, Text)]
entryBoundaryCorpus = canonicalCorpus <> irrelevantEntries "entry-boundary" 287
entryOneOverCorpus = canonicalCorpus <> irrelevantEntries "entry-one-over" 288

irrelevantEntries :: String -> Int -> [(FilePath, Text)]
irrelevantEntries label count =
    [("oracle/" <> label <> "-" <> show index, "") | index <- [1 .. count]]

pathLengthBoundary, pathLengthOneOver :: FilePath
pathLengthBoundary = replicate 256 'p'
pathLengthOneOver = replicate 257 'p'

pathLengthBoundaryCorpus, pathLengthOneOverCorpus :: [(FilePath, Text)]
pathLengthBoundaryCorpus = canonicalCorpus <> [(pathLengthBoundary, "")]
pathLengthOneOverCorpus = canonicalCorpus <> [(pathLengthOneOver, "")]

documentBytePath :: FilePath
documentBytePath = "oracle/document-byte-boundary"

documentByteBoundaryCorpus, documentByteOneOverCorpus :: [(FilePath, Text)]
documentByteBoundaryCorpus = canonicalCorpus <> [(documentBytePath, Text.replicate 524288 "x")]
documentByteOneOverCorpus = canonicalCorpus <> [(documentBytePath, Text.replicate 524289 "x")]

configuredTotalDocumentBytes, totalPaddingChunkBytes :: Integer
configuredTotalDocumentBytes = 16777216
totalPaddingChunkBytes = 524287

totalByteBoundaryCorpus, totalByteOneOverCorpus :: [(FilePath, Text)]
totalByteBoundaryCorpus =
    canonicalCorpus
        <> totalBytePaddingDocuments
            (configuredTotalDocumentBytes - corpusUtf8Bytes canonicalCorpus)
totalByteOneOverCorpus = incrementLastDocument totalByteBoundaryCorpus

totalBytePaddingDocuments :: Integer -> [(FilePath, Text)]
totalBytePaddingDocuments byteCount = go 0 byteCount
  where
    go :: Integer -> Integer -> [(FilePath, Text)]
    go _ remaining | remaining <= 0 = []
    go index remaining =
        let admitted = min totalPaddingChunkBytes remaining
         in ( "oracle/total-byte-padding-" <> show index
            , Text.replicate (fromInteger admitted) "x"
            )
                : go (index + 1) (remaining - admitted)

incrementLastDocument :: [(FilePath, Text)] -> [(FilePath, Text)]
incrementLastDocument entries = case reverse entries of
    [] -> []
    (path, contents) : remaining -> reverse remaining <> [(path, contents <> "x")]

corpusUtf8Bytes :: [(FilePath, Text)] -> Integer
corpusUtf8Bytes =
    sum . map (toInteger . ByteString.length . TextEncoding.encodeUtf8 . snd)

documentLinePath :: FilePath
documentLinePath = "oracle/document-line-boundary"

documentLineBoundaryCorpus, documentLineOneOverCorpus :: [(FilePath, Text)]
documentLineBoundaryCorpus = canonicalCorpus <> [(documentLinePath, lineDocument 8192)]
documentLineOneOverCorpus = canonicalCorpus <> [(documentLinePath, lineDocument 8193)]

lineDocument :: Int -> Text
lineDocument count = Text.unlines (replicate count "x")

trackerRawBoundaryCorpus, trackerRawOneOverCorpus :: [(FilePath, Text)]
trackerRawBoundaryCorpus =
    modifyPath trackerPath (<> rawTrackerCandidates 32) canonicalCorpus
trackerRawOneOverCorpus =
    modifyPath trackerPath (<> rawTrackerCandidates 33) canonicalCorpus

rawTrackerCandidates :: Int -> Text
rawTrackerCandidates count = Text.unlines (replicate count "non-pipe raw tracker candidate")

repeatedTrackerHeaderPairCount :: Int
repeatedTrackerHeaderPairCount = 66

repeatedTrackerHeaderDocument :: Text
repeatedTrackerHeaderDocument =
    Text.unlines
        ( concat
            ( replicate
                repeatedTrackerHeaderPairCount
                [trackerHeaderLine, trackerDelimiterLine]
            )
        )

repeatedTrackerHeaderCorpus :: [(FilePath, Text)]
repeatedTrackerHeaderCorpus =
    modifyPath trackerPath (const repeatedTrackerHeaderDocument) canonicalCorpus

trackerRawBoundaryFindings :: [ExpectedFinding]
trackerRawBoundaryFindings =
    [ ExpectedFinding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        trackerPath
        ( "locus=line:"
            <> showText lineNumber
            <> " reason=tracker candidate must have outer pipes and exactly seven cells"
        )
    | lineNumber <- [101 .. 132 :: Int]
    ]
        <> [ ExpectedFinding
                "PLAN-SEMANTIC-TRACKER-ROW-EXTRA"
                trackerPath
                "locus=canonical-tracker-table expected=96 observed=128 reason=raw tracker accounting found rows beyond the closed canonical phase inventory"
           ]
        <> expectedJoinFindings

phaseRowBoundaryCorpus, phaseRowOneOverCorpus :: [(FilePath, Text)]
phaseRowBoundaryCorpus =
    modifyPath (oraclePath phase0) (<> inertPipeRows 12) canonicalCorpus
phaseRowOneOverCorpus =
    modifyPath (oraclePath phase0) (<> inertPipeRows 13) canonicalCorpus

inertPipeRows :: Int -> Text
inertPipeRows count = Text.unlines (replicate count "| inert |")

semanticMismatch :: (Show value) => Int -> Text -> value -> value -> ExpectedFinding
semanticMismatch ordinal fieldName wanted observed =
    ExpectedFinding
        "PLAN-SEMANTIC-JOIN-MISMATCH"
        (oraclePath (oraclePhaseFor ordinal))
        ( "phase="
            <> renderOrdinal ordinal
            <> " field="
            <> fieldName
            <> " expected="
            <> showText wanted
            <> " actual="
            <> showText observed
        )

oraclePath :: OraclePhase -> FilePath
oraclePath row =
    "DEVELOPMENT_PLAN/phase_"
        <> Text.unpack (renderOrdinal (oracleOrdinal row))
        <> "_"
        <> Text.unpack (oracleCapability row)
        <> ".md"

categorySlug :: Text -> Text
categorySlug = Text.map replace . Text.toLower
  where
    replace character
        | character == ' ' || character == '/' = '-'
        | otherwise = character

renderOrdinal :: Int -> Text
renderOrdinal ordinal = Text.justifyRight 2 '0' (showText ordinal)

activeStatus, blockedStatus :: Text
activeStatus = "🔄 Active — NOT VALIDATED"
blockedStatus = "⏸️ Blocked — NOT VALIDATED"

planRoot, trackerPath :: FilePath
planRoot = "DEVELOPMENT_PLAN/"
trackerPath = "DEVELOPMENT_PLAN/README.md"

oracleLiteralProblems :: [String]
oracleLiteralProblems =
    [ "oracle phase literals must contain exactly 96 rows"
    | length oraclePhases /= 96
    ]
        <> [ "oracle phase ordinals must be exactly 0 through 95"
           | map oracleOrdinal oraclePhases /= [0 .. 95]
           ]
        <> [ "every canonical oracle phase lookup must resolve exactly once without the invalid sentinel"
           | Map.size oraclePhaseMap /= 96
                || map oraclePhaseFor [0 .. 95] /= oraclePhases
                || any ((== oracleOrdinal invalidOraclePhase) . oracleOrdinal) oraclePhases
           ]
        <> [ "oracle contract vectors must contain exactly one row for each ordinal 0 through 95"
           | length oraclePhaseVectors /= 96
                || map vectorOrdinal oraclePhaseVectors /= [0 .. 95]
                || Map.size oraclePhaseVectorMap /= 96
           ]
        <> [ "every canonical oracle vector lookup must resolve exactly once without the invalid sentinel"
           | map oraclePhaseVectorFor [0 .. 95] /= oraclePhaseVectors
                || any ((== vectorOrdinal invalidOraclePhaseVector) . vectorOrdinal) oraclePhaseVectors
           ]
        <> [ "the Phase-0 through Phase-36 bitmaps must be bound and every later bitmap must retain exactly eighteen ContractGap markers"
           | any ((/= "BBBBBBBBBBBBBBBBBB") . vectorSlotBitmap) (take 37 oraclePhaseVectors)
                || any ((/= "GGGGGGGGGGGGGGGGGG") . vectorSlotBitmap) (drop 37 oraclePhaseVectors)
           ]
        <> [ "the explicit oracle stage vector must retain 50 direct, one pb-child, one fake, and 44 hardware rows"
           | Map.fromListWith (+) [(vectorStage row, 1 :: Int) | row <- oraclePhaseVectors]
                /= Map.fromList
                    [ ("DirectSourceBoundHaskell", 50)
                    , ("PbChildUnderDirectHaskellSupervisor", 1)
                    , ("GatePassBoundHaskellFakeBoundary", 1)
                    , ("GatePassBoundHardware", 44)
                    ]
           ]
        <> [ "the explicit oracle critical-guard vector must retain only the five frozen guarded rows"
           | [ (vectorOrdinal row, vectorCriticalGuard row)
             | row <- oraclePhaseVectors
             , not (Text.null (vectorCriticalGuard row))
             ]
                /= [ (49, "phase49:requires=all-source-migration-queries-zero,all-owners-at-or-before-49-zero")
                   , (50, "phase50:requires=no-source-migration-ownership,phase49-gate-pass-source-snapshot,direct-haskell-supervisor-with-pb-child,identity-argv-exec-handoff,public-target-not-self-supervising")
                   , (51, "phase51:requires=hardware-free-execution,haskell-fake-boundaries-only")
                   , (52, "phase52:requires=first-hardware-validation")
                   , (56, "phase56:provider=DistributionRegistry2;image=registry:2;requires=distribution-registry2-only")
                   ]
           ]
        <> [ "oracle gate category literals must contain exactly 18 unique rows"
           | length gateCategories /= 18 || Set.size (Set.fromList gateCategories) /= 18
           ]
        <> [ "oracle gap total must be exactly 1,062"
           | sum (map (length . localGapCategoryNames . oracleOrdinal) oraclePhases) /= 1062
           ]
        <> [ "oracle bound total must be exactly 666"
           | 1728 - sum (map (length . localGapCategoryNames . oracleOrdinal) oraclePhases) /= 666
           ]
        <> [ "oracle resource-required phase set must contain exactly 53 unique ordinals"
           | length resourceRequiredOrdinals /= 53
                || Set.size (Set.fromList resourceRequiredOrdinals) /= 53
                || length
                    [ ()
                    | row <- oraclePhaseVectors
                    , vectorResourceProjection row == "not-required|ABSENT"
                    ]
                    /= 43
                || length unresolvedResourceOrdinals /= 47
                || any
                    (\row -> vectorResourceProjection row `notElem` ["required|GATE-READY", "required|UNRESOLVED", "not-required|ABSENT"])
                    oraclePhaseVectors
           ]
        <> [ "the frozen semantic and resource inventories must retain 769/104 observations and 1,063/330 findings"
           | length expectedSemanticObservations /= 769
                || length expectedSemanticFindings /= 1063
                || length expectedResourceObservations /= 104
                || length expectedResourceFindings /= 330
           ]
        <> [ "oracle reverse legacy map must contain exactly 26 unique IDs"
           | let identifiers = concat (Map.elems localLegacyReverseMap)
              in length identifiers /= 26 || Set.size (Set.fromList identifiers) /= 26
           ]
        <> [ "the inert-prose negative must replace a nonzero, independently counted sentence in every phase"
           | inertProseReplacementCount <= 0 || inertProseReplacementCount /= 96
           ]
        <> [ "the dense comment fixture must retain 50,000 pairs on one admitted physical line"
           | not denseCommentFixtureIsExact
           ]
        <> [ "entry-boundary fixtures must contain exactly 384 and 385 supplied entries"
           | length entryBoundaryCorpus /= 384 || length entryOneOverCorpus /= 385
           ]
        <> [ "path-boundary fixtures must contain exactly 256 and 257 characters"
           | length pathLengthBoundary /= 256 || length pathLengthOneOver /= 257
           ]
        <> [ "document-byte fixtures must contain exactly 524288 and 524289 UTF-8 bytes"
           | corpusUtf8Bytes [(documentBytePath, Text.replicate 524288 "x")] /= 524288
                || corpusUtf8Bytes [(documentBytePath, Text.replicate 524289 "x")] /= 524289
           ]
        <> [ "aggregate-byte fixtures must contain exactly 16777216 and 16777217 UTF-8 bytes"
           | corpusUtf8Bytes totalByteBoundaryCorpus /= 16777216
                || corpusUtf8Bytes totalByteOneOverCorpus /= 16777217
           ]
        <> [ "aggregate-byte fixtures must retain the frozen 129-entry corpus cardinality"
           | length totalByteBoundaryCorpus /= 129 || length totalByteOneOverCorpus /= 129
           ]
        <> [ "document-line fixtures must contain exactly 8192 and 8193 physical lines"
           | length (Text.lines (lineDocument 8192)) /= 8192
                || length (Text.lines (lineDocument 8193)) /= 8193
           ]
        <> [ "tracker-row fixtures must contain exactly 128 and 129 raw body candidates, including non-pipe rows"
           | 96 + length (Text.lines (rawTrackerCandidates 32)) /= 128
                || 96 + length (Text.lines (rawTrackerCandidates 33)) /= 129
                || any (Text.isPrefixOf "|" . Text.stripStart) (Text.lines (rawTrackerCandidates 33))
           ]
        <> [ "the repeated tracker-header fixture must saturate at 129 candidates within document bounds"
           | repeatedTrackerHeaderPairCount /= 66
                || min 129 (2 * (repeatedTrackerHeaderPairCount - 1)) /= 129
                || length (Text.lines repeatedTrackerHeaderDocument) /= 132
                || any (Text.null . Text.strip) (Text.lines repeatedTrackerHeaderDocument)
                || corpusUtf8Bytes [(trackerPath, repeatedTrackerHeaderDocument)] > 524288
                || length (Text.lines repeatedTrackerHeaderDocument) > 8192
           ]
        <> [ "raw-HTML termination fixtures must distinguish ASCII space/tab from non-ASCII whitespace"
           | spaceOnlyPhysicalLine /= "   "
                || tabOnlyPhysicalLine /= "\t"
                || nonAsciiWhitespaceLine /= "\x00a0"
                || Text.length nonAsciiWhitespaceLine /= 1
           ]
        <> [ "gate splice fixtures must retain exact contiguous 9/9 fragments and one canonical replacement anchor"
           | not gateSpliceFixturesAreExact
           ]
        <> [ "the tracker splice fixture must retain exact 48/48 fragments around one top-level fence"
           | not trackerSplitFixtureIsExact
           ]
        <> [ "list-contained table fixtures must retain one list marker and a two-space prefix on every structural row"
           | not listContainedFixturesAreExact
           ]
        <> [ "phase-row fixtures must contain exactly 32 and 33 visible pipe rows"
           | 20 + length (Text.lines (inertPipeRows 12)) /= 32
                || 20 + length (Text.lines (inertPipeRows 13)) /= 33
           ]

expectExactResult :: String -> Text -> [(Text, Text)] -> [ExpectedFinding] -> CheckResult -> [String]
expectExactResult label expectedName expectedObservations expectedFindings result =
    [ label <> ": the public pre-authority front door unexpectedly passed"
    | checkPassed result
    ]
        <> [ label
                <> ": check name mismatch; expected "
                <> show expectedName
                <> ", observed "
                <> show (checkName result)
           | checkName result /= expectedName
           ]
        <> [ label
                <> ": observation projection mismatch\nexpected: "
                <> show expectedObservations
                <> "\nactual:   "
                <> show actualObservations
           | actualObservations /= expectedObservations
           ]
        <> [ label
                <> ": finding projection mismatch\nexpected: "
                <> show expectedFindings
                <> "\nactual:   "
                <> show actualFindings
           | actualFindings /= expectedFindings
           ]
  where
    actualObservations = [(observationKey item, observationValue item) | item <- checkObservations result]
    actualFindings = map expectedFromFinding (checkFindings result)

expectExactJoinResult :: String -> [(Text, Text)] -> [ExpectedFinding] -> CheckResult -> [String]
expectExactJoinResult label =
    expectExactResult label "phase-semantic-join-diagnostic"

expectedFromFinding :: Finding -> ExpectedFinding
expectedFromFinding item =
    ExpectedFinding (findingCode item) (findingSubject item) (findingDetail item)

omitPath :: FilePath -> [(FilePath, Text)] -> [(FilePath, Text)]
omitPath target = filter ((/= target) . fst)

replaceInPath :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceInPath target before after = map replace
  where
    replace item@(path, contents)
        | path == target = (path, Text.replace before after contents)
        | otherwise = item

modifyPath :: FilePath -> (Text -> Text) -> [(FilePath, Text)] -> [(FilePath, Text)]
modifyPath target transform = map modify
  where
    modify item@(path, contents)
        | path == target = (path, transform contents)
        | otherwise = item

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems = do
    unless (null problems) (fail (unlines (name : problems)))
    putStrLn
        ( name
            <> ": diagnostic expectations met; no complete-gate or validation claim is implied."
        )

showText :: (Show value) => value -> Text
showText = Text.pack . show
