{-# LANGUAGE OverloadedStrings #-}

module PhaseContractInternalOracle
  ( phaseContractInternalExactCaseNames
  , phaseContractInternalSelectorMatrixRows
  , phaseContractInternalSelectorNames
  , runPhaseContractInternalExactCase
  , runPhaseContractInternalOracle
  , runPhaseContractInternalSelectorOracle
  , runPhaseContractInternalUnaffectedControl
  ) where

import Amoebius.Validation.PhaseContract.Internal (checkPhaseContracts, checkPhaseContractsForPhase)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import PhaseContractOracle (phaseContractValidCorpus)

phaseContractInternalSelectorMatrixRows :: [(String, [String], String)]
phaseContractInternalSelectorMatrixRows =
  [ ( "VALIDATION_PHASE_CONTRACT_SEMANTIC_OBSERVATION_COMPOSITION_BYPASS_MUTANT"
    , [ "semantic-observation-composition"
      , "phase-semantic-contract-route"
      , "resource-provision-contract-route"
      , "phase-semantic-join-route"
      ]
    , "sprint-inventory-finding"
    )
  , ( "VALIDATION_PHASE_CONTRACT_SEMANTIC_FINDING_COMPOSITION_BYPASS_MUTANT"
    , [ "semantic-finding-composition"
      , "phase-semantic-contract-route"
      , "resource-provision-contract-route"
      , "phase-semantic-join-route"
      ]
    , "phase-duplicate-render-order"
    )
  , ( "VALIDATION_PHASE_CONTRACT_SEMANTIC_CONTRACT_ROUTE_DROP_MUTANT"
    , [ "phase-semantic-contract-route"
      , "semantic-observation-composition"
      , "semantic-finding-composition"
      ]
    , "sprint-inventory-finding"
    )
  , ( "VALIDATION_PHASE_CONTRACT_RESOURCE_CONTRACT_ROUTE_DROP_MUTANT"
    , [ "resource-provision-contract-route"
      , "semantic-observation-composition"
      , "semantic-finding-composition"
      ]
    , "phase-duplicate-render-order"
    )
  , ( "VALIDATION_PHASE_CONTRACT_SEMANTIC_JOIN_ROUTE_DROP_MUTANT"
    , [ "phase-semantic-join-route"
      , "semantic-observation-composition"
      , "semantic-finding-composition"
      ]
    , "phase-duplicate-selection"
    )
  , ( "VALIDATION_PHASE_CONTRACT_SPRINT_INVENTORY_FINDING_BYPASS_MUTANT"
    , ["sprint-inventory-finding", "semantic-finding-composition"]
    , "semantic-observation-composition"
    )
  , ( "VALIDATION_PHASE_CONTRACT_PHASE_DUPLICATE_SELECTION_MUTANT"
    , ["phase-duplicate-selection"]
    , "semantic-observation-composition"
    )
  , ( "VALIDATION_PHASE_CONTRACT_PHASE_DUPLICATE_RENDER_ORDER_MUTANT"
    , ["phase-duplicate-render-order"]
    , "semantic-observation-composition"
    )
  ]

phaseContractInternalSelectorNames :: [String]
phaseContractInternalSelectorNames = [selector | (selector, _, _) <- phaseContractInternalSelectorMatrixRows]

phaseContractInternalExactCaseNames :: [String]
phaseContractInternalExactCaseNames =
  [ "semantic-observation-composition"
  , "semantic-finding-composition"
  , "phase-semantic-contract-route"
  , "resource-provision-contract-route"
  , "phase-semantic-join-route"
  , "sprint-inventory-finding"
  , "phase-duplicate-selection"
  , "phase-duplicate-render-order"
  ]

runPhaseContractInternalOracle :: IO ()
runPhaseContractInternalOracle =
  finishDiagnostics
    "PhaseContractInternalOracle"
    (selectorIntegrityProblems <> concatMap exactCaseProblems phaseContractInternalExactCaseNames <> recordedFrontierProblems)

runPhaseContractInternalExactCase :: String -> IO ()
runPhaseContractInternalExactCase exactCase =
  finishDiagnostics ("PhaseContractInternalOracle exact case " <> exactCase) (exactCaseProblems exactCase)

runPhaseContractInternalSelectorOracle :: String -> IO ()
runPhaseContractInternalSelectorOracle selector =
  case [impacts | (candidate, impacts, _) <- phaseContractInternalSelectorMatrixRows, candidate == selector] of
    [impacts] ->
      finishDiagnostics
        ("PhaseContractInternalOracle selector " <> selector)
        (concatMap exactCaseProblems impacts)
    matches -> fail ("PhaseContractInternalOracle selector lookup is not singular for " <> selector <> ": " <> show matches)

runPhaseContractInternalUnaffectedControl :: String -> IO ()
runPhaseContractInternalUnaffectedControl selector =
  case [control | (candidate, _, control) <- phaseContractInternalSelectorMatrixRows, candidate == selector] of
    [control] -> runPhaseContractInternalExactCase control
    matches -> fail ("PhaseContractInternalOracle control lookup is not singular for " <> selector <> ": " <> show matches)

selectorIntegrityProblems :: [String]
selectorIntegrityProblems =
  ["internal selector registry must contain exactly eight distinct selectors" | length phaseContractInternalSelectorNames /= 8 || not (allDistinct phaseContractInternalSelectorNames)]
    <> ["internal exact-case registry must contain exactly eight distinct cases" | length phaseContractInternalExactCaseNames /= 8 || not (allDistinct phaseContractInternalExactCaseNames)]
    <> [selector <> ": selector has no assigned impact" | (selector, impacts, _) <- phaseContractInternalSelectorMatrixRows, null impacts]
    <> [selector <> ": unknown impact " <> impact | (selector, impacts, _) <- phaseContractInternalSelectorMatrixRows, impact <- impacts, impact `notElem` phaseContractInternalExactCaseNames]
    <> [selector <> ": invalid unaffected control " <> control | (selector, impacts, control) <- phaseContractInternalSelectorMatrixRows, control `notElem` phaseContractInternalExactCaseNames || control `elem` impacts]
    <> ["selector primary impacts must biject over the eight exact cases" | sort [primary | (_, primary : _, _) <- phaseContractInternalSelectorMatrixRows] /= sort phaseContractInternalExactCaseNames]

exactCaseProblems :: String -> [String]
exactCaseProblems exactCase = case exactCase of
  "semantic-observation-composition" ->
    expectCount "full-mode observation carrier" 1067 (length (checkObservations cleanResult))
  "semantic-finding-composition" ->
    expectCount "full-mode finding carrier" 446 (length (checkFindings cleanResult))
  "phase-semantic-contract-route" ->
    expectObservation "semantic phase count" "semantic.phase-count" "96" cleanResult
      <> expectObservation "semantic slot count" "semantic.slot-count" "1728" cleanResult
      <> expectObservation "semantic gap count" "semantic.gap-count" "882" cleanResult
      <> expectObservation "semantic bound count" "semantic.bound-count" "846" cleanResult
      <> expectObservation "semantic target phase" "semantic.target-phase" "00" cleanResult
      <> expectObservation "semantic deferred gap count" "semantic.deferred-gap-count" "882" cleanResult
      <> expectObservation "semantic legacy count" "semantic.legacy-count" "26" cleanResult
      <> expectFindingCount "semantic gap findings" "PLAN-SEMANTIC-CONTRACT-GAP" 0 cleanResult
      <> expectFindingCount "semantic diagnostic refusal" "PLAN-SEMANTIC-DIAGNOSTIC-ONLY" 0 cleanResult
  "resource-provision-contract-route" ->
    expectObservation "resource phase domain" "resource.phase-domain-count" "96" cleanResult
      <> expectObservation "resource required phases" "resource.required-phase-count" "53" cleanResult
      <> expectObservation "resource slot count" "resource.slot-count" "371" cleanResult
      <> expectObservation "resource gap count" "resource.gap-count" "329" cleanResult
      <> expectObservation "resource draft count" "resource.draft-count" "0" cleanResult
      <> expectObservation "resource gate-ready count" "resource.gate-ready-count" "42" cleanResult
      <> expectFindingCount "resource gap findings" "PLAN-RESOURCE-CONTRACT-GAP" 0 cleanResult
      <> expectFindingCount "resource diagnostic refusal" "PLAN-RESOURCE-DIAGNOSTIC-ONLY" 0 cleanResult
  "phase-semantic-join-route" ->
    expectObservation "join supplied paths" "semantic.join.supplied-path-count" "97" cleanResult
      <> expectObservation "join parsed phases" "semantic.join.parsed-phase-count" "0" cleanResult
      <> expectObservation "join tracker candidates" "semantic.join.tracker-candidate-count" "1" cleanResult
      <> expectObservation "semantic join phase count" "semantic.join.phase-count" "0" cleanResult
      <> expectObservation "resource join phase count" "resource.join.phase-count" "0" cleanResult
      <> expectFindingCount "semantic path missing findings" "PLAN-SEMANTIC-PHASE-PATH-MISSING" 96 cleanResult
      <> expectFindingCount "semantic path unknown findings" "PLAN-SEMANTIC-PHASE-PATH-UNKNOWN" 96 cleanResult
      <> expectFindingCount "semantic Markdown refusal" "PLAN-SEMANTIC-MARKDOWN-DIAGNOSTIC-ONLY" 0 cleanResult
  "sprint-inventory-finding" ->
    -- The positive: every phase in the valid corpus numbers its sprints from
    -- one, so a contiguous inventory is clean. The negative differs in exactly
    -- one dimension — Phase 0's only sprint is numbered two instead of one —
    -- and must be refused at that phase's own path.
    expectFindingCount "contiguous sprint inventory" "PLAN-SPRINT-INVENTORY" 0 cleanResult
      <> expectExactFinding
        "a sprint inventory that does not begin at one is refused"
        "PLAN-SPRINT-INVENTORY"
        "DEVELOPMENT_PLAN/phase_00_synthetic_capability.md"
        "sprint identities must be contiguous from one; expected [Just 1], observed [Just 2]"
        nonContiguousResult
  "phase-duplicate-selection" ->
    expectNoFinding
      "lexically first duplicate is the selected phase contract"
      "PLAN-SPRINT-INVENTORY"
      duplicatePhasePath
      duplicateResult
  "phase-duplicate-render-order" ->
    expectExactFinding
      "duplicate paths render in lexical order"
      "PLAN-PHASE-DUPLICATE"
      duplicatePhasePath
      "phase ordinal occurs in more than one contract path: DEVELOPMENT_PLAN/phase_07_synthetic_capability.md, DEVELOPMENT_PLAN/phase_07_zz_duplicate.md"
      duplicateResult
  _ -> ["unknown internal exact case: " <> exactCase]

cleanResult :: CheckResult
cleanResult = checkPhaseContracts phaseContractValidCorpus

duplicateResult :: CheckResult
duplicateResult = checkPhaseContracts duplicateCorpus

recordedFrontierProblems :: [String]
recordedFrontierProblems =
  concat
    [ expectFindingCount "post-Phase-0 phase statuses" "PLAN-PHASE-STATUS" 0 postPhaseZeroResult
    , expectFindingCount "post-Phase-0 sprint statuses" "PLAN-SPRINT-STATUS" 0 postPhaseZeroResult
    , expectFindingCount "post-Phase-0 tracker statuses" "PLAN-TRACKER-STATUS" 0 postPhaseZeroResult
    , expectFindingCount "post-Phase-0 frontier recognition" "PLAN-STATUS-FRONTIER-RECORDED" 0 postPhaseZeroResult
    , expectObservation "post-Phase-0 completed-prefix semantic target" "semantic.target-phase" "00" postPhaseZeroResult
    , expectAtLeastOneFinding "phase/tracker disagreement" "PLAN-PHASE-STATUS" phaseDisagreementResult
    , expectAtLeastOneFinding "sprint/tracker disagreement" "PLAN-SPRINT-STATUS" phaseDisagreementResult
    , expectAtLeastOneFinding "two Active tracker rows" "PLAN-STATUS-FRONTIER-RECORDED" twoActiveResult
    , expectAtLeastOneFinding "Done-prefix hole" "PLAN-STATUS-FRONTIER-RECORDED" doneHoleResult
    , expectAtLeastOneFinding "premature no-Active tracker" "PLAN-STATUS-FRONTIER-RECORDED" prematureNoActiveResult
    , expectFindingCount "terminal frontier recognition" "PLAN-STATUS-FRONTIER-RECORDED" 0 allDoneResult
    , expectFindingCount "terminal phase statuses" "PLAN-PHASE-STATUS" 0 allDoneResult
    , expectFindingCount "terminal sprint statuses" "PLAN-SPRINT-STATUS" 0 allDoneResult
    , expectFindingCount "terminal tracker statuses" "PLAN-TRACKER-STATUS" 0 allDoneResult
    , expectObservation "terminal completed-prefix semantic target" "semantic.target-phase" "95" allDoneResult
    , expectFindingCount "terminal unresolved contracts remain fail-closed" "PLAN-SEMANTIC-CONTRACT-GAP" 882 allDoneResult
    , expectObservation "explicit Phase-1 gate semantic target" "semantic.target-phase" "01" phaseOneGateResult
    , expectFindingCount "explicit Phase-1 gate has no Phase-1 semantic gaps" "PLAN-SEMANTIC-CONTRACT-GAP" 0 phaseOneGateResult
    ]

postPhaseZeroResult :: CheckResult
postPhaseZeroResult = checkPhaseContracts postPhaseZeroCorpus

phaseDisagreementResult :: CheckResult
phaseDisagreementResult = checkPhaseContracts phaseDisagreementCorpus

twoActiveResult :: CheckResult
twoActiveResult = checkPhaseContracts (rewriteTrackerStatus 2 "⏸️ Blocked — NOT VALIDATED" "🔄 Active — NOT VALIDATED" postPhaseZeroCorpus)

doneHoleResult :: CheckResult
doneHoleResult = checkPhaseContracts (rewriteTrackerStatus 0 "✅ Done" "⏸️ Blocked — NOT VALIDATED" postPhaseZeroCorpus)

prematureNoActiveResult :: CheckResult
prematureNoActiveResult = checkPhaseContracts (rewriteTrackerStatus 1 "🔄 Active — NOT VALIDATED" "⏸️ Blocked — NOT VALIDATED" postPhaseZeroCorpus)

allDoneResult :: CheckResult
allDoneResult = checkPhaseContracts (fmap makeAllDone postPhaseZeroCorpus)

phaseOneGateResult :: CheckResult
phaseOneGateResult = checkPhaseContractsForPhase 1 postPhaseZeroCorpus

postPhaseZeroCorpus :: [(FilePath, Text)]
postPhaseZeroCorpus =
  rewriteTrackerStatus 1 "⏸️ Blocked — NOT VALIDATED" "🔄 Active — NOT VALIDATED"
    ( rewriteTrackerStatus 0 "🔄 Active — NOT VALIDATED" "✅ Done"
        ( fmap advancePhaseDocument phaseContractValidCorpus
        )
    )

phaseDisagreementCorpus :: [(FilePath, Text)]
phaseDisagreementCorpus =
  [ if path == phaseOneSyntheticPath
      then (path, phaseOneBeforeAdvance)
      else entry
  | entry@(path, _) <- postPhaseZeroCorpus
  ]
 where
  phaseOneBeforeAdvance = case lookup phaseOneSyntheticPath phaseContractValidCorpus of
    Just contents -> contents
    Nothing -> ""

advancePhaseDocument :: (FilePath, Text) -> (FilePath, Text)
advancePhaseDocument entry@(path, contents)
  | path == phaseZeroSyntheticPath =
      ( path
      , Text.replace "**Status**: Active — NOT VALIDATED" "**Status**: Done"
          ( Text.replace "## Sprint 0.1: Synthetic seam 🔄" "## Sprint 0.1: Synthetic seam ✅"
              (Text.replace "🔄 Active — NOT VALIDATED." "✅ Done." contents)
          )
      )
  | path == phaseOneSyntheticPath =
      ( path
      , Text.replace "**Status**: Blocked — NOT VALIDATED" "**Status**: Active — NOT VALIDATED"
          ( Text.replace "## Sprint 1.1: Synthetic seam ⏸️" "## Sprint 1.1: Synthetic seam 🔄"
              (Text.replace "⏸️ Blocked — NOT VALIDATED." "🔄 Active — NOT VALIDATED." contents)
          )
      )
  | otherwise = entry

rewriteTrackerStatus :: Int -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
rewriteTrackerStatus number before after = fmap rewriteEntry
 where
  rowPrefix = "| " <> Text.pack (show number) <> " | "
  rewriteEntry entry@(path, contents)
    | path == trackerSyntheticPath =
        (path, Text.unlines (fmap rewriteLine (Text.lines contents)))
    | otherwise = entry
  rewriteLine line
    | rowPrefix `Text.isPrefixOf` line = Text.replace ("| " <> before <> " |") ("| " <> after <> " |") line
    | otherwise = line

makeAllDone :: (FilePath, Text) -> (FilePath, Text)
makeAllDone (path, contents) = (path, Text.unlines (fmap rewriteLine (Text.lines contents)))
 where
  rewriteLine line
    | path == trackerSyntheticPath && "| " `Text.isPrefixOf` line =
        Text.replace "| 🔄 Active — NOT VALIDATED |" "| ✅ Done |"
          (Text.replace "| ⏸️ Blocked — NOT VALIDATED |" "| ✅ Done |" line)
    | line == "🔄 Active — NOT VALIDATED." || line == "⏸️ Blocked — NOT VALIDATED." = "✅ Done."
    | "## Sprint " `Text.isPrefixOf` line =
        Text.replace " 🔄" " ✅" (Text.replace " ⏸️" " ✅" line)
    | line == "**Status**: Active — NOT VALIDATED" || line == "**Status**: Blocked — NOT VALIDATED" = "**Status**: Done"
    | otherwise = line

phaseZeroSyntheticPath :: FilePath
phaseZeroSyntheticPath = "DEVELOPMENT_PLAN/phase_00_synthetic_capability.md"

phaseOneSyntheticPath :: FilePath
phaseOneSyntheticPath = "DEVELOPMENT_PLAN/phase_01_synthetic_capability.md"

trackerSyntheticPath :: FilePath
trackerSyntheticPath = "DEVELOPMENT_PLAN/README.md"

-- | The valid corpus with Phase 0's single sprint renumbered from one to two.
nonContiguousSprintCorpus :: [(FilePath, Text)]
nonContiguousSprintCorpus =
  [ ( path
    , if path == "DEVELOPMENT_PLAN/phase_00_synthetic_capability.md"
        then Text.replace "## Sprint 0.1:" "## Sprint 0.2:" contents
        else contents
    )
  | (path, contents) <- phaseContractValidCorpus
  ]

nonContiguousResult :: CheckResult
nonContiguousResult = checkPhaseContracts nonContiguousSprintCorpus

duplicateCorpus :: [(FilePath, Text)]
duplicateCorpus =
  phaseContractValidCorpus
    <> [ ( duplicatePhasePath
         , Text.replace
             "## Sprint 7.1: Synthetic seam ⏸️"
             "## Sprint 7.2: Synthetic seam ⏸️"
             contents
         )
       | (path, contents) <- phaseContractValidCorpus
       , path == "DEVELOPMENT_PLAN/phase_07_synthetic_capability.md"
       ]

duplicatePhasePath :: FilePath
duplicatePhasePath = "DEVELOPMENT_PLAN/phase_07_zz_duplicate.md"

expectObservation :: String -> Text -> Text -> CheckResult -> [String]
expectObservation label key expected result =
  case [observationValue item | item <- checkObservations result, observationKey item == key] of
    [actual] | actual == expected -> []
    actual -> [label <> ": expected exactly " <> show (key, expected) <> ", observed " <> show actual]

expectFindingCount :: String -> Text -> Int -> CheckResult -> [String]
expectFindingCount label code expected result =
  expectCount label expected (length [() | item <- checkFindings result, findingCode item == code])

expectAtLeastOneFinding :: String -> Text -> CheckResult -> [String]
expectAtLeastOneFinding label code result
  | any ((== code) . findingCode) (checkFindings result) = []
  | otherwise = [label <> ": expected at least one " <> Text.unpack code <> " finding"]

expectCount :: String -> Int -> Int -> [String]
expectCount label expected actual
  | actual == expected = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

expectExactFinding :: String -> Text -> FilePath -> Text -> CheckResult -> [String]
expectExactFinding label code subject detail result
  | any matches (checkFindings result) = []
  | otherwise = [label <> ": expected exact finding " <> show (code, subject, detail)]
 where
  matches item = findingCode item == code && findingSubject item == subject && findingDetail item == detail

expectNoFinding :: String -> Text -> FilePath -> CheckResult -> [String]
expectNoFinding label code subject result
  | all (not . matches) (checkFindings result) = []
  | otherwise = [label <> ": unexpectedly observed finding " <> show (code, subject)]
 where
  matches item = findingCode item == code && findingSubject item == subject

allDistinct :: Eq value => [value] -> Bool
allDistinct values = length values == length (nub values)

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics label problems =
  unless (null problems) (fail (label <> ":\n" <> unlines (map ("  - " <>) problems)))
