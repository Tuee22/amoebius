{-# LANGUAGE OverloadedStrings #-}

module PhaseContractOracle
  ( runPhaseContractOracle
  ) where

-- Component diagnostics only.  This oracle does not perform human review,
-- qualify the phase-contract harness, validate a phase, or promote status.

import Amoebius.Validation.PhaseContract (checkPhaseContractStructure, checkPhaseContracts)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text

runPhaseContractOracle :: IO ()
runPhaseContractOracle =
  finishDiagnostics
    "PhaseContractOracle"
    ( concat
        [ expectClean "independently stated 96-phase and tracker corpus" validCorpus
        , expectFindingInResult
            "generic structural boilerplate cannot become a production contract candidate"
            "PLAN-SEMANTIC-AUDIT-UNIMPLEMENTED"
            planRoot
            (checkPhaseContracts validCorpus)
        , expectFindingInResult
            "empty phase discovery"
            "PLAN-PHASE-DISCOVERY"
            planRoot
            (checkPhaseContractStructure [])
        , expectFindingInResult
            "phase-shaped decoy outside DEVELOPMENT_PLAN cannot satisfy discovery"
            "PLAN-PHASE-DISCOVERY"
            planRoot
            (checkPhaseContractStructure [("archive/phase_00_decoy.md", phaseDocument 0)])
        , expectFinding
            "closed phase domain omits Phase 95"
            "PLAN-PHASE-MISSING"
            planRoot
            (filter ((/= phasePath 95) . fst) validCorpus)
        , expectFinding
            "closed phase domain rejects Phase 96"
            "PLAN-PHASE-EXTRA"
            (phasePath 96)
            (validCorpus <> [(phasePath 96, phaseDocument 96)])
        , expectFinding
            "tracker domain omits Phase 95"
            "PLAN-TRACKER-MISSING"
            trackerPath
            (replaceDocument trackerPath (trackerDocument [0 .. 94]) validCorpus)
        , expectFinding
            "phase status reset"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus activeStatus validCorpus)
        , expectFinding
            "tracker status reset"
            "PLAN-TRACKER-STATUS"
            trackerPath
            ( replaceIn
                trackerPath
                (trackerRow 10 blockedTrackerStatus)
                (trackerRow 10 "Done")
                validCorpus
            )
        , expectFinding
            "immediate predecessor dependency"
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (dependencyValue 10)
                "[Phase 8](./phase_08_synthetic_capability.md)"
                validCorpus
            )
        , expectFinding
            "predecessor phase token cannot match a longer ordinal by prefix"
            "PLAN-GATE-PREDECESSOR"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (gateRow "Predecessor" "Phase 09")
                (gateRow "Predecessor" "Phase 090")
                validCorpus
            )
        , expectFinding
            "tracker title joins its phase H1"
            "PLAN-TRACKER-TITLE"
            trackerPath
            ( replaceIn
                trackerPath
                "| 10 | Synthetic capability 10 |"
                "| 10 | Divergent title |"
                validCorpus
            )
        , expectFinding
            "tracker substrate projection joins its phase summary"
            "PLAN-TRACKER-PROJECTION"
            trackerPath
            ( replaceIn
                trackerPath
                (trackerRow 10 blockedTrackerStatus)
                (trackerRowWith 10 "linux-cpu" "none" "2" blockedTrackerStatus)
                validCorpus
            )
        , expectFinding
            "eighteen-row gate cardinality"
            "PLAN-GATE-SHAPE"
            (phasePath 7)
            (replaceIn (phasePath 7) (gateRow "Challenge" standardChallenge) "" validCorpus)
        , expectFinding
            "eighteen-row gate order"
            "PLAN-GATE-SHAPE"
            (phasePath 7)
            ( replaceIn
                (phasePath 7)
                (gateRow "Subject" standardSubject <> "\n" <> gateRow "Command" (commandValue 7))
                (gateRow "Command" (commandValue 7) <> "\n" <> gateRow "Subject" standardSubject)
                validCorpus
            )
        , expectFinding
            "unresolved gate cell refuses"
            "PLAN-GATE-UNRESOLVED"
            (phasePath 8)
            (replaceIn (phasePath 8) (gateRow "Oracle" standardOracle) (gateRow "Oracle" "UNRESOLVED") validCorpus)
        , expectObservation
            "unresolved and missing markers are counted separately"
            "unresolved-marker-cell-count"
            "1"
            (checkPhaseContractStructure markerCorpus)
        , expectObservation
            "missing markers are not mislabeled unresolved"
            "missing-marker-cell-count"
            "1"
            (checkPhaseContractStructure markerCorpus)
        , expectObservation
            "combined refusal-marker count remains explicit"
            "refusal-marker-cell-count"
            "2"
            (checkPhaseContractStructure markerCorpus)
        , expectFinding
            "exact canonical pb command"
            "PLAN-GATE-COMMAND"
            (phasePath 9)
            ( replaceIn
                (phasePath 9)
                (gateRow "Command" (commandValue 9))
                (gateRow "Command" "`pb validate phase 9`")
                validCorpus
            )
        , expectFinding
            "phase-summary canonical pb command"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            ( replaceIn
                (phasePath 9)
                ("**Gate:** " <> commandValue 9 <> " — NOT VALIDATED.")
                "**Gate:** `pb validate phase 9` — NOT VALIDATED."
                validCorpus
            )
        , expectFinding
            "Phase 49 ordered hardware-free semantic spine"
            "PLAN-PHASE49-SPINE"
            (phasePath 49)
            ( replaceIn
                (phasePath 49)
                "plan/resolve → provision → renderAll"
                "plan/resolve → renderAll → provision"
                validCorpus
            )
        , expectFinding
            "Phase 51 remains pre-hardware"
            "PLAN-PREHARDWARE-FIELD"
            (phasePath 51)
            (replaceIn (phasePath 51) "**Substrate:** none" "**Substrate:** linux-cpu" validCorpus)
        , expectFinding
            "Phase 52 is the first hardware-bearing contract"
            "PLAN-HARDWARE-CUT"
            (phasePath 52)
            (replaceIn (phasePath 52) "**Substrate:** linux-cpu" "**Substrate:** none" validCorpus)
        ]
    )

validCorpus :: [(FilePath, Text)]
validCorpus =
  [(phasePath number, phaseDocument number) | number <- [0 .. 95]]
    <> [(trackerPath, trackerDocument [0 .. 95])]

markerCorpus :: [(FilePath, Text)]
markerCorpus =
  replaceIn
    (phasePath 9)
    (gateRow "Oracle" standardOracle)
    (gateRow "Oracle" "`MISSING`")
    ( replaceIn
        (phasePath 8)
        (gateRow "Oracle" standardOracle)
        (gateRow "Oracle" "UNRESOLVED")
        validCorpus
    )

phaseDocument :: Int -> Text
phaseDocument number =
  Text.unlines
    ( [ "# Phase " <> showText number <> ": " <> phaseTitle number
      , ""
      , "## Phase Summary"
      , ""
      , "**Phase scope:** One synthetic Haskell target capability."
      , ""
      , "**Substrate:** " <> substrateValue number
      , ""
      , "**Lane:** " <> laneValue number
      , ""
      , "**Register:** " <> registerValue number
      , ""
      , "**Depends on:** " <> dependencyValue number
      , ""
      , "**Gate:** " <> commandValue number <> " — NOT VALIDATED."
      , ""
      , "## Phase Status"
      , ""
      , if number == 0 then activeStatus else blockedStatus
      , ""
      , "## Gate integrity"
      , ""
      , "| Key | Contract |"
      , "|---|---|"
      ]
        <> gateRows number
    )

gateRows :: Int -> [Text]
gateRows number =
  [ gateRow "Claim" (if number == 49 then phaseFortyNineClaim else standardClaim)
  , gateRow "Subject" (if number == 49 then phaseFortyNineSubject else standardSubject)
  , gateRow "Command" (commandValue number)
  , gateRow "Oracle" standardOracle
  , gateRow "Positive controls" "A legal control remains green."
  , gateRow "Paired negatives" "A one-defect negative must turn red."
  , gateRow "Mutants" "A production-locus mutation must be observed."
  , gateRow "Discovery" "The complete supplied corpus is enumerated."
  , gateRow "Challenge" standardChallenge
  , gateRow "Observer" "The observer is separate from the subject."
  , gateRow "Authority/bypass" "No alternate verdict authority exists."
  , gateRow "Freshness" "The candidate binds the supplied source snapshot."
  , gateRow "Qualification" "Qualification remains a separate component."
  , gateRow "Cleanroom" "Generated material begins absent."
  , gateRow "Legacy closure" "Active owner-phase rows must reach zero."
  , gateRow "Predecessor" (if number == 0 then "genesis" else "Phase " <> formatPhase (number - 1))
  , gateRow "Residue" "Later layers remain UNVERIFIED."
  , gateRow "Human authority" "Promotion authority is human-only."
  ]

gateRow :: Text -> Text -> Text
gateRow key value = "| " <> key <> " | " <> value <> " |"

standardClaim :: Text
standardClaim = "The Haskell target capability satisfies its frozen claim."

standardSubject :: Text
standardSubject = "Amoebius.Target"

standardOracle :: Text
standardOracle = "An independently authored Haskell expectation decides the claim."

standardChallenge :: Text
standardChallenge = "The paired negative changes exactly one semantic fact."

phaseFortyNineClaim :: Text
phaseFortyNineClaim =
  "The hardware-free Haskell spine is decode → legality → bind/expand → plan/resolve → provision → renderAll → plan → dry-run → fake-apply."

phaseFortyNineSubject :: Text
phaseFortyNineSubject =
  Text.intercalate
    ", "
    [ "Amoebius.Dsl.Decode"
    , "Amoebius.Dsl.Foreclosure"
    , "Amoebius.Capability.Binding"
    , "Amoebius.Capacity.Provision"
    , "Amoebius.Manifest.RenderAll"
    , "Amoebius.Kernel.Chain"
    , "Amoebius.Kernel.Plan"
    , "Amoebius.Exec.Boundary"
    , "Amoebius.Validation.DslBarrier"
    ]

phaseTitle :: Int -> Text
phaseTitle 49 = "No-hardware DSL promotion barrier"
phaseTitle number = "Synthetic capability " <> showText number

phasePath :: Int -> FilePath
phasePath number =
  "DEVELOPMENT_PLAN/phase_"
    <> Text.unpack (formatPhase number)
    <> "_synthetic_capability.md"

dependencyValue :: Int -> Text
dependencyValue 0 = "genesis"
dependencyValue number =
  "[Phase "
    <> showText (number - 1)
    <> "](./phase_"
    <> formatPhase (number - 1)
    <> "_synthetic_capability.md)"

commandValue :: Int -> Text
commandValue number = "`pb validate phase " <> formatPhase number <> "`"

substrateValue :: Int -> Text
substrateValue number
  | number <= 51 = "none"
  | otherwise = "linux-cpu"

laneValue :: Int -> Text
laneValue number
  | number <= 51 = "none"
  | otherwise = "cpu"

registerValue :: Int -> Text
registerValue number
  | number <= 51 = "2"
  | otherwise = "3"

activeStatus :: Text
activeStatus = "🔄 Active — NOT VALIDATED."

blockedStatus :: Text
blockedStatus = "⏸️ Blocked — NOT VALIDATED."

activeTrackerStatus :: Text
activeTrackerStatus = "🔄 Active — NOT VALIDATED"

blockedTrackerStatus :: Text
blockedTrackerStatus = "⏸️ Blocked — NOT VALIDATED"

trackerDocument :: [Int] -> Text
trackerDocument numbers =
  Text.unlines
    ( [ "# Synthetic Development Plan Tracker"
      , ""
      , "| Phase | Title | Substrate | Lane | Register | Status | Contract |"
      , "|---|---|---|---|---|---|---|"
      ]
        <> [trackerRow number (if number == 0 then activeTrackerStatus else blockedTrackerStatus) | number <- numbers]
    )

trackerRow :: Int -> Text -> Text
trackerRow number =
  trackerRowWith number (substrateValue number) (laneValue number) (registerValue number)

trackerRowWith :: Int -> Text -> Text -> Text -> Text -> Text
trackerRowWith number substrate lane register status =
  "| "
    <> showText number
    <> " | "
    <> phaseTitle number
    <> " | "
    <> substrate
    <> " | "
    <> lane
    <> " | "
    <> register
    <> " | "
    <> status
    <> " | [Contract](./phase_"
    <> formatPhase number
    <> "_synthetic_capability.md) |"

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"

planRoot :: FilePath
planRoot = "DEVELOPMENT_PLAN/"

formatPhase :: Int -> Text
formatPhase number
  | number < 10 = "0" <> showText number
  | otherwise = showText number

showText :: Show value => value -> Text
showText = Text.pack . show

replaceIn :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceIn wanted old new =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, Text.replace old new contents)
          else entry
    )

replaceDocument :: FilePath -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceDocument wanted replacement =
  map
    ( \entry@(path, _) ->
        if path == wanted
          then (path, replacement)
          else entry
    )

expectClean :: String -> [(FilePath, Text)] -> [String]
expectClean label corpus =
  case checkFindings (checkPhaseContractStructure corpus) of
    [] -> []
    findings -> [label <> ": unexpected findings " <> show findings]

expectFinding :: String -> Text -> FilePath -> [(FilePath, Text)] -> [String]
expectFinding label code locus = expectFindingInResult label code locus . checkPhaseContractStructure

expectFindingInResult :: String -> Text -> FilePath -> CheckResult -> [String]
expectFindingInResult label code locus result
  | any matches (checkFindings result) = []
  | otherwise =
      [ label
          <> ": expected finding "
          <> Text.unpack code
          <> " at "
          <> locus
          <> ", observed "
          <> show (checkFindings result)
      ]
  where
    matches item = findingCode item == code && findingSubject item == locus

expectObservation :: String -> Text -> Text -> CheckResult -> [String]
expectObservation label key expected result =
  case [observationValue item | item <- checkObservations result, observationKey item == key] of
    [actual]
      | actual == expected -> []
    observed -> [label <> ": expected " <> Text.unpack key <> "=" <> Text.unpack expected <> ", observed " <> show observed]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
