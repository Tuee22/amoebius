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
            "production contracts pin the complete sprint inventory"
            "PLAN-SPRINT-INVENTORY"
            (phasePath 0)
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
            "a second bare phase status cannot hide after the reset line"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus (blockedStatus <> "\n\n✅ Done") validCorpus)
        , expectFinding
            "a second phase Status field cannot hide after the reset line"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus (blockedStatus <> "\n\n**Status**: ✅ Done") validCorpus)
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
        , expectClean
            "gate-row prose cannot supply predecessor, residue, or authority semantics"
            gateSemanticProseDecoyCorpus
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
                (gateSummaryLine 9)
                "**Gate:** `pb validate phase 9` — NOT VALIDATED."
                validCorpus
            )
        , expectFinding
            "phase-summary dual Validated and NOT VALIDATED status"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) ("**Gate:** " <> commandValue 9 <> "; see [Gate integrity](#gate-integrity). Validated — NOT VALIDATED.") validCorpus)
        , expectFinding
            "a fenced canonical gate summary cannot mask a contradictory live summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            ( appendTo
                (phasePath 9)
                ("\n```text\n" <> gateSummaryLine 9 <> "\n```\n")
                (replaceIn (phasePath 9) (gateSummaryLine 9) ("**Gate:** " <> commandValue 9 <> "; see [Gate integrity](#gate-integrity). Validated — NOT VALIDATED.") validCorpus)
            )
        , expectFinding
            "an HTML-comment-spliced reset is not the raw canonical gate summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) (Text.replace "NOT VALIDATED" "NOT<!-- hidden --> VALIDATED" (gateSummaryLine 9)) validCorpus)
        , expectFinding
            "a line-wrapped reset is not the raw canonical gate summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) (Text.replace "NOT VALIDATED" "NOT\nVALIDATED" (gateSummaryLine 9)) validCorpus)
        , expectClean
            "an exact blocked sprint reset status is admitted structurally"
            (appendTo (phasePath 10) (sprintBlock 10 1 "Blocked — NOT VALIDATED") validCorpus)
        , expectFinding
            "a dual Validated and NOT VALIDATED sprint status is refused"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (appendTo (phasePath 10) (sprintBlock 10 1 "Validated — NOT VALIDATED") validCorpus)
        , expectFinding
            "an HTML-comment-spliced sprint reset is not the raw canonical field"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (appendTo (phasePath 10) (sprintBlock 10 1 "Blocked — NOT<!-- hidden --> VALIDATED") validCorpus)
        , expectFinding
            "a lowercase done sprint status is refused"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (appendTo (phasePath 10) (sprintBlock 10 1 "done — NOT VALIDATED") validCorpus)
        , expectFinding
            "a sprint heading cannot claim another phase"
            "PLAN-SPRINT-IDENTITY"
            (phasePath 10)
            (appendTo (phasePath 10) (sprintBlock 9 1 "Blocked — NOT VALIDATED") validCorpus)
        , expectClean
            "Phase 49 Claim, Subject, and title prose are semantically inert"
            phaseFortyNineProseDecoyCorpus
        , expectClean
            "Substrate, Lane, and Register projections cannot supply hardware-ordering semantics"
            phaseProjectionSemanticDecoyCorpus
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

gateSemanticProseDecoyCorpus :: [(FilePath, Text)]
gateSemanticProseDecoyCorpus =
  replaceIn
    (phasePath 10)
    (gateRow "Human authority" "Promotion authority is human-only.")
    (gateRow "Human authority" "This reader-facing explanation carries no executable policy value.")
    ( replaceIn
        (phasePath 10)
        (gateRow "Residue" "Later layers remain UNVERIFIED.")
        (gateRow "Residue" "This reader-facing explanation carries no executable coverage value.")
        ( replaceIn
            (phasePath 10)
            (gateRow "Predecessor" "Phase 09")
            (gateRow "Predecessor" "This reader-facing explanation carries no executable dependency value.")
            ( replaceIn
                (phasePath 10)
                (gateRow "Command" (commandValue 10))
                (gateRow "Command" (commandValue 10 <> "; Python and tools/ are inert explanatory decoys."))
                validCorpus
            )
        )
    )

phaseFortyNineProseDecoyCorpus :: [(FilePath, Text)]
phaseFortyNineProseDecoyCorpus =
  replaceIn
    trackerPath
    "| 49 | No-hardware DSL promotion barrier |"
    "| 49 | Semantically opaque prose |"
    ( replaceIn
        (phasePath 49)
        "# Phase 49: No-hardware DSL promotion barrier"
        "# Phase 49: Semantically opaque prose"
        ( replaceIn
            (phasePath 49)
            (gateRow "Subject" phaseFortyNineSubject)
            (gateRow "Subject" "Harbor and registry:2 are inert prose decoys, not executable provider values.")
            ( replaceIn
                (phasePath 49)
                (gateRow "Claim" phaseFortyNineClaim)
                (gateRow "Claim" "Module names and fake-apply keywords in this prose carry no executable semantics.")
                validCorpus
            )
        )
    )

phaseProjectionSemanticDecoyCorpus :: [(FilePath, Text)]
phaseProjectionSemanticDecoyCorpus =
  replaceIn
    trackerPath
    (trackerRowWith 52 "linux-cpu" "cpu" "3" blockedTrackerStatus)
    (trackerRowWith 52 "none" "semantically-opaque" "2" blockedTrackerStatus)
    ( replaceIn
        (phasePath 52)
        "**Substrate:** linux-cpu\n\n**Lane:** cpu\n\n**Register:** 3"
        "**Substrate:** none\n\n**Lane:** semantically-opaque\n\n**Register:** 2"
        ( replaceIn
            trackerPath
            (trackerRowWith 51 "none" "none" "2" blockedTrackerStatus)
            (trackerRowWith 51 "linux-cpu" "cuda" "3" blockedTrackerStatus)
            ( replaceIn
                (phasePath 51)
                "**Substrate:** none\n\n**Lane:** none\n\n**Register:** 2"
                "**Substrate:** linux-cpu\n\n**Lane:** cuda\n\n**Register:** 3"
                validCorpus
            )
        )
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
      , gateSummaryLine number
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

gateSummaryLine :: Int -> Text
gateSummaryLine number =
  "**Gate:** " <> commandValue number <> "; see [Gate integrity](#gate-integrity). NOT VALIDATED."

sprintBlock :: Int -> Int -> Text -> Text
sprintBlock phaseNumberValue sprintNumber status =
  Text.unlines
    [ ""
    , "## Sprint " <> showText phaseNumberValue <> "." <> showText sprintNumber <> ": Synthetic seam ⏸️"
    , ""
    , "**Status**: " <> status
    ]

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

appendTo :: FilePath -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
appendTo wanted addition =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, contents <> addition)
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
