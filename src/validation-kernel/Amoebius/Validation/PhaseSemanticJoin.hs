{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseSemanticJoin
  ( phaseSemanticJoinDiagnostic
  ) where

import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.PhaseSemanticContract
  ( phaseStructuralProjectionDiagnostic
  )
import Amoebius.Validation.ResourceProvisionContract
  ( resourceProvisionProjectionDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.Char (isAlpha, isAlphaNum, isDigit)
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Text.Read (readMaybe)

-- This parser intentionally sees only structural joins.  Natural-language
-- Claim/Subject/Oracle/provider/module/count/Legacy prose is never returned to
-- the semantic registry and therefore cannot create a contract value.

data PhaseDocument = PhaseDocument
  { documentOrdinal :: Int
  , documentPath :: FilePath
  , documentTitle :: Text
  , documentSummaryFields :: [Text]
  , documentSubstrateToken :: Text
  , documentLaneToken :: Text
  , documentRegisterToken :: Text
  , documentPredecessorLink :: Text
  , documentFutureCommand :: Text
  , documentResetStatus :: Text
  , documentGateRows :: [Text]
  , documentUnresolvedRows :: [Text]
  , documentResourceHeading :: Text
  , documentResourceBlocker :: Bool
  }
  deriving (Eq, Show)

data TrackerRow = TrackerRow
  { trackerOrdinal :: Int
  , trackerTitle :: Text
  , trackerSubstrate :: Text
  , trackerLane :: Text
  , trackerRegister :: Text
  , trackerStatus :: Text
  , trackerContractPath :: Text
  }
  deriving (Eq, Show)

data Fence
  = Fence Char Int
  | OpaqueContainerFence
  deriving (Eq, Show)

data HtmlBlock
  = HtmlUntilBlank
  | HtmlUntilMarker Text
  | OpaqueContainerHtml
  deriving (Eq, Show)

data VisibleLine = VisibleLine
  { visibleLineNumber :: Int
  , visibleLineText :: Text
  }
  deriving (Eq, Show)

data TrackerCandidate
  = ValidTrackerCandidate TrackerRow
  | MalformedTrackerCandidate Int Text
  | OutOfRangeTrackerCandidate Int Int
  deriving (Eq, Show)

data TrackerParse = TrackerParse
  { parsedTrackerRows :: [TrackerRow]
  , trackerTableCount :: Int
  , trackerRawCandidateCount :: Int
  , trackerMalformedCandidates :: [(Int, Text)]
  , trackerOutOfRangeCandidates :: [(Int, Int)]
  }
  deriving (Eq, Show)

-- Fixed parser-work bounds. Every value is a literal so a source check
-- can see the admitted corpus without trusting derived repository statistics.
maximumSuppliedEntryCount :: Integer
maximumSuppliedEntryCount = 384

maximumSuppliedPathLength :: Integer
maximumSuppliedPathLength = 256

maximumDocumentBytes :: Integer
maximumDocumentBytes = 524288

maximumTotalDocumentBytes :: Integer
maximumTotalDocumentBytes = 16777216

maximumDocumentLines :: Integer
maximumDocumentLines = 8192

maximumTrackerRows :: Integer
maximumTrackerRows = 128

maximumPhaseRows :: Integer
maximumPhaseRows = 32

phaseSemanticJoinDiagnostic :: [(FilePath, Text)] -> CheckResult
phaseSemanticJoinDiagnostic supplied =
  case basicInputLimitFindings supplied of
    basicFindings@(_ : _) -> inputLimitRefusal supplied basicFindings
    [] -> case rowLimitFindings supplied of
      rowFindings@(_ : _) -> inputLimitRefusal supplied rowFindings
      [] -> phaseSemanticJoinWithinLimits supplied

inputLimitRefusal :: [(FilePath, Text)] -> [Finding] -> CheckResult
inputLimitRefusal supplied limitFindings =
  CheckResult
    { checkName = "phase-semantic-join-diagnostic"
    , checkObservations =
        [ observation "semantic.join.supplied-path-count" (showText (length supplied))
        , observation "semantic.join.parsed-phase-count" "0"
        , observation "semantic.join.tracker-candidate-count" (showText trackerCount)
        , observation "semantic.join.input-preflight" "refused-before-semantic-parsing"
        ]
    , checkFindings = limitFindings <> [markdownDiagnosticRefusal]
    }
 where
  trackerCount = length [() | (path, _) <- supplied, path == canonicalTrackerPath]

phaseSemanticJoinWithinLimits :: [(FilePath, Text)] -> CheckResult
phaseSemanticJoinWithinLimits supplied =
  CheckResult
    { checkName = "phase-semantic-join-diagnostic"
    , checkObservations =
        [ observation "semantic.join.supplied-path-count" (showText (length supplied))
        , observation "semantic.join.parsed-phase-count" (showText (length phaseDocuments))
        , observation "semantic.join.tracker-candidate-count" (showText (length trackerCandidates))
        ]
          <> checkObservations semanticDiagnostic
          <> checkObservations resourceDiagnostic
    , checkFindings =
        phasePathDiscoveryFindings supplied
          <> trackerCardinalityFindings
          <> trackerRowDiscoveryFindings trackerParse
          <> trackerInventoryFindings
          <> checkFindings semanticDiagnostic
          <> checkFindings resourceDiagnostic
          <> canonicalPhasePathAgreementFindings
          <> [markdownDiagnosticRefusal]
    }
 where
  phaseDocuments =
    mapMaybe
      (uncurry parsePhaseDocument)
      [entry | entry@(path, _) <- supplied, Map.member path canonicalPhasePathMap]
  trackerCandidates = [contents | (path, contents) <- supplied, path == canonicalTrackerPath]
  trackerParse = case trackerCandidates of
    [contents] -> parseTrackerDocument contents
    _ -> emptyTrackerParse
  trackerRows = parsedTrackerRows trackerParse
  trackerMap = Map.fromListWith (<>) [(trackerOrdinal row, [row]) | row <- trackerRows]
  phaseMap = Map.fromListWith (<>) [(documentOrdinal document, [document]) | document <- phaseDocuments]
  structuralRows = map (structuralProjection trackerMap) phaseDocuments
  resourceRows =
    [ (documentOrdinal document, documentResourceHeading document, documentResourceBlocker document)
    | document <- phaseDocuments
    ]
  semanticDiagnostic = phaseStructuralProjectionDiagnostic structuralRows
  resourceDiagnostic = resourceProvisionProjectionDiagnostic resourceRows
  trackerCardinalityFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-CARDINALITY"
        canonicalTrackerPath
        ("expected exactly one tracker document; observed " <> showText (length trackerCandidates))
    | length trackerCandidates /= 1
    ]
  trackerInventoryFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-ROW-CARDINALITY"
        canonicalTrackerPath
        ("expected exactly 96 tracker rows; observed " <> showText (length trackerRows))
    | length trackerCandidates == 1
    , length trackerRows /= 96
    ]
      <> [ finding
             "PLAN-SEMANTIC-TRACKER-DUPLICATE"
             canonicalTrackerPath
             ("phase=" <> showText ordinal <> " has " <> showText (length rows) <> " tracker rows")
         | (ordinal, rows) <- Map.toAscList trackerMap
         , length rows /= 1
         ]
      <> [ finding
             "PLAN-SEMANTIC-TRACKER-MISSING"
             (documentPath document)
             ("phase=" <> showText ordinal <> " has no tracker row")
         | (ordinal, documents) <- Map.toAscList phaseMap
         , Map.notMember ordinal trackerMap
         , document <- take 1 documents
         ]
      <> [ finding
             "PLAN-SEMANTIC-TRACKER-UNJOINED"
             canonicalTrackerPath
             ("phase=" <> showText ordinal <> " tracker row has no phase contract")
         | ordinal <- Map.keys trackerMap
         , Map.notMember ordinal phaseMap
         ]

markdownDiagnosticRefusal :: Finding
markdownDiagnosticRefusal =
  finding
    "PLAN-SEMANTIC-MARKDOWN-DIAGNOSTIC-ONLY"
    "DEVELOPMENT_PLAN/"
    "Markdown contributes only a narrow structural projection; its prose cannot satisfy a Haskell semantic slot"

basicInputLimitFindings :: [(FilePath, Text)] -> [Finding]
basicInputLimitFindings supplied =
  limitFinding
    "PLAN-SEMANTIC-INPUT-ENTRY-LIMIT"
    "DEVELOPMENT_PLAN/"
    "supplied-entry-count"
    maximumSuppliedEntryCount
    suppliedCount
    "the structural join refuses before parsing when the supplied document corpus exceeds its configured entry bound"
    <> concatMap perEntry supplied
    <> limitFinding
      "PLAN-SEMANTIC-INPUT-TOTAL-BYTE-LIMIT"
      "DEVELOPMENT_PLAN/"
      "supplied-total-utf8-bytes"
      maximumTotalDocumentBytes
      totalBytes
      "the structural join refuses before parsing when aggregate supplied UTF-8 bytes exceed the configured bound"
 where
  suppliedCount = toInteger (length supplied)
  totalBytes = sum [utf8ByteCount contents | (_, contents) <- supplied]
  perEntry (path, contents) =
    limitFinding
      "PLAN-SEMANTIC-INPUT-PATH-LENGTH-LIMIT"
      path
      "supplied-path-characters"
      maximumSuppliedPathLength
      (toInteger (length path))
      "the supplied path exceeds the configured character-length bound"
      <> limitFinding
        "PLAN-SEMANTIC-INPUT-DOCUMENT-BYTE-LIMIT"
        path
        "document-utf8-bytes"
        maximumDocumentBytes
        (utf8ByteCount contents)
        "the supplied document exceeds the configured UTF-8 byte bound"
      <> limitFinding
        "PLAN-SEMANTIC-INPUT-DOCUMENT-LINE-LIMIT"
        path
        "document-lines"
        maximumDocumentLines
        (toInteger (length (Text.lines contents)))
        "the supplied document exceeds the configured physical-line bound"

rowLimitFindings :: [(FilePath, Text)] -> [Finding]
rowLimitFindings supplied = concatMap perRelevantEntry supplied
 where
  perRelevantEntry (path, contents)
    | path == canonicalTrackerPath =
        limitFinding
          "PLAN-SEMANTIC-TRACKER-ROW-LIMIT"
          path
          "tracker-raw-candidate-rows"
          maximumTrackerRows
          (trackerRawCandidatePreflightCount contents)
          "the tracker exceeds its configured pre-parse raw candidate-row bound"
    | isPhaseLikePath path =
        limitFinding
          "PLAN-SEMANTIC-PHASE-ROW-LIMIT"
          path
          "phase-visible-pipe-rows"
          maximumPhaseRows
          (visiblePipeRowCount contents)
          "the phase-like document exceeds its configured pre-parse visible table-row bound"
    | otherwise = []

visiblePipeRowCount :: Text -> Integer
visiblePipeRowCount contents =
  toInteger
    ( length
        [ ()
        | rawLine <- outsideFences contents
        , Just line <- [structuralBlockLine rawLine]
        , "|" `Text.isPrefixOf` line
        ]
    )

trackerRawCandidatePreflightCount :: Text -> Integer
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_TRACKER_LIMIT_PIPE_ONLY_MUTANT)
trackerRawCandidatePreflightCount = visiblePipeRowCount
#else
trackerRawCandidatePreflightCount =
  toInteger
    . length
    . take (fromInteger maximumTrackerRows + 1)
    . concat
    . trackerTableBodies
    . outsideFencesNumbered
#endif

limitFinding :: Text -> FilePath -> Text -> Integer -> Integer -> Text -> [Finding]
limitFinding code subject locus limit observed reason =
  [ finding
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
  | observed > limit
  ]

utf8ByteCount :: Text -> Integer
utf8ByteCount = toInteger . ByteString.length . TextEncoding.encodeUtf8

phasePathDiscoveryFindings :: [(FilePath, Text)] -> [Finding]
phasePathDiscoveryFindings supplied =
  missingFindings
    <> duplicateFindings
    <> unknownPhasePathFindings phaseLikePaths
 where
  suppliedPathCounts = Map.fromListWith (+) [(path, 1 :: Int) | (path, _) <- supplied]
  phaseLikePaths = [path | (path, _) <- supplied, isPhaseLikePath path]
  missingFindings =
    [ finding
        "PLAN-SEMANTIC-PHASE-PATH-MISSING"
        path
        ("canonical phase path was not supplied; phase=" <> showText ordinal)
    | (path, ordinal) <- Map.toAscList canonicalPhasePathMap
    , Map.notMember path suppliedPathCounts
    ]
  duplicateFindings =
    [ finding
        "PLAN-SEMANTIC-PHASE-PATH-DUPLICATE"
        path
        ("phase-like supplied path occurs more than once; observed=" <> showText count)
    | (path, count) <- Map.toAscList suppliedPathCounts
    , isPhaseLikePath path
    , count > 1
    ]

unknownPhasePathFindings :: [FilePath] -> [Finding]
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_UNKNOWN_PATH_DISCOVERY_BYPASS_MUTANT)
unknownPhasePathFindings _ = Map.size canonicalPhasePathByOrdinal `seq` []
#else
unknownPhasePathFindings paths = concatMap classifyUnknown (Map.keys pathSet)
 where
  pathSet = Map.fromList [(path, ()) | path <- paths]
  classifyUnknown path
    | Map.member path canonicalPhasePathMap = []
    | otherwise = case phaseOrdinalFromPath path of
        Nothing ->
          [ finding
              "PLAN-SEMANTIC-PHASE-PATH-MALFORMED"
              path
              "phase-like path must be DEVELOPMENT_PLAN/phase_NN_<canonical-slug>.md with exactly two decimal ordinal digits"
          ]
        Just ordinal ->
          [ finding
              "PLAN-SEMANTIC-PHASE-PATH-UNKNOWN"
              path
              ( case Map.lookup ordinal canonicalPhasePathByOrdinal of
                  Nothing ->
                    "parsed phase ordinal lies outside the canonical 00..95 domain; ordinal="
                      <> showText ordinal
                  Just canonicalPath ->
                    "phase-like path does not equal the canonical path for ordinal="
                      <> showText ordinal
                      <> "; canonical="
                      <> Text.pack canonicalPath
              )
          ]
#endif

isPhaseLikePath :: FilePath -> Bool
isPhaseLikePath path =
  case Text.stripPrefix "DEVELOPMENT_PLAN/" (Text.pack path) of
    Just planRelative -> "phase" `Text.isPrefixOf` Text.toCaseFold planRelative
    Nothing -> False

canonicalTrackerPath :: FilePath
canonicalTrackerPath = "DEVELOPMENT_PLAN/README.md"

canonicalPhasePathMap :: Map FilePath Int
canonicalPhasePathMap =
  Map.fromList
    [ (path, ordinal)
    | path <- canonicalPhasePaths
    , Just ordinal <- [phaseOrdinalFromPath path]
    ]

canonicalPhasePathByOrdinal :: Map Int FilePath
canonicalPhasePathByOrdinal =
  Map.fromList
    [ (ordinal, path)
    | path <- canonicalPhasePaths
    , Just ordinal <- [phaseOrdinalFromPath path]
    ]

-- | The two independently authored phase-path tables must agree.
--
-- 'canonicalPhasePaths' below is written out by hand in this module, and the
-- identity table projects its own path for every phase. Nothing compared them:
-- they agreed only because both happened to be right, and a drift would surface
-- as one missing and one unknown finding per affected phase rather than as the
-- single fact that the two tables disagree. Keeping both authorships and
-- asserting their equality is what makes the pair a check instead of a
-- duplicate.
canonicalPhasePathAgreementFindings :: [Finding]
canonicalPhasePathAgreementFindings =
  [ finding
      "PLAN-SEMANTIC-PATH-TABLE-DISAGREEMENT"
      "DEVELOPMENT_PLAN/"
      ( "the join's authored phase-path table and the identity table's projected paths differ; join-only="
          <> showText [path | path <- canonicalPhasePaths, path `notElem` identityPaths]
          <> " identity-only="
          <> showText [path | path <- identityPaths, path `notElem` canonicalPhasePaths]
      )
  | canonicalPhasePaths /= identityPaths
  ]
 where
  identityPaths = map PhaseIdentity.phaseIdentityPath PhaseIdentity.allPhaseIdentities

canonicalPhasePaths :: [FilePath]
canonicalPhasePaths =
  [ "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
  , "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md"
  , "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md"
  , "DEVELOPMENT_PLAN/phase_03_artifact_calculus.md"
  , "DEVELOPMENT_PLAN/phase_04_budget_calculus.md"
  , "DEVELOPMENT_PLAN/phase_05_lift_calculus.md"
  , "DEVELOPMENT_PLAN/phase_06_workflow_calculus.md"
  , "DEVELOPMENT_PLAN/phase_07_evidence_calculus.md"
  , "DEVELOPMENT_PLAN/phase_08_scope_index.md"
  , "DEVELOPMENT_PLAN/phase_09_resource_index.md"
  , "DEVELOPMENT_PLAN/phase_10_calculus_composition.md"
  , "DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md"
  , "DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md"
  , "DEVELOPMENT_PLAN/phase_13_symbolic_checker.md"
  , "DEVELOPMENT_PLAN/phase_14_refinement_checker.md"
  , "DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md"
  , "DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md"
  , "DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md"
  , "DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md"
  , "DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md"
  , "DEVELOPMENT_PLAN/phase_20_extension_declaration.md"
  , "DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md"
  , "DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md"
  , "DEVELOPMENT_PLAN/phase_23_extension_security_laws.md"
  , "DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md"
  , "DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md"
  , "DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md"
  , "DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md"
  , "DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md"
  , "DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md"
  , "DEVELOPMENT_PLAN/phase_30_capability_bind.md"
  , "DEVELOPMENT_PLAN/phase_31_provision_seal.md"
  , "DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md"
  , "DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md"
  , "DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md"
  , "DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md"
  , "DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md"
  , "DEVELOPMENT_PLAN/phase_37_ui_program_schema.md"
  , "DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md"
  , "DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md"
  , "DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md"
  , "DEVELOPMENT_PLAN/phase_41_offline_language_plan.md"
  , "DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md"
  , "DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md"
  , "DEVELOPMENT_PLAN/phase_44_ui_local_composition.md"
  , "DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md"
  , "DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md"
  , "DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md"
  , "DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md"
  , "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md"
  , "DEVELOPMENT_PLAN/phase_50_host_assert_cli.md"
  , "DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md"
  , "DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md"
  , "DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md"
  , "DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md"
  , "DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md"
  , "DEVELOPMENT_PLAN/phase_56_base_image_registry.md"
  , "DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md"
  , "DEVELOPMENT_PLAN/phase_58_object_reconciler.md"
  , "DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md"
  , "DEVELOPMENT_PLAN/phase_60_retained_storage.md"
  , "DEVELOPMENT_PLAN/phase_61_vault_pki.md"
  , "DEVELOPMENT_PLAN/phase_62_platform_backbone.md"
  , "DEVELOPMENT_PLAN/phase_63_platform_services_2.md"
  , "DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md"
  , "DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md"
  , "DEVELOPMENT_PLAN/phase_66_app_tenancy.md"
  , "DEVELOPMENT_PLAN/phase_67_pulsar_client.md"
  , "DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md"
  , "DEVELOPMENT_PLAN/phase_69_content_store_workflow.md"
  , "DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md"
  , "DEVELOPMENT_PLAN/phase_71_release_lifecycle.md"
  , "DEVELOPMENT_PLAN/phase_72_ui_program_release.md"
  , "DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md"
  , "DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md"
  , "DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md"
  , "DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md"
  , "DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md"
  , "DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md"
  , "DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md"
  , "DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md"
  , "DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md"
  , "DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md"
  , "DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md"
  , "DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md"
  , "DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md"
  , "DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md"
  , "DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md"
  , "DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md"
  , "DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md"
  , "DEVELOPMENT_PLAN/phase_90_test_topology_live.md"
  , "DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md"
  , "DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md"
  , "DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md"
  , "DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md"
  , "DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md"
  ]

structuralProjection
  :: Map Int [TrackerRow]
  -> PhaseDocument
  -> ( Int
     , FilePath
     , Text
     , [Text]
     , Text
     , Text
     , Text
     , Text
     , Text
     , Text
     , [Text]
     , [Text]
     , Text
     )
structuralProjection trackerMap document =
  ( documentOrdinal document
  , documentPath document
  , documentTitle document
  , documentSummaryFields document
  , documentSubstrateToken document
  , documentLaneToken document
  , documentRegisterToken document
  , documentPredecessorLink document
  , documentFutureCommand document
  , documentResetStatus document
  , documentGateRows document
  , documentUnresolvedRows document
  , trackerProjection
  )
 where
  trackerProjection = case Map.lookup (documentOrdinal document) trackerMap of
    Just [row] -> renderTrackerProjection row
    Nothing -> "MISSING"
    Just rows -> "AMBIGUOUS:" <> showText (length rows)

parsePhaseDocument :: FilePath -> Text -> Maybe PhaseDocument
parsePhaseDocument path contents = do
  ordinal <- phaseOrdinalFromPath path
  let visible = outsideFences contents
      summary = uniqueSection "## Phase Summary" visible
      gate = uniqueSection "## Gate integrity" visible
      phaseStatus = uniqueSection "## Phase Status" visible
      summaryFields = mapMaybe summaryFieldLabel summary
      gateRows = parseGateTable gate
      resourceHeadings =
        [ Text.drop 3 line
        | line <- visible
        , "## Resource provision" `Text.isPrefixOf` line
        ]
      resourceHeading = case resourceHeadings of
        [] -> "ABSENT"
        [heading] -> heading
        headings -> "AMBIGUOUS:" <> showText headings
      resourceBody = case resourceHeadings of
        [heading] -> uniqueSection ("## " <> heading) visible
        _ -> []
      resourceBlocker =
        case
            [ Text.strip line
            | rawLine <- resourceBody
            , Just line <- [structuralBlockLine rawLine]
            , ">" `Text.isPrefixOf` Text.strip line
            ] of
          firstBlockquote : _ ->
            "> **UNRESOLVED — blocks validation.** No live mutation may begin."
              `Text.isPrefixOf` firstBlockquote
          [] -> False
  pure
    PhaseDocument
      { documentOrdinal = ordinal
      , documentPath = path
      , documentTitle = uniquePhaseTitle ordinal visible
      , documentSummaryFields = summaryFields
      , documentSubstrateToken = summaryToken "Substrate" summary
      , documentLaneToken = summaryToken "Lane" summary
      , documentRegisterToken = summaryToken "Register" summary
      , documentPredecessorLink = parsePredecessorLink ordinal (summaryValue "Depends on" summary)
      , documentFutureCommand = inlineCode (summaryValue "Gate" summary)
      , documentResetStatus = uniqueResetStatus phaseStatus
      , documentGateRows = map fst gateRows
      , documentUnresolvedRows = [name | (name, value) <- gateRows, unresolvedGateValue value]
      , documentResourceHeading = resourceHeading
      , documentResourceBlocker = resourceBlocker
      }

unresolvedGateValue :: Text -> Bool
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_UNRESOLVED_SUBSTRING_BYPASS_MUTANT)
unresolvedGateValue = Text.isInfixOf "UNRESOLVED"
#else
unresolvedGateValue = Text.isPrefixOf "UNRESOLVED — blocks validation:"
#endif

phaseOrdinalFromPath :: FilePath -> Maybe Int
phaseOrdinalFromPath path = do
  remainder <- Text.stripPrefix "DEVELOPMENT_PLAN/phase_" (Text.pack path)
  let (digits, suffix) = Text.splitAt 2 remainder
  if Text.length digits == 2
      && Text.all isDigit digits
      && "_" `Text.isPrefixOf` suffix
      && ".md" `Text.isSuffixOf` suffix
    then readMaybe (Text.unpack digits)
    else Nothing

uniquePhaseTitle :: Int -> [Text] -> Text
uniquePhaseTitle ordinal visible =
  uniqueValue
    [ Text.strip title
    | line <- visible
    , Just title <- [Text.stripPrefix ("# Phase " <> showText ordinal <> ":") line]
    , not (Text.null (Text.strip title))
    ]

summaryFieldNames :: [Text]
summaryFieldNames = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

summaryFieldLabel :: Text -> Maybe Text
summaryFieldLabel line =
  case
      [ name
      | name <- summaryFieldNames
      , ("**" <> name <> ":**") `Text.isPrefixOf` line
      ] of
    [name] -> Just name
    _ -> Nothing

summaryValue :: Text -> [Text] -> Text
summaryValue name visible =
  uniqueValue
    [ Text.strip value
    | line <- visible
    , Just value <- [Text.stripPrefix ("**" <> name <> ":**") line]
    ]

summaryToken :: Text -> [Text] -> Text
summaryToken name = firstCanonicalToken . summaryValue name

firstCanonicalToken :: Text -> Text
firstCanonicalToken value =
  Text.takeWhile isTokenCharacter (Text.dropWhile (not . isTokenCharacter) value)
 where
  isTokenCharacter character = isAlphaNum character || character `elem` ['-', '/', '—']

parsePredecessorLink :: Int -> Text -> Text
parsePredecessorLink 0 value
  | Text.strip value == "genesis" = "genesis"
parsePredecessorLink _ value =
  case Text.stripPrefix "[Phase " (Text.strip value) of
    Nothing -> "MALFORMED"
    Just rest ->
      let (digits, afterDigits) = Text.breakOn "](" rest
       in case Text.stripPrefix "](" afterDigits of
            Nothing -> "MALFORMED"
            Just afterOpen ->
              let (target, afterTarget) = Text.breakOn ")" afterOpen
               in if Text.null digits || not (Text.all isDigit digits) || not (predecessorCloseIsExact afterTarget)
                    then "MALFORMED"
                    else
                      "Phase "
                        <> digits
                        <> "|"
                        <> qualifyPlanPath target

predecessorCloseIsExact :: Text -> Bool
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_PREDECESSOR_TRAILING_BYPASS_MUTANT)
predecessorCloseIsExact = not . Text.null
#else
predecessorCloseIsExact = (== ")")
#endif

inlineCode :: Text -> Text
inlineCode value =
  case Text.breakOn "`" value of
    (_, remainder)
      | not (Text.null remainder) ->
          let afterOpen = Text.drop 1 remainder
              (code, afterCode) = Text.breakOn "`" afterOpen
           in if Text.null afterCode then "MALFORMED" else code
    _ -> "MALFORMED"

uniqueResetStatus :: [Text] -> Text
uniqueResetStatus visible =
  uniqueValue
    [ Text.dropWhileEnd (== '.') (Text.strip line)
    | rawLine <- visible
    , Just line <- [structuralBlockLine rawLine]
    , "🔄 Active —" `Text.isPrefixOf` Text.strip line
        || "⏸️ Blocked —" `Text.isPrefixOf` Text.strip line
    ]

parseGateRow :: Text -> Maybe (Text, Text)
parseGateRow rawLine = do
  cells <- gateCells rawLine
  case cells of
    [keyCell, value] -> do
      withoutOpen <- Text.stripPrefix "`" keyCell
      name <- Text.stripSuffix "`" withoutOpen
      if Text.null name || Text.null value
        then Nothing
        else Just (name, value)
    _ -> Nothing

-- Gate rows are meaningful only inside one physically contiguous Markdown
-- table.  In particular, removing an opaque block or ignoring an indented
-- code line must never stitch two table fragments into a semantic inventory.
parseGateTable :: [Text] -> [(Text, Text)]
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_GATE_TABLE_FRAME_BYPASS_MUTANT)
parseGateTable = mapMaybe parseGateRow
#else
parseGateTable body =
  case headerIndexes of
    [headerIndex] ->
      case drop (headerIndex + 1) body of
        delimiter : following
          | isGateDelimiter delimiter ->
              let (rows, remaining) = consumeRows following
               in if any (maybe False (const True) . parseGateRow) remaining
                    then []
                    else rows
        _ -> []
    _ -> []
 where
  headerIndexes =
    [ index
    | (index, line) <- zip [0 ..] body
    , isGateHeader line
    ]

  consumeRows [] = ([], [])
  consumeRows remaining@(line : following) =
    case parseGateRow line of
      Just row ->
        let (rows, afterRows) = consumeRows following
         in (row : rows, afterRows)
      Nothing -> ([], remaining)
#endif

isGateHeader :: Text -> Bool
isGateHeader line = gateCells line == Just ["Key", "Contract"]

isGateDelimiter :: Text -> Bool
isGateDelimiter line = gateCells line == Just ["---", "---"]

gateCells :: Text -> Maybe [Text]
gateCells rawLine = do
  line <- structuralBlockLine rawLine
  withoutOpen <- Text.stripPrefix "|" (Text.stripEnd line)
  withoutClose <- Text.stripSuffix "|" withoutOpen
  pure (map Text.strip (Text.splitOn "|" withoutClose))

emptyTrackerParse :: TrackerParse
emptyTrackerParse =
  TrackerParse
    { parsedTrackerRows = []
    , trackerTableCount = 0
    , trackerRawCandidateCount = 0
    , trackerMalformedCandidates = []
    , trackerOutOfRangeCandidates = []
    }

parseTrackerDocument :: Text -> TrackerParse
parseTrackerDocument contents =
  TrackerParse
    { parsedTrackerRows =
        [ row
        | ValidTrackerCandidate row <- classified
        ]
    , trackerTableCount = length tableCandidates
    , trackerRawCandidateCount = length rawCandidates
    , trackerMalformedCandidates =
        [ (lineNumber, reason)
        | (lineNumber, Left reason) <- tableCandidates
        ]
          <> [ (lineNumber, reason)
        | MalformedTrackerCandidate lineNumber reason <- classified
        ]
    , trackerOutOfRangeCandidates =
        [ (lineNumber, ordinal)
        | OutOfRangeTrackerCandidate lineNumber ordinal <- classified
        ]
    }
 where
  tableCandidates = trackerTableCandidates (outsideFencesNumbered contents)
  tableBodies = [body | (_, Right body) <- tableCandidates]
  rawCandidates = concat tableBodies
  classified = map parseTrackerCandidate rawCandidates

trackerRowDiscoveryFindings :: TrackerParse -> [Finding]
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_TRACKER_ROW_DISCOVERY_BYPASS_MUTANT)
trackerRowDiscoveryFindings parsed =
  trackerTableCount parsed
    `seq` trackerRawCandidateCount parsed
    `seq` trackerMalformedCandidates parsed
    `seq` trackerOutOfRangeCandidates parsed
    `seq` []
#else
trackerRowDiscoveryFindings parsed =
  tableCardinalityFindings
    <> malformedFindings
    <> outOfRangeFindings
    <> extraFindings
 where
  tableCardinalityFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-TABLE-CARDINALITY"
        canonicalTrackerPath
        ( "locus=canonical-tracker-table expected=1 observed="
            <> showText (trackerTableCount parsed)
            <> " reason=the canonical tracker header must identify exactly one raw row inventory"
        )
    | trackerTableCount parsed /= 1
    ]
  malformedFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-ROW-MALFORMED"
        canonicalTrackerPath
        ( "locus=line:"
            <> showText lineNumber
            <> " reason="
            <> reason
        )
    | (lineNumber, reason) <- trackerMalformedCandidates parsed
    ]
  outOfRangeFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-ROW-OUT-OF-RANGE"
        canonicalTrackerPath
        ( "locus=line:"
            <> showText lineNumber
            <> " ordinal="
            <> showText ordinal
            <> " reason=tracker ordinals are closed to the canonical 0..95 domain"
        )
    | (lineNumber, ordinal) <- trackerOutOfRangeCandidates parsed
    ]
  extraFindings =
    [ finding
        "PLAN-SEMANTIC-TRACKER-ROW-EXTRA"
        canonicalTrackerPath
        ( "locus=canonical-tracker-table expected=96 observed="
            <> showText (trackerRawCandidateCount parsed)
            <> " reason=raw tracker accounting found rows beyond the closed canonical phase inventory"
        )
    | trackerRawCandidateCount parsed > 96
    ]
#endif

trackerTableBodies :: [VisibleLine] -> [[VisibleLine]]
trackerTableBodies visible =
  [ body
  | (_, Right body) <- trackerTableCandidates visible
  ]

trackerTableCandidates :: [VisibleLine] -> [(Int, Either Text [VisibleLine])]
trackerTableCandidates = scan
 where
  scan [] = []
  scan (line : following)
    | isTrackerHeader (visibleLineText line) =
        let (candidate, remaining) = trackerBody following
         in (visibleLineNumber line, candidate) : scan remaining
    | otherwise = scan following

  trackerBody following =
    case following of
      delimiter : rest
        | isTrackerDelimiter (visibleLineText delimiter) ->
            let (body, afterBody) = span (not . blankVisibleLine) rest
             in (Right body, dropOneBlank afterBody)
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_TRACKER_DELIMITER_BYPASS_MUTANT)
      _ ->
        let (body, afterBody) = span (not . blankVisibleLine) following
         in (Right body, dropOneBlank afterBody)
#else
      _ ->
        ( Left "canonical tracker header must be followed immediately by a seven-cell Markdown delimiter row"
        , following
        )
#endif

  blankVisibleLine = physicalBlankLine . visibleLineText
  dropOneBlank [] = []
  dropOneBlank (_ : remaining) = remaining

isTrackerHeader :: Text -> Bool
isTrackerHeader line = case trackerCells line of
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_TRACKER_HEADER_WILDCARD_BYPASS_MUTANT)
  Just ["Phase", _, "Substrate", "Lane", "Register", "Status", _] -> True
#else
  Just ["Phase", "Name", "Substrate", "Lane", "Register", "Status", "Validation contract"] -> True
#endif
  _ -> False

isTrackerDelimiter :: Text -> Bool
isTrackerDelimiter line = case trackerCells line of
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_TRACKER_DELIMITER_SHAPE_BYPASS_MUTANT)
  Just cells -> length cells == 7 && all isDelimiterCell cells
  Nothing -> False
 where
  isDelimiterCell cell =
    let withoutLeft = Text.dropWhile (== ':') cell
        withoutRight = Text.dropWhileEnd (== ':') withoutLeft
     in Text.length withoutRight >= 3 && Text.all (== '-') withoutRight
#else
  Just cells -> length cells == 7 && all isDelimiterCell cells
  Nothing -> False
 where
  isDelimiterCell cell =
    let withoutLeft = case Text.stripPrefix ":" cell of
          Just remainder -> remainder
          Nothing -> cell
        withoutRight = case Text.stripSuffix ":" withoutLeft of
          Just remainder -> remainder
          Nothing -> withoutLeft
     in Text.length withoutRight >= 3 && Text.all (== '-') withoutRight
#endif

parseTrackerCandidate :: VisibleLine -> TrackerCandidate
parseTrackerCandidate visibleLine =
  case trackerCells (visibleLineText visibleLine) of
    Nothing -> malformed "tracker candidate must have outer pipes and exactly seven cells"
    Just cells -> case cells of
      [ordinalText, title, substrate, lane, validationRegister, phaseStatus, contractLink]
        | Text.null ordinalText -> malformed "tracker ordinal cell is empty"
        | otherwise -> case readMaybe (Text.unpack ordinalText) of
            Nothing -> malformed "tracker ordinal must contain a representable decimal integer"
            Just ordinal
              | ordinal < 0 || ordinal > 95 ->
                  OutOfRangeTrackerCandidate (visibleLineNumber visibleLine) ordinal
              | not (Text.all isDigit ordinalText) || ordinalText /= showText ordinal ->
                  malformed "tracker ordinal must use its canonical unsigned decimal spelling without leading zeroes"
              | any Text.null [title, substrate, lane, validationRegister, phaseStatus, contractLink] ->
                  malformed "tracker candidate contains an empty required cell"
              | markdownLinkTarget contractLink == "MALFORMED" ->
                  malformed "tracker contract cell must contain exactly one structurally closed Markdown link"
              | otherwise ->
                  ValidTrackerCandidate
                    TrackerRow
                      { trackerOrdinal = ordinal
                      , trackerTitle = title
                      , trackerSubstrate = stripWrappingCode substrate
                      , trackerLane = stripWrappingCode lane
                      , trackerRegister = stripWrappingCode validationRegister
                      , trackerStatus = phaseStatus
                      , trackerContractPath = qualifyPlanPath (markdownLinkTarget contractLink)
                      }
      _ -> malformed "tracker candidate must have outer pipes and exactly seven cells"
 where
  malformed reason = MalformedTrackerCandidate (visibleLineNumber visibleLine) reason

trackerCells :: Text -> Maybe [Text]
trackerCells rawLine = do
  line <- structuralBlockLine rawLine
  withoutOpen <- Text.stripPrefix "|" (Text.stripEnd line)
  withoutClose <- Text.stripSuffix "|" withoutOpen
  pure (map Text.strip (Text.splitOn "|" withoutClose))

structuralBlockLine :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_INDENTED_CODE_BYPASS_MUTANT)
structuralBlockLine = Just . Text.stripStart
#else
structuralBlockLine line =
  case Text.uncons line of
    Just (character, _)
      | character == ' ' || character == '\t' -> Nothing
    _ -> Just line
#endif

renderTrackerProjection :: TrackerRow -> Text
renderTrackerProjection row =
  Text.intercalate
    "|"
    [ trackerTitle row
    , trackerSubstrate row
    , trackerLane row
    , trackerRegister row
    , trackerStatus row
    , trackerContractPath row
    ]

markdownLinkTarget :: Text -> Text
markdownLinkTarget value =
  case Text.stripPrefix "[" value of
    Nothing -> "MALFORMED"
    Just afterLabelOpen ->
      let (label, afterOpen) = Text.breakOn "](" afterLabelOpen
       in case Text.stripPrefix "](" afterOpen of
            Nothing -> "MALFORMED"
            Just remainder ->
              let (target, afterTarget) = Text.breakOn ")" remainder
               in if Text.null label || Text.null target || afterTarget /= ")"
                    then "MALFORMED"
                    else target

qualifyPlanPath :: Text -> Text
qualifyPlanPath target
  | "DEVELOPMENT_PLAN/" `Text.isPrefixOf` target = target
  | target == "MALFORMED" = target
  | otherwise = "DEVELOPMENT_PLAN/" <> target

stripWrappingCode :: Text -> Text
stripWrappingCode value =
  case (Text.stripPrefix "`" value, Text.stripSuffix "`" value) of
    (Just withoutOpen, Just _) -> Text.dropEnd 1 withoutOpen
    _ -> value

uniqueSection :: Text -> [Text] -> [Text]
uniqueSection heading visible = case sectionStarts of
  [start] ->
    takeWhile (not . isH2) (drop (start + 1) visible)
  _ -> []
 where
  sectionStarts = [index | (index, line) <- zip [0 ..] visible, line == heading]

isH2 :: Text -> Bool
isH2 line =
  "## " `Text.isPrefixOf` line && not ("### " `Text.isPrefixOf` line)

outsideFences :: Text -> [Text]
outsideFences = map visibleLineText . outsideFencesNumbered

outsideFencesNumbered :: Text -> [VisibleLine]
outsideFencesNumbered contents =
  reverse visibleReversed
 where
  (_, _, _, visibleReversed) =
    foldl'
      step
      (Nothing, False, Nothing, [])
      (zip [1 ..] (Text.lines contents))
  step (Just OpaqueContainerFence, _, _, visible) _ =
    (Just OpaqueContainerFence, False, Nothing, visible)
  step (Just activeFence, _, _, visible) (_, rawLine)
    | isFenceCloser activeFence rawLine = (Nothing, False, Nothing, visible)
    | otherwise = (Just activeFence, False, Nothing, visible)
  step (Nothing, _, Just OpaqueContainerHtml, visible) _ =
    (Nothing, False, Just OpaqueContainerHtml, visible)
  step (Nothing, _, Just HtmlUntilBlank, visible) (lineNumber, rawLine)
    | physicalBlankLine rawLine =
        (Nothing, False, Nothing, VisibleLine lineNumber "" : visible)
    | otherwise = (Nothing, False, Just HtmlUntilBlank, visible)
  step (Nothing, _, Just block@(HtmlUntilMarker marker), visible) (lineNumber, rawLine)
    | marker `Text.isInfixOf` Text.toCaseFold rawLine =
        (Nothing, False, Nothing, VisibleLine lineNumber "" : visible)
    | otherwise = (Nothing, False, Just block, visible)
  step (Nothing, commentActive, Nothing, visible) (lineNumber, rawLine) =
    let (nextCommentActive, maskedLine) = maskHtmlComments commentActive rawLine
        maskedSyntaxLine = containerSyntaxLine maskedLine
     in case fenceOpener maskedLine of
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_OPAQUE_BOUNDARY_BYPASS_MUTANT)
          Just openedFence -> (Just openedFence, False, Nothing, visible)
#else
          Just openedFence ->
            ( Just openedFence
            , False
            , Nothing
            , VisibleLine lineNumber "" : visible
            )
#endif
          Nothing -> case fenceOpener maskedSyntaxLine of
            Just _ -> (Just OpaqueContainerFence, False, Nothing, visible)
            Nothing -> case htmlBlockOpener maskedLine of
              Just block
                | htmlBlockClosesOnLine block maskedLine ->
                    (Nothing, False, Nothing, VisibleLine lineNumber "" : visible)
                | otherwise -> (Nothing, False, Just block, visible)
              Nothing -> case htmlBlockOpener maskedSyntaxLine of
                Just _ -> (Nothing, False, Just OpaqueContainerHtml, visible)
                Nothing ->
                  ( Nothing
                  , nextCommentActive
                  , Nothing
                  , VisibleLine lineNumber maskedLine : visible
                  )

htmlBlockOpener :: Text -> Maybe HtmlBlock
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_RAW_HTML_BYPASS_MUTANT)
htmlBlockOpener _ = Nothing
#else
htmlBlockOpener line = do
  afterIndent <- dropFenceIndent line
  let folded = Text.toCaseFold afterIndent
  case [name | name <- ["script", "pre", "style", "textarea"], name `htmlTagStarts` folded] of
    tagName : _ -> Just (HtmlUntilMarker ("</" <> tagName <> ">"))
    [] ->
      if "<?" `Text.isPrefixOf` folded
        then Just (HtmlUntilMarker "?>")
        else
          if "<![cdata[" `Text.isPrefixOf` folded
            then Just (HtmlUntilMarker "]]>")
            else
              if "<!" `Text.isPrefixOf` folded
                then Just (HtmlUntilMarker ">")
                else
                  if isBlockHtmlTag folded || isCompleteHtmlTagLine folded
                    then Just HtmlUntilBlank
                    else Nothing
#endif

htmlBlockClosesOnLine :: HtmlBlock -> Text -> Bool
htmlBlockClosesOnLine HtmlUntilBlank _ = False
htmlBlockClosesOnLine (HtmlUntilMarker marker) line =
  marker `Text.isInfixOf` Text.toCaseFold line
htmlBlockClosesOnLine OpaqueContainerHtml _ = False

htmlTagStarts :: Text -> Text -> Bool
htmlTagStarts name line =
  case Text.stripPrefix ("<" <> name) line of
    Just remainder ->
      case Text.uncons remainder of
        Nothing -> True
        Just (character, _) -> character == ' ' || character == '\t' || character == '>'
    Nothing -> False

isBlockHtmlTag :: Text -> Bool
isBlockHtmlTag line =
  case htmlTagName line of
    Just name -> name `elem` blockHtmlTagNames
    Nothing -> False

blockHtmlTagNames :: [Text]
blockHtmlTagNames =
  [ "address", "article", "aside", "base", "basefont", "blockquote", "body"
  , "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir"
  , "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form"
  , "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head"
  , "header", "hr", "html", "iframe", "legend", "li", "link", "main", "menu"
  , "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param"
  , "search", "section", "summary", "table", "tbody", "td", "tfoot", "th"
  , "thead", "title", "tr", "track", "ul"
  ]

htmlTagName :: Text -> Maybe Text
htmlTagName line = do
  afterOpen <- Text.stripPrefix "<" line
  let afterSlash = case Text.stripPrefix "/" afterOpen of
        Just value -> value
        Nothing -> afterOpen
      (name, remainder) = Text.span (\character -> isAlphaNum character || character == '-') afterSlash
  case Text.uncons name of
    Just (first, _)
      | isAlpha first
          && case Text.uncons remainder of
            Nothing -> True
            Just (character, _) ->
              character == ' ' || character == '\t' || character == '>' || character == '/' ->
          Just name
    _ -> Nothing

isCompleteHtmlTagLine :: Text -> Bool
isCompleteHtmlTagLine line =
  case htmlTagName line of
    Nothing -> False
    Just _ ->
      let (throughClose, tailAfterClose) = Text.breakOnEnd ">" line
       in not (Text.null throughClose)
            && Text.all (\character -> character == ' ' || character == '\t') tailAfterClose

-- CommonMark recognizes fenced-code and raw-HTML blocks after blockquote and
-- list container markers.  This normalizer is used only to discover those
-- block boundaries; the visible line retains its original container markers
-- so a blockquoted/list-indented structural row is never promoted to a row.
containerSyntaxLine :: Text -> Text
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_CONTAINER_PREFIX_BYPASS_MUTANT)
containerSyntaxLine = id
#else
containerSyntaxLine = stripContainers . dropContainerIndent
 where
  stripContainers line =
    case stripOneContainer line of
      Nothing -> line
      Just remainder -> stripContainers (dropContainerIndent remainder)

  stripOneContainer line =
    case Text.stripPrefix ">" line of
      Just remainder -> Just (dropMarkerWhitespace remainder)
      Nothing -> stripListMarker line

  stripListMarker line =
    case Text.uncons line of
      Just (marker, remainder)
        | marker `elem` ['-', '+', '*'] ->
            whitespaceDelimited remainder
      _ ->
        let (digits, remainder) = Text.span isDigit line
         in if Text.null digits || Text.length digits > 9
              then Nothing
              else case Text.uncons remainder of
                Just (marker, afterMarker)
                  | marker == '.' || marker == ')' -> whitespaceDelimited afterMarker
                _ -> Nothing

  whitespaceDelimited remainder =
    case Text.uncons remainder of
      Just (character, _)
        | character == ' ' || character == '\t' ->
            Just (dropMarkerWhitespace remainder)
      _ -> Nothing

  dropMarkerWhitespace = Text.dropWhile (\character -> character == ' ' || character == '\t')

  dropContainerIndent line =
    let (indent, remainder) = Text.span (== ' ') line
     in if Text.length indent <= 3 then remainder else line
#endif

fenceOpener :: Text -> Maybe Fence
fenceOpener line = do
  afterIndent <- dropFenceIndent line
  (marker, width, trailing) <- fenceRun afterIndent
  if width >= 3 && (marker /= '`' || not (Text.any (== '`') trailing))
    then Just (Fence marker width)
    else Nothing

isFenceCloser :: Fence -> Text -> Bool
isFenceCloser (Fence openedMarker openedWidth) line =
  case dropFenceIndent line >>= fenceRun of
    Just (candidateMarker, candidateWidth, trailing) ->
      candidateMarker == openedMarker
        && candidateWidth >= openedWidth
        && fenceClosingTailIsWhitespace trailing
    Nothing -> False
isFenceCloser OpaqueContainerFence _ = False

fenceClosingTailIsWhitespace :: Text -> Bool
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_PSEUDO_FENCE_CLOSE_BYPASS_MUTANT)
fenceClosingTailIsWhitespace _ = True
#else
fenceClosingTailIsWhitespace = Text.all isClosingWhitespace
 where
  isClosingWhitespace character = character == ' ' || character == '\t'
#endif

dropFenceIndent :: Text -> Maybe Text
dropFenceIndent line =
  let (indent, remainder) = Text.span (== ' ') line
   in if Text.length indent <= 3 then Just remainder else Nothing

fenceRun :: Text -> Maybe (Char, Int, Text)
fenceRun line = case Text.uncons line of
  Just (marker, remainder)
    | marker == '`' || marker == '~' ->
        let sameMarkers = Text.takeWhile (== marker) remainder
            width = 1 + Text.length sameMarkers
         in Just (marker, width, Text.drop (width - 1) remainder)
  _ -> Nothing

-- A comment is replaced by a non-whitespace sentinel instead of deleted.
-- Consequently two tokens on either side cannot be joined, and a fence marker
-- hidden wholly or partly in a comment cannot change fenced visibility.
maskHtmlComments :: Bool -> Text -> (Bool, Text)
maskHtmlComments initiallyActive input =
  go initiallyActive input initialChunks
 where
  initialChunks = [commentSentinel | initiallyActive]

  go True remaining chunks =
    let (_, closing) = Text.breakOn "-->" remaining
     in if Text.null closing
          then finish True chunks
          else go False (Text.drop 3 closing) chunks
  go False remaining chunks =
    case Text.breakOn "<!--" remaining of
      (before, remainder)
        | Text.null remainder -> finish False (before : chunks)
        | otherwise ->
            go
              True
              (Text.drop 4 remainder)
              (commentSentinel : before : chunks)

  finish active chunks = (active, Text.concat (reverse chunks))

commentSentinel :: Text
#if defined(VALIDATION_PHASE_SEMANTIC_JOIN_COMMENT_SPLICE_BYPASS_MUTANT)
commentSentinel = ""
#else
commentSentinel = "!"
#endif

physicalBlankLine :: Text -> Bool
physicalBlankLine = Text.all (\character -> character == ' ' || character == '\t')

uniqueValue :: [Text] -> Text
uniqueValue values = case values of
  [value] -> value
  [] -> "MISSING"
  _ -> "AMBIGUOUS:" <> showText values

showText :: Show value => value -> Text
showText = Text.pack . show
