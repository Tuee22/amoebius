{-# LANGUAGE OverloadedStrings #-}

-- | The documentation-area oracle executable.
--
-- It depends on no @amoebius@ library. It reads the projection the plan-decisions suite
-- wrote and prints a ledger derived from the literals below: one row per expectation,
-- @green@ or @red@ with the observed value. The process exits non-zero when any row is
-- red. Nothing here regenerates an expectation from the subject.
module Main (main) where

import Control.Monad (unless)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  (input, findingsPath, negativesPath) <- case arguments of
    [path] -> do
      directory <- doesDirectoryExist path
      if directory
        then do
          findingsPresent <- doesFileExist (path <> "/findings.tsv")
          negativesPresent <- doesFileExist (path <> "/negatives.tsv")
          pure (path <> "/plan-decisions.tsv", if findingsPresent then Just (path <> "/findings.tsv") else Nothing, if negativesPresent then Just (path <> "/negatives.tsv") else Nothing)
        else pure (path, Nothing, Nothing)
    [path, findings] -> pure (path, Just findings, Nothing)
    [path, findings, negatives] -> pure (path, Just findings, Just negatives)
    _ -> pure (".build/runs/phase-00/plan-decisions.tsv", Nothing, Nothing)
  contents <- TextIO.readFile input
  findingRows <- maybe (pure Nothing) (fmap (Just . tsvRows) . TextIO.readFile) findingsPath
  negativeRows <- maybe (pure Nothing) (fmap (Just . tsvRows) . TextIO.readFile) negativesPath
  let ledger = judge (tsvRows contents) <> maybe [] judgeFindings findingRows <> maybe [] judgeNegatives negativeRows
  mapM_ (TextIO.putStrLn . renderRow) ledger
  unless (all rowGreen ledger) exitFailure

tsvRows :: Text -> [[Text]]
tsvRows contents = map (Text.splitOn "\t") (filter (not . Text.null) (Text.lines contents))

-- | The documentation checker's ledger over the governed corpus carries no finding.
judgeFindings :: [[Text]] -> [LedgerRow]
judgeFindings rows =
  [ expect "doc.findings" "0" (showText (length [() | ("finding" : _) <- rows]))
  , expect "doc.governed-count-observed" "present" (if any (\row -> take 2 row == ["observation", "governed-count"]) rows then "present" else "absent")
  ]

-- | Each rendered negative reports the finding named here, from these literals
-- and never from the renderer's own expectation column.
judgeNegatives :: [[Text]] -> [LedgerRow]
judgeNegatives rows =
  [ expect ("negative." <> name) code (if code `elem` observedCodes name then code else "absent:" <> Text.intercalate "," (observedCodes name))
  | (name, code) <- expectedNegatives
  ]
 where
  observedCodes name = case [codes | (rowName : _ : codes : _) <- rows, rowName == name] of
    (codes : _) -> Text.splitOn "," codes
    [] -> []

expectedNegatives :: [(Text, Text)]
expectedNegatives =
  [ ("broken-link", "DOC-LINK-TARGET")
  , ("stale-backlink", "DOC-BACKLINK-STALE")
  , ("missing-status-line", "PLAN-PHASE-STATUS")
  , ("non-frontier-status-vector", "PLAN-STATUS-FRONTIER-RECORDED")
  , ("unauthorised-frozen-edit", "DOC-FROZEN-BODY-CHANGED")
  , ("uncited-module-claim", "DOC-HONESTY-MOOD")
  , ("gate-spec-block-mismatch", "DOC-GATE-SPEC-MISMATCH")
  , ("decision-log-out-of-order", "DOC-DECISION-LOG-ORDER")
  ]

data LedgerRow = LedgerRow
  { rowName :: Text
  , rowGreen :: Bool
  , rowObserved :: Text
  }

renderRow :: LedgerRow -> Text
renderRow row =
  Text.intercalate "\t" [rowName row, if rowGreen row then "green" else "red", rowObserved row]

judge :: [[Text]] -> [LedgerRow]
judge rows =
  [ expect "phase.cardinality" (showText (length expectedPhases)) (showText (length phases))
  , expect "phase.table" (renderPairs expectedPhases) (renderPairs phases)
  , expect "phase.resource-required" (renderInts expectedResourceRequired) (renderInts resourceRequired)
  , expect "phase.paths" "exact" (if all pathExact phaseRows then "exact" else "drift")
  , expect "predecessor.50" "9" (lookupRow "predecessor" "50")
  , expect "predecessor.0" "none" (lookupRow "predecessor" "0")
  , expect "predecessor.1" "0" (lookupRow "predecessor" "1")
  , expect "successor.9" "50" (lookupRow "successor" "9")
  , expect "successor.95" "none" (lookupRow "successor" "95")
  , expect "role.DSL_BARRIER" "9" (lookupRow "role" "DSL_BARRIER")
  , expect "role.BOOTSTRAP_HANDOFF" "50" (lookupRow "role" "BOOTSTRAP_HANDOFF")
  , expect "role.HOST_ENSURE" "51" (lookupRow "role" "HOST_ENSURE")
  , expect "role.FIRST_HARDWARE" "52" (lookupRow "role" "FIRST_HARDWARE")
  , expect "role.REGISTRY_BOUNDARY" "56" (lookupRow "role" "REGISTRY_BOUNDARY")
  , expect "gap" "10..49" (Text.intercalate ".." (take 2 (drop 1 (firstRow "gap"))))
  , expect "integrity.problems" "0" (showText (length (rowsOf "integrity")))
  , expect "legacy.cardinality" (showText (length expectedLegacy)) (showText (length legacy))
  , expect "legacy.owners" (renderPairsText expectedLegacy) (renderPairsText legacy)
  , expect "decision.ids" (Text.intercalate "," expectedDecisions) (Text.intercalate "," decisions)
  , expect "frozen.paths" (Text.intercalate "," (sort expectedFrozen)) (Text.intercalate "," (sort frozenPaths))
  , expect "frozen.digests" "sha256-hex" (if all digestShaped frozenDigests then "sha256-hex" else "malformed")
  , expect "frozen.decisions" "known" (if all (`elem` expectedDecisions) frozenDecisions then "known" else "unknown")
  ]
 where
  rowsOf kind = [drop 1 row | row <- rows, take 1 row == [kind]]
  firstRow kind = case [row | row <- rows, take 1 row == [kind]] of
    (row : _) -> row
    [] -> []
  lookupRow kind key = case [value | (k : value : _) <- rowsOf kind, k == key] of
    [value] -> value
    _ -> "absent"
  phaseRows = rowsOf "phase"
  phases = [(readInt ordinal, capability) | (ordinal : capability : _) <- phaseRows]
  resourceRequired = [readInt ordinal | (ordinal : _ : _ : requirement : _) <- phaseRows, requirement == "required"]
  pathExact row = case row of
    (ordinal : capability : path : _) -> path == "DEVELOPMENT_PLAN/phase_" <> pad ordinal <> "_" <> capability <> ".md"
    _ -> False
  legacy = [(identifier, owner) | (identifier : owner : _) <- rowsOf "legacy"]
  decisions = [identifier | (identifier : _) <- rowsOf "decision"]
  frozenPaths = [path | (path : _) <- rowsOf "frozen"]
  frozenDigests = [digest | (_ : digest : _) <- rowsOf "frozen"]
  frozenDecisions = [identifier | (_ : _ : identifier : _) <- rowsOf "frozen"]

expect :: Text -> Text -> Text -> LedgerRow
expect name expected observed = LedgerRow name (expected == observed) observed

pad :: Text -> Text
pad ordinal = Text.justifyRight 2 '0' ordinal

readInt :: Text -> Int
readInt text = case reads (Text.unpack text) of
  [(value, "")] -> value
  _ -> -1

showText :: Int -> Text
showText = Text.pack . show

renderInts :: [Int] -> Text
renderInts = Text.intercalate "," . map showText . sort

renderPairs :: [(Int, Text)] -> Text
renderPairs pairs = Text.intercalate "," [showText ordinal <> "=" <> capability | (ordinal, capability) <- sort pairs]

renderPairsText :: [(Text, Text)] -> Text
renderPairsText pairs = Text.intercalate "," [key <> "=" <> value | (key, value) <- Map.toAscList (Map.fromList pairs)]

digestShaped :: Text -> Bool
digestShaped digest = Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest

-- The literal expectations. Authored from the plan documents, never from the subject.

expectedPhases :: [(Int, Text)]
expectedPhases =
  [ (0, "documentation_suite"), (1, "toolchain_spike"), (2, "repository_layout_conformance")
  , (3, "typed_spine"), (4, "witness_manifests_capacity_storage"), (5, "substrates_lanes_image_recipe")
  , (6, "extension_admission_attested_scope"), (7, "child_clusters_obligation_teardown")
  , (8, "ui_program_language_binding"), (9, "dsl_barrier")
  , (50, "host_assert_cli"), (51, "host_ensure_kernel"), (52, "linux_engine_bringup")
  , (53, "apple_engine_bringup"), (54, "windows_engine_bringup"), (55, "bootstrap_coordinator_kind")
  , (56, "base_image_registry"), (57, "complementary_arch_child"), (58, "object_reconciler")
  , (59, "capacity_scheduler"), (60, "retained_storage"), (61, "vault_pki"), (62, "platform_backbone")
  , (63, "platform_services_2"), (64, "keycloak_ingress"), (65, "live_dsl_deploy"), (66, "app_tenancy")
  , (67, "pulsar_client"), (68, "user_tenant_isolation_live"), (69, "content_store_workflow")
  , (70, "ui_projection_runtime"), (71, "release_lifecycle"), (72, "ui_program_release")
  , (73, "network_fabric_wireguard"), (74, "multicluster_spawn_georepl"), (75, "gateway_migration_drills")
  , (76, "provider_deploy_checkpoint"), (77, "provider_child_bringup"), (78, "provider_ebs_credential")
  , (79, "provider_dynamic_nodes"), (80, "determinism_jitcache"), (81, "ui_single_tenant_live")
  , (82, "ui_multi_tenant_live"), (83, "ui_rollout_reconnect"), (84, "ui_ha_multizone")
  , (85, "offline_replay_receipts"), (86, "offline_blobs_isolation"), (87, "offline_release_evolution")
  , (88, "offline_multizone_continuity"), (89, "apple_metal_host_daemon"), (90, "test_topology_live")
  , (91, "infernix_rederivation"), (92, "infernix_ui_rederivation"), (93, "jitml_rederivation")
  , (94, "jitml_ui_rederivation"), (95, "webapp_rederivation")
  ]

expectedResourceRequired :: [Int]
expectedResourceRequired = 1 : [50 .. 95]

expectedLegacy :: [(Text, Text)]
expectedLegacy =
  [ ("LTD-SRC-000", "repository_layout_conformance"), ("LTD-SRC-001", "repository_layout_conformance")
  , ("LTD-SRC-002", "typed_spine"), ("LTD-SRC-003", "typed_spine"), ("LTD-SRC-004", "ui_program_language_binding")
  , ("LTD-SRC-005", "repository_layout_conformance"), ("LTD-SRC-006", "repository_layout_conformance")
  , ("LTD-SRC-007", "toolchain_spike"), ("LTD-SRC-008", "repository_layout_conformance")
  , ("LTD-SRC-009", "toolchain_spike"), ("LTD-META-001", "repository_layout_conformance")
  , ("LTD-VAL-001", "documentation_suite"), ("LTD-VAL-002", "documentation_suite")
  , ("LTD-VAL-003", "documentation_suite"), ("LTD-VAL-004", "documentation_suite")
  , ("LTD-VAL-005", "typed_spine"), ("LTD-VAL-006", "documentation_suite")
  , ("LTD-VAL-007", "host_assert_cli"), ("LTD-VAL-008", "host_assert_cli"), ("LTD-DOC-001", "typed_spine")
  , ("LTD-NAME-001", "repository_layout_conformance"), ("LTD-HOST-001", "host_ensure_kernel")
  , ("LTD-HOST-002", "host_ensure_kernel"), ("LTD-IMG-001", "base_image_registry")
  , ("LTD-RUN-001", "bootstrap_coordinator_kind"), ("LTD-SEED-001", "infernix_rederivation")
  , ("LTD-SEED-002", "jitml_rederivation"), ("LTD-BOOT-001", "toolchain_spike")
  , ("LTD-KRN-001", "documentation_suite"), ("LTD-KRN-002", "documentation_suite"), ("LTD-KRN-003", "documentation_suite")
  , ("LTD-DSL-001", "typed_spine"), ("LTD-DSL-002", "typed_spine"), ("LTD-DSL-003", "witness_manifests_capacity_storage")
  , ("LTD-DSL-004", "typed_spine"), ("LTD-DSL-005", "extension_admission_attested_scope")
  , ("LTD-DSL-006", "ui_program_language_binding"), ("LTD-DSL-007", "extension_admission_attested_scope")
  , ("LTD-DSL-008", "extension_admission_attested_scope"), ("LTD-DSL-009", "typed_spine")
  , ("LTD-LIB-001", "dsl_barrier"), ("LTD-LIB-002", "later-phases-track"), ("LTD-UI-001", "ui_program_release")
  , ("LTD-HELPER-001", "host_assert_cli")
  ]

expectedDecisions :: [Text]
expectedDecisions = ["DL-0001", "DL-0002", "DL-0003", "DL-0004", "DL-0005", "DL-0006", "DL-0007", "DL-0008", "DL-0009", "DL-0010", "DL-0011", "DL-0012", "DL-0013", "DL-0014"]

-- | The frozen set of documentation_standards.md section 17: every governed document under
-- documents/ except the decision log, AGENTS.md, the three plan rulebooks, and the register.
expectedFrozen :: [Text]
expectedFrozen =
  [ "AGENTS.md"
  , "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
  , "DEVELOPMENT_PLAN/development_plan_phase_model.md"
  , "DEVELOPMENT_PLAN/development_plan_standards.md"
  , "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
  , "documents/README.md"
  , "documents/documentation_standards.md"
  , "documents/glossary.md"
  , "documents/reading_order.md"
  , "documents/engineering/README.md"
  , "documents/engineering/app_vs_deployment_doctrine.md"
  , "documents/engineering/apple_metal_headless_builds.md"
  , "documents/engineering/backup_recovery_doctrine.md"
  , "documents/engineering/behavioural_verification_doctrine.md"
  , "documents/engineering/bootstrap_sequence_doctrine.md"
  , "documents/engineering/browser_offline_runtime_doctrine.md"
  , "documents/engineering/capability_extension_doctrine.md"
  , "documents/engineering/chaos_failover_doctrine.md"
  , "documents/engineering/chaos_failover_second_axis.md"
  , "documents/engineering/chaos_failover_worked_examples.md"
  , "documents/engineering/cluster_lifecycle_doctrine.md"
  , "documents/engineering/cluster_topology_doctrine.md"
  , "documents/engineering/conformance_harness_doctrine.md"
  , "documents/engineering/consistency_pacelc_doctrine.md"
  , "documents/engineering/content_addressing_determinism.md"
  , "documents/engineering/content_addressing_doctrine.md"
  , "documents/engineering/daemon_topology_doctrine.md"
  , "documents/engineering/deterministic_simulation_doctrine.md"
  , "documents/engineering/diagram_conventions.md"
  , "documents/engineering/dsl_doctrine.md"
  , "documents/engineering/evidence_calculus_doctrine.md"
  , "documents/engineering/extension_conformance_doctrine.md"
  , "documents/engineering/extension_conformance_laws.md"
  , "documents/engineering/extension_conformance_security.md"
  , "documents/engineering/extension_conformance_transactions.md"
  , "documents/engineering/formal_model_doctrine.md"
  , "documents/engineering/gate_runner_doctrine.md"
  , "documents/engineering/gateway_migration_doctrine.md"
  , "documents/engineering/gateway_migration_model_doctrine.md"
  , "documents/engineering/generated_artifacts_doctrine.md"
  , "documents/engineering/host_cluster_comms_doctrine.md"
  , "documents/engineering/image_build_doctrine.md"
  , "documents/engineering/inforcespec_migration_doctrine.md"
  , "documents/engineering/jit_artifact_doctrine.md"
  , "documents/engineering/jit_budget_doctrine.md"
  , "documents/engineering/lift_and_compose_doctrine.md"
  , "documents/engineering/low_code_ui_runtime_doctrine.md"
  , "documents/engineering/low_code_ui_workflow_lifting.md"
  , "documents/engineering/manifest_generation_doctrine.md"
  , "documents/engineering/migration_doctrine.md"
  , "documents/engineering/monitoring_doctrine.md"
  , "documents/engineering/namespace_layout_doctrine.md"
  , "documents/engineering/network_fabric_doctrine.md"
  , "documents/engineering/platform_services_doctrine.md"
  , "documents/engineering/preflight_validation_doctrine.md"
  , "documents/engineering/pulsar_client_doctrine.md"
  , "documents/engineering/pulumi_ebs_credential_model.md"
  , "documents/engineering/pulumi_iac_doctrine.md"
  , "documents/engineering/readiness_ordering_doctrine.md"
  , "documents/engineering/release_lifecycle_doctrine.md"
  , "documents/engineering/repository_layout_doctrine.md"
  , "documents/engineering/resource_capacity_construction.md"
  , "documents/engineering/resource_capacity_doctrine.md"
  , "documents/engineering/resource_capacity_folds.md"
  , "documents/engineering/resource_capacity_schema.md"
  , "documents/engineering/resource_capacity_sources.md"
  , "documents/engineering/resource_capacity_storage.md"
  , "documents/engineering/resource_capacity_types.md"
  , "documents/engineering/service_capability_doctrine.md"
  , "documents/engineering/single_logical_data_plane_doctrine.md"
  , "documents/engineering/storage_lifecycle_doctrine.md"
  , "documents/engineering/substrate_doctrine.md"
  , "documents/engineering/substrate_node_inventory.md"
  , "documents/engineering/tenancy_doctrine.md"
  , "documents/engineering/test_derivation_analysis.md"
  , "documents/engineering/testing_doctrine.md"
  , "documents/engineering/testing_spoof_resistance.md"
  , "documents/engineering/ui_realtime_coordination_doctrine.md"
  , "documents/engineering/validation_frame_doctrine.md"
  , "documents/engineering/vault_pki_doctrine.md"
  , "documents/engineering/workflow_calculus_doctrine.md"
  , "documents/illegal_state/README.md"
  , "documents/illegal_state/illegal_state_capability_messaging.md"
  , "documents/illegal_state/illegal_state_capacity.md"
  , "documents/illegal_state/illegal_state_catalog.md"
  , "documents/illegal_state/illegal_state_lifecycle.md"
  , "documents/illegal_state/illegal_state_ml_asset.md"
  , "documents/illegal_state/illegal_state_multicluster.md"
  , "documents/illegal_state/illegal_state_security.md"
  , "documents/illegal_state/illegal_state_storage.md"
  , "documents/illegal_state/illegal_state_techniques.md"
  , "documents/illegal_state/illegal_state_tenancy.md"
  , "documents/illegal_state/illegal_state_topology.md"
  ]
