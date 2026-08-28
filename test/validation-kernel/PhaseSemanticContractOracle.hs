{-# LANGUAGE OverloadedStrings #-}

module PhaseSemanticContractOracle
  ( runPhaseSemanticContractOracle
  ) where

-- Component diagnostics only.  This oracle owns local fixture types and
-- independently frozen literals.  It imports no production contract type,
-- constructor, selector, category list, registry row, or renderer.

import Amoebius.Validation.PhaseSemanticContract
  ( phaseSemanticContractDiagnostic
  )
import Amoebius.Validation.PhaseSemanticJoin
  ( phaseSemanticJoinDiagnostic
  )
import Amoebius.Validation.ResourceProvisionContract
  ( resourceProvisionContractDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , checkPassed
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
            "the no-input resource registry has the exact 55-phase unresolved inventory"
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
            "one reset-status mutation is refused at the exact Phase-0 status locus"
            expectedJoinObservations
            (semanticMutationFindings [resetStatusMutationFinding])
            resetStatusMutationResult
        , expectExactJoinResult
            "a tab-indented phase status is code and cannot satisfy the reset-status projection"
            expectedJoinObservations
            (semanticMutationFindings [tabIndentedStatusFinding])
            tabIndentedStatusResult
        , expectExactJoinResult
            "a phase status hidden inside raw script HTML cannot satisfy the reset-status projection"
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
  [ phase 0 "documentation_suite" "Documentation, source policy, and validation trust root" "none" "none" "—"
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
  , phase 49 "self_referential_gates" "No-hardware DSL promotion barrier + self-referential gate suite" "none" "none" "2"
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
-- each row is a reviewable expectation that must move explicitly.
phaseVector :: Int -> Text -> Text -> Text -> Text -> OraclePhaseVector
phaseVector = OraclePhaseVector

oraclePhaseVectors :: [OraclePhaseVector]
oraclePhaseVectors =
  [ phaseVector 0 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 1 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 2 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 3 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 4 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 5 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 6 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 7 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 8 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 9 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 10 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 11 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 12 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 13 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 14 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 15 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 16 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 17 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 18 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 19 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 20 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 21 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 22 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 23 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 24 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 25 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 26 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 27 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 28 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 29 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 30 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 31 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 32 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 33 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 34 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 35 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 36 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 37 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 38 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 39 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 40 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 41 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 42 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 43 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 44 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 45 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 46 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 47 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 48 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "not-required|ABSENT" ""
  , phaseVector 49 "DirectSourceBoundHaskell" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase49:requires=all-source-migration-queries-zero,all-owners-at-or-before-49-zero"
  , phaseVector 50 "PbChildUnderDirectHaskellSupervisor" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase50:requires=no-source-migration-ownership,approved-phase49-source-snapshot,direct-haskell-supervisor-with-pb-child,identity-argv-exec-handoff,public-target-not-self-supervising"
  , phaseVector 51 "ApprovalBoundHaskellFakeBoundary" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase51:requires=hardware-free-execution,haskell-fake-boundaries-only"
  , phaseVector 52 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase52:requires=first-hardware-validation"
  , phaseVector 53 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 54 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 55 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 56 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" "phase56:provider=DistributionRegistry2;image=registry:2;requires=distribution-registry2-only"
  , phaseVector 57 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 58 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 59 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 60 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 61 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 62 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 63 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 64 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 65 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 66 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 67 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 68 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 69 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 70 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 71 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 72 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 73 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 74 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 75 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 76 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 77 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 78 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 79 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 80 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 81 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 82 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 83 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 84 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 85 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 86 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 87 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 88 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 89 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 90 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 91 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 92 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 93 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 94 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
  , phaseVector 95 "ApprovalBoundHardware" "GGGGGGGGGGGGGGGGGG" "required|UNRESOLVED" ""
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
  , "Human authority"
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
  , ("semantic.gap-count", "1728")
  , ("semantic.draft-count", "0")
  , ("semantic.reviewed-count", "0")
  , ("semantic.legacy-count", "25")
  ]
    <> [("semantic.phase", localPhaseProjection row) | row <- oraclePhases]

expectedSemanticFindings :: [ExpectedFinding]
expectedSemanticFindings =
  concatMap localSlotFindings oraclePhases
    <> [ ExpectedFinding
           "PLAN-SEMANTIC-DIAGNOSTIC-ONLY"
           planRoot
           "all 1,728 semantic slots are ContractGap; no reviewed value or reviewer custody exists, and these observations cannot promote a phase"
       ]

localSlotFindings :: OraclePhase -> [ExpectedFinding]
localSlotFindings row = zipWith findingFor gateCategories slotMarkers
 where
  ordinal = oracleOrdinal row
  slotMarkers = Text.unpack (vectorSlotBitmap (oraclePhaseVectorFor ordinal))
  findingFor category marker
    | marker == 'G' =
        ExpectedFinding
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
    | marker == 'D' =
        ExpectedFinding
          "PLAN-SEMANTIC-REVIEW-MISSING"
          (oraclePath row)
          ( "phase="
              <> renderOrdinal ordinal
              <> " category="
              <> category
              <> " draft=phase-"
              <> renderOrdinal ordinal
              <> "-"
              <> categorySlug category
              <> " review=missing"
          )
    | otherwise =
        ExpectedFinding
          "ORACLE-UNEXPECTED-SLOT-MARKER"
          (oraclePath row)
          ("phase=" <> renderOrdinal ordinal <> " marker=" <> Text.singleton marker)

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
    [ (0, ["LTD-SRC-000", "LTD-SRC-008", "LTD-VAL-001", "LTD-VAL-002", "LTD-VAL-003", "LTD-VAL-004"])
    , (1, ["LTD-SRC-007", "LTD-SRC-009"])
    , (2, ["LTD-META-001", "LTD-NAME-001"])
    , (25, ["LTD-SRC-002"])
    , (26, ["LTD-SRC-003"])
    , (27, ["LTD-DOC-001"])
    , (46, ["LTD-SRC-004"])
    , (47, ["LTD-SRC-001", "LTD-SRC-005", "LTD-SRC-006", "LTD-VAL-006"])
    , (49, ["LTD-VAL-005"])
    , (51, ["LTD-HOST-001", "LTD-HOST-002"])
    , (55, ["LTD-RUN-001"])
    , (56, ["LTD-IMG-001"])
    , (91, ["LTD-SEED-001"])
    , (93, ["LTD-SEED-002"])
    ]

expectedResourceObservations :: [(Text, Text)]
expectedResourceObservations =
  [ ("resource.phase-domain-count", "96")
  , ("resource.required-phase-count", "55")
  , ("resource.slot-count", "385")
  , ("resource.gap-count", "385")
  , ("resource.draft-count", "0")
  , ("resource.reviewed-count", "0")
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
  | ordinal <- resourceRequiredOrdinals
  , field <- resourceFields
  ]
    <> [ ExpectedFinding
           "PLAN-RESOURCE-DIAGNOSTIC-ONLY"
           planRoot
           "all 55 phase-specific resource-provision contracts are unresolved; no live mutation is authorized"
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
    "caller-supplied structural projections cannot populate, review, or promote a semantic contract slot"
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
  | ordinal `elem` resourceRequiredOrdinals =
      [ ""
      , "## Resource provision — UNRESOLVED"
      , "> **UNRESOLVED — blocks validation.** No live mutation is authorized. Fixture-only inventory."
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
        (oraclePath phase1)
        phase1SubjectGateRow
        "| `Subject` | blocks validation: independent subject missing. |"
        canonicalCorpus
    )
unresolvedSubstringMutationResult =
  phaseSemanticJoinDiagnostic
    ( replaceInPath
        (oraclePath phase1)
        phase1SubjectGateRow
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
    ( modifyPath trackerPath listItemRawScriptBlock canonicalCorpus )
listFencedTrackerResult =
  phaseSemanticJoinDiagnostic
    ( modifyPath trackerPath listItemFencedBlock canonicalCorpus )
alternatingFenceTrackerResult =
  phaseSemanticJoinDiagnostic
    ( modifyPath trackerPath (const (alternatingFenceBlock (trackerTable oraclePhases))) canonicalCorpus )
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
    ( modifyPath trackerPath (<> (nonAsciiWhitespaceLine <> "\n")) canonicalCorpus )
splitTrackerFenceResult =
  phaseSemanticJoinDiagnostic
    ( modifyPath trackerPath (const splitTrackerFenceDocument) canonicalCorpus )

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
    && all ((== 9) . length)
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

phase1SubjectGateRow, resourceBlockerLine :: Text
phase1SubjectGateRow =
  "| `Subject` | UNRESOLVED — blocks validation: independent subject missing. |"
resourceBlockerLine =
  "> **UNRESOLVED — blocks validation.** No live mutation is authorized. Fixture-only inventory."

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
resetStatusMutationFinding = semanticMismatch 0 "reset-status" activeStatus blockedStatus
tabIndentedStatusFinding :: ExpectedFinding
tabIndentedStatusFinding =
  semanticMismatch 0 "reset-status" activeStatus ("MISSING" :: Text)
summaryOrderMutationFinding =
  semanticMismatch
    34
    "summary-field-order"
    summaryFields
    ["Phase scope", "Lane", "Substrate", "Register", "Depends on", "Gate"]
unresolvedMarkerMutationFinding =
  semanticMismatch
    1
    "unresolved-shape"
    (localGapCategoryNames 1)
    (filter (/= "Subject") (localGapCategoryNames 1))
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
  , semanticMismatch
      1
      "unresolved-shape"
      (localGapCategoryNames 1)
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
               <> showText ("Resource provision — UNRESOLVED" :: Text)
               <> " actual="
               <> showText ("ABSENT" :: Text)
           )
       , ExpectedFinding
           "PLAN-RESOURCE-JOIN-MISMATCH"
           (oraclePath phase1)
           "phase=01 field=unresolved-blocker expected=True actual=False"
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
          "the structural join refuses before parsing when the supplied document corpus exceeds its reviewed entry bound"
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
          "the supplied path exceeds the reviewed character-length bound"
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
          "the supplied document exceeds the reviewed UTF-8 byte bound"
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
          "the structural join refuses before parsing when aggregate supplied UTF-8 bytes exceed the reviewed bound"
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
          "the supplied document exceeds the reviewed physical-line bound"
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
          "the tracker exceeds its reviewed pre-parse raw candidate-row bound"
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
          "the tracker exceeds its reviewed pre-parse raw candidate-row bound"
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
          "the phase-like document exceeds its reviewed pre-parse visible table-row bound"
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

reviewedTotalDocumentBytes, totalPaddingChunkBytes :: Integer
reviewedTotalDocumentBytes = 16777216
totalPaddingChunkBytes = 524287

totalByteBoundaryCorpus, totalByteOneOverCorpus :: [(FilePath, Text)]
totalByteBoundaryCorpus =
  canonicalCorpus
    <> totalBytePaddingDocuments
      (reviewedTotalDocumentBytes - corpusUtf8Bytes canonicalCorpus)
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

semanticMismatch :: Show value => Int -> Text -> value -> value -> ExpectedFinding
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
    <> [ "every explicit oracle slot bitmap must contain exactly eighteen ContractGap markers"
       | any ((/= "GGGGGGGGGGGGGGGGGG") . vectorSlotBitmap) oraclePhaseVectors
       ]
    <> [ "the explicit oracle stage vector must retain 50 direct, one pb-child, one fake, and 44 hardware rows"
       | Map.fromListWith (+) [(vectorStage row, 1 :: Int) | row <- oraclePhaseVectors]
           /= Map.fromList
             [ ("DirectSourceBoundHaskell", 50)
             , ("PbChildUnderDirectHaskellSupervisor", 1)
             , ("ApprovalBoundHaskellFakeBoundary", 1)
             , ("ApprovalBoundHardware", 44)
             ]
       ]
    <> [ "the explicit oracle critical-guard vector must retain only the five frozen guarded rows"
       | [ (vectorOrdinal row, vectorCriticalGuard row)
          | row <- oraclePhaseVectors
          , not (Text.null (vectorCriticalGuard row))
          ]
           /= [ (49, "phase49:requires=all-source-migration-queries-zero,all-owners-at-or-before-49-zero")
              , (50, "phase50:requires=no-source-migration-ownership,approved-phase49-source-snapshot,direct-haskell-supervisor-with-pb-child,identity-argv-exec-handoff,public-target-not-self-supervising")
              , (51, "phase51:requires=hardware-free-execution,haskell-fake-boundaries-only")
              , (52, "phase52:requires=first-hardware-validation")
              , (56, "phase56:provider=DistributionRegistry2;image=registry:2;requires=distribution-registry2-only")
              ]
       ]
    <> [ "oracle gate category literals must contain exactly 18 unique rows"
       | length gateCategories /= 18 || Set.size (Set.fromList gateCategories) /= 18
       ]
    <> [ "oracle gap total must be exactly 1,728"
       | sum (map (length . localGapCategoryNames . oracleOrdinal) oraclePhases) /= 1728
       ]
    <> [ "oracle draft total must remain exactly zero"
       | 1728 - sum (map (length . localGapCategoryNames . oracleOrdinal) oraclePhases) /= 0
       ]
    <> [ "oracle resource-required phase set must contain exactly 55 unique ordinals"
       | length resourceRequiredOrdinals /= 55
           || Set.size (Set.fromList resourceRequiredOrdinals) /= 55
           || length
             [ ()
             | row <- oraclePhaseVectors
             , vectorResourceProjection row == "not-required|ABSENT"
             ]
             /= 41
           || any
             (\row -> vectorResourceProjection row `notElem` ["required|UNRESOLVED", "not-required|ABSENT"])
             oraclePhaseVectors
       ]
    <> [ "the frozen clean semantic and resource inventories must retain 102 observations and 1,729/386 findings"
       | length expectedSemanticObservations /= 102
           || length expectedSemanticFindings /= 1729
           || length expectedResourceObservations /= 102
           || length expectedResourceFindings /= 386
       ]
    <> [ "oracle reverse legacy map must contain exactly 25 unique IDs"
       | let identifiers = concat (Map.elems localLegacyReverseMap)
        in length identifiers /= 25 || Set.size (Set.fromList identifiers) /= 25
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
        <> ": diagnostic expectations met; no review, qualification, validation, or promotion claim is implied."
    )

showText :: Show value => value -> Text
showText = Text.pack . show
