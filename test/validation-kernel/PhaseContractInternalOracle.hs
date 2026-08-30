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

import Amoebius.Validation.PhaseContract.Internal (checkPhaseContracts)
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
    (selectorIntegrityProblems <> concatMap exactCaseProblems phaseContractInternalExactCaseNames)

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
    expectCount "full-mode observation carrier" 219 (length (checkObservations cleanResult))
  "semantic-finding-composition" ->
    expectCount "full-mode finding carrier" 947 (length (checkFindings cleanResult))
  "phase-semantic-contract-route" ->
    expectObservation "semantic phase count" "semantic.phase-count" "96" cleanResult
      <> expectObservation "semantic slot count" "semantic.slot-count" "1728" cleanResult
      <> expectObservation "semantic gap count" "semantic.gap-count" "1728" cleanResult
      <> expectObservation "semantic bound count" "semantic.bound-count" "0" cleanResult
      <> expectObservation "semantic target phase" "semantic.target-phase" "00" cleanResult
      <> expectObservation "semantic deferred gap count" "semantic.deferred-gap-count" "1710" cleanResult
      <> expectObservation "semantic legacy count" "semantic.legacy-count" "26" cleanResult
      <> expectFindingCount "semantic gap findings" "PLAN-SEMANTIC-CONTRACT-GAP" 18 cleanResult
      <> expectFindingCount "semantic diagnostic refusal" "PLAN-SEMANTIC-DIAGNOSTIC-ONLY" 0 cleanResult
  "resource-provision-contract-route" ->
    expectObservation "resource phase domain" "resource.phase-domain-count" "96" cleanResult
      <> expectObservation "resource required phases" "resource.required-phase-count" "55" cleanResult
      <> expectObservation "resource slot count" "resource.slot-count" "385" cleanResult
      <> expectObservation "resource gap count" "resource.gap-count" "385" cleanResult
      <> expectObservation "resource draft count" "resource.draft-count" "0" cleanResult
      <> expectObservation "resource gate-ready count" "resource.gate-ready-count" "0" cleanResult
      <> expectFindingCount "resource gap findings" "PLAN-RESOURCE-CONTRACT-GAP" 385 cleanResult
      <> expectFindingCount "resource diagnostic refusal" "PLAN-RESOURCE-DIAGNOSTIC-ONLY" 1 cleanResult
  "phase-semantic-join-route" ->
    expectObservation "join supplied paths" "semantic.join.supplied-path-count" "97" cleanResult
      <> expectObservation "join parsed phases" "semantic.join.parsed-phase-count" "0" cleanResult
      <> expectObservation "join tracker candidates" "semantic.join.tracker-candidate-count" "1" cleanResult
      <> expectObservation "semantic join phase count" "semantic.join.phase-count" "0" cleanResult
      <> expectObservation "resource join phase count" "resource.join.phase-count" "0" cleanResult
      <> expectFindingCount "semantic path missing findings" "PLAN-SEMANTIC-PHASE-PATH-MISSING" 96 cleanResult
      <> expectFindingCount "semantic path unknown findings" "PLAN-SEMANTIC-PHASE-PATH-UNKNOWN" 96 cleanResult
      <> expectFindingCount "semantic Markdown refusal" "PLAN-SEMANTIC-MARKDOWN-DIAGNOSTIC-ONLY" 1 cleanResult
  "sprint-inventory-finding" ->
    expectFindingCount "recorded canonical sprint inventory" "PLAN-SPRINT-INVENTORY" 58 cleanResult
      <> expectExactFinding
        "Phase 0 recorded sprint inventory"
        "PLAN-SPRINT-INVENTORY"
        "DEVELOPMENT_PLAN/phase_00_synthetic_capability.md"
        "sprint identities must be the recorded contiguous inventory [1,2,3,4,5,6,7,8]; observed [Just 1]"
        cleanResult
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
