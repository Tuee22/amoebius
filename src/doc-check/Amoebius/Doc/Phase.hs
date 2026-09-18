{-# LANGUAGE OverloadedStrings #-}

-- | Structural phase-contract and tracker checks of the standalone documentation
-- checker: the exact document shape the development-plan rulebooks fix, the
-- dependency and blocker edges, the eighteen-row gate table, the sprint schema, and
-- the recorded status vector against the one canonical frontier. No semantic
-- registry, no evidence capture, no kernel import.
module Amoebius.Doc.Phase
  ( PhaseDocument (..)
  , checkPhaseAndTracker
  , checkPhaseContractStructure
  , checkPhaseContracts
  , checkPhaseContractsAfterPass
  , checkPhaseContractsForPhase
  , parsePhaseDocument
  , phaseNumberFromPath
  , recordedStatusFrontier
  , trackerPath
  ) where

import Amoebius.Doc.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import Data.List (findIndex, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe, maybeToList)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath.Posix (normalise, takeDirectory, takeFileName)
import System.FilePath (takeExtension)
import Text.Read (readMaybe)

data PhaseDocument = PhaseDocument
  { phaseNumber :: Int
  , phasePath :: FilePath
  , phaseRawLines :: [Text]
  , phaseLines :: [(Int, Text)]
  , phaseTitle :: Maybe Text
  , phaseFields :: Map Text [Text]
  , phaseSummaryFieldOrder :: [Text]
  , phaseSummaryFieldStrays :: [(Int, Text)]
  , phaseSectionHeadings :: [Text]
  , phaseGateRows :: [(Text, Text)]
  , phaseGateFrameProblems :: [Text]
  }
  deriving (Eq, Show)

data TrackerRow = TrackerRow
  { trackerNumber :: Int
  , trackerTitle :: Text
  , trackerSubstrate :: Text
  , trackerLane :: Text
  , trackerRegister :: Text
  , trackerStatus :: Text
  , trackerContract :: Text
  }
  deriving (Eq, Show)

data Fence = Fence Char Int
  deriving (Eq, Show)

data HtmlBlock
  = HtmlUntilBlank
  | HtmlUntilMarker Text
  deriving (Eq, Show)

data PlanLine
  = StructuralLine Int Text
  | OpaqueBoundary Int
  deriving (Eq, Show)

data TrackerFrame = TrackerFrame
  { trackerFrameRows :: [TrackerRow]
  , trackerFrameProblems :: [Text]
  }
  deriving (Eq, Show)

data TrackerStage
  = TrackerSeekingHeader
  | TrackerExpectingDelimiter
  | TrackerExpectingRow Int
  | TrackerExpectingEnd
  | TrackerFinished
  | TrackerBroken
  deriving (Eq, Show)

data TrackerScan = TrackerScan
  { trackerScanStage :: TrackerStage
  , trackerScanHeaderCount :: Int
  , trackerScanRowsReversed :: [TrackerRow]
  , trackerScanProblemsReversed :: [Text]
  }
  deriving (Eq, Show)

-- | Pure worktree phase/tracker check. The complete tracker vector must encode
-- exactly one typed canonical frontier. That recorded frontier governs all
-- status projections, while semantic obligations extend through its completed
-- prefix. This is a structural diagnostic, not evidence that the recorded
-- transitions occurred; candidate paths use 'checkPhaseContractsForPhase'.
checkPhaseContracts :: [(FilePath, Text)] -> CheckResult
checkPhaseContracts supplied =
  case phaseContractInputEnvelopeFindings supplied of
    [] -> case recordedStatusFrontier supplied of
      Just frontier ->
        checkPhaseContractsWithSemanticBarrier
          (RecordedScope (Status.completedPrefixDueOrdinal frontier) frontier)
          supplied
      Nothing ->
        addRecordedFrontierRefusal
          (checkPhaseContractsWithSemanticBarrier (RecordedScope phaseDomainLowerNumber Status.initialFrontier) supplied)
    _ -> checkPhaseContractsWithSemanticBarrier (RecordedScope phaseDomainLowerNumber Status.initialFrontier) supplied

-- | The gate-path entry, scoped to the phase under validation.  A semantic
-- contract gap at a strictly later phase is that phase's obligation, not this
-- one's, so it is observed rather than fatal
-- (development_plan_gate_integrity.md section M.6).
checkPhaseContractsForPhase :: Int -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsForPhase phase supplied =
  case Status.frontierForGate phase of
    Nothing -> invalidStatusTarget "gate" phase
    Just frontier -> checkPhaseContractsWithSemanticBarrier (GateScope phase frontier) supplied

-- | Validate the exact in-memory status projection produced by a passing gate
-- before any tracked byte is replaced. Semantic obligations remain scoped to
-- the phase that just passed; only the status frontier advances.
checkPhaseContractsAfterPass :: Int -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsAfterPass phase supplied =
  case Status.frontierForGate phase >>= (\frontier -> Status.frontierAfterPass frontier phase) of
    Nothing -> invalidStatusTarget "post-pass" phase
    Just frontier -> checkPhaseContractsWithSemanticBarrier (PostPassScope phase frontier) supplied

invalidStatusTarget :: Text -> Int -> CheckResult
invalidStatusTarget scope phase =
  CheckResult
    { checkName = phaseContractCheckName
    , checkObservations =
        [ observation "phase-contract.status-scope" scope
        , observation "phase-contract.status-target" (showText phase)
        ]
    , checkFindings =
        [ finding
            "PLAN-STATUS-FRONTIER-INVALID"
            "DEVELOPMENT_PLAN/"
            "the requested status frontier is outside the canonical phase domain or is not a one-step transition"
        ]
    }

-- | Structural parser seam for small oracle corpora. It always carries an
-- exact diagnostic-only refusal: caller-authored Markdown bytes cannot become
-- a candidate-shaped green 'CheckResult'.
checkPhaseContractStructure :: [(FilePath, Text)] -> CheckResult
checkPhaseContractStructure = checkPhaseContractsWithSemanticBarrier StructuralOnly

-- | Which register this parse is serving.  'StructuralOnly' is the pure
-- caller-supplied seam and keeps its exact permanent refusal; 'GateScope'
-- names the phase under validation.
data SemanticScope
  = StructuralOnly
  | GateScope Int Status.StatusFrontier
  | PostPassScope Int Status.StatusFrontier
  | RecordedScope Int Status.StatusFrontier
  deriving (Eq, Show)

semanticAuditRequired :: SemanticScope -> Bool
semanticAuditRequired scope = case scope of
  StructuralOnly -> False
  GateScope _ _ -> True
  PostPassScope _ _ -> True
  RecordedScope _ _ -> True

checkPhaseContractsWithSemanticBarrier :: SemanticScope -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsWithSemanticBarrier scope supplied =
  case phaseContractInputEnvelopeFindings supplied of
    [] -> checkPhaseContractsWithinEnvelope scope supplied
    envelopeFindings ->
      CheckResult
        { checkName = phaseContractCheckName
        , checkObservations = phaseContractInputEnvelopeObservations
        , checkFindings = structuralDiagnosticRefusal (semanticAuditRequired scope) <> phaseContractInputEnvelopeResultFindings envelopeFindings
        }

checkPhaseContractsWithinEnvelope :: SemanticScope -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsWithinEnvelope scope supplied =
  CheckResult
    { checkName = phaseContractCheckName
    , checkObservations = structuralResultObservations
          <> semanticResultObservations
    , checkFindings =
        phaseDomainResultFindings
          <> phaseStructureResultFindings
          <> dependencyResultFindings
          <> gateResultFindings
          <> sprintResultFindings
          <> trackerResultFindings
          <> trackerJoinResultFindings
          <> projectionVocabularyResultFindings
          <> structuralDiagnosticRefusal (semanticAuditRequired scope)
          <> semanticResultFindings
    }
 where
  normalized = [(normalizePath path, contents) | (path, contents) <- supplied]
  parsed = mapMaybe (uncurry parsePhaseDocument) normalized
  grouped = Map.fromListWith (<>) [(phaseNumber phase, [phase]) | phase <- parsed]
  phases = Map.mapMaybe selectPhaseDocument grouped
  structuralResultObservations =
    guardedStructuralResultObservations
  guardedStructuralResultObservations =
    [ observation "phase-document-count" (phaseDocumentCountObservationValue (Map.size phases))
    , observation "tracker-row-count" (trackerRowCountObservationValue (length trackerRows))
    , observation "gate-row-count" (gateRowCountObservationValue (sum (map (length . phaseGateRows) (Map.elems phases))))
    , observation "sprint-section-count" (sprintSectionCountObservationValue (sum (map (length . sprintSectionsFor) (Map.elems phases))))
    , observation "unresolved-marker-cell-count" (unresolvedMarkerCountObservationValue unresolvedMarkerCount)
    , observation "missing-marker-cell-count" (missingMarkerCountObservationValue missingMarkerCount)
    , observation "refusal-marker-cell-count" (refusalMarkerCountObservationValue refusalMarkerCount)
    ]
  phaseDomainResultFindings =
    guardedPhaseDomainResultFindings
  guardedPhaseDomainResultFindings = phaseDomainFindings
  phaseStructureResultFindings =
    guardedPhaseStructureResultFindings
  guardedPhaseStructureResultFindings = concatMap (checkPhaseStructure scope) (Map.elems phases)
  dependencyResultFindings =
    guardedDependencyResultFindings
  guardedDependencyResultFindings = concatMap (checkDependency phases) (Map.elems phases)
  gateResultFindings =
    guardedGateResultFindings
  guardedGateResultFindings = concatMap (checkGate scope) (Map.elems phases)
  sprintResultFindings =
    guardedSprintResultFindings
  guardedSprintResultFindings = concatMap (checkSprintContracts phases scope (semanticAuditRequired scope)) (Map.elems phases)
  trackerResultFindings =
    guardedTrackerResultFindings
  guardedTrackerResultFindings = trackerFindings
  trackerJoinResultFindings =
    guardedTrackerJoinResultFindings
  guardedTrackerJoinResultFindings = checkTrackerJoin phases trackerRows
  projectionVocabularyResultFindings =
    guardedProjectionVocabularyResultFindings
  guardedProjectionVocabularyResultFindings = checkProjectionVocabulary phases trackerRows
  semanticResultObservations =
    guardedSemanticResultObservations
  guardedSemanticResultObservations = concatMap checkObservations semanticDiagnostics
  semanticResultFindings =
    guardedSemanticResultFindings
  guardedSemanticResultFindings = concatMap checkFindings semanticDiagnostics
  duplicatePhaseFindings =
    guardedDuplicatePhaseFindings
  guardedDuplicatePhaseFindings =
    [ finding
        "PLAN-PHASE-DUPLICATE"
        (phasePath first)
        ("phase ordinal occurs in more than one contract path: " <> renderPaths candidates)
    | candidates@(first : _) <- Map.elems grouped
    , length candidates /= 1
    ]
  expectedNumbers = Set.fromList PhaseIdentity.phaseOrdinals
  actualNumbers = Map.keysSet phases
  missingNumbers = Set.toAscList (expectedNumbers Set.\\ actualNumbers)
  extraNumbers = Set.toAscList (actualNumbers Set.\\ expectedNumbers)
  phaseDomainFindings =
    duplicatePhaseFindings
      <> missingPhaseFindings
      <> extraPhaseFindings
      <> discoveryPhaseFindings
  missingPhaseFindings =
    guardedMissingPhaseFindings
  guardedMissingPhaseFindings =
    [finding "PLAN-PHASE-MISSING" "DEVELOPMENT_PLAN/" ("missing Phase " <> showText number) | number <- missingNumbers]
  extraPhaseFindings =
    guardedExtraPhaseFindings
  guardedExtraPhaseFindings =
    [finding "PLAN-PHASE-EXTRA" (phasePath phase) ("phase ordinal lies outside the closed " <> phaseDomainLabel <> " domain") | number <- extraNumbers, Just phase <- [Map.lookup number phases]]
  discoveryPhaseFindings =
    guardedDiscoveryPhaseFindings
  guardedDiscoveryPhaseFindings =
    [finding "PLAN-PHASE-DISCOVERY" "DEVELOPMENT_PLAN/" "no numbered phase contracts were supplied" | Map.null phases]
  trackerCandidates = [contents | (path, contents) <- normalized, path == trackerPath]
  trackerFrame = case trackerCandidates of
    [contents] -> parseTrackerDocument contents
    _ -> TrackerFrame [] []
  trackerRows = trackerFrameRows trackerFrame
  trackerFindings =
    trackerCardinalityFindings
      <> trackerFrameFindings trackerFrame
      <> checkTrackerShape scope trackerRows
  trackerCardinalityFindings =
    guardedTrackerCardinalityFindings
  guardedTrackerCardinalityFindings =
    [ finding
        "PLAN-TRACKER-CARDINALITY"
        trackerPath
        "the supplied corpus must contain exactly one development-plan tracker"
    | length trackerCandidates /= 1
    ]
  gateCellValues = [value | phase <- Map.elems phases, (_, value) <- phaseGateRows phase]
  unresolvedMarkerCount = length (filter containsUnresolvedMarker gateCellValues)
  missingMarkerCount = length (filter containsMissingMarker gateCellValues)
  refusalMarkerCount = length (filter containsRefusalMarker gateCellValues)
  semanticDiagnostics = [] :: [CheckResult]




trackerFrameFindings :: TrackerFrame -> [Finding]
trackerFrameFindings frame =
  guardedTrackerFrameFindings
 where
  guardedTrackerFrameFindings =
    [ finding "PLAN-TRACKER-TABLE-FRAME" trackerPath problem
    | problem <- trackerFrameProblems frame
    ]

recordedStatusFrontier :: [(FilePath, Text)] -> Maybe Status.StatusFrontier
recordedStatusFrontier supplied = case trackerCandidates of
  [contents]
    | null (trackerFrameProblems frame)
        && map trackerNumber rows == PhaseIdentity.phaseOrdinals -> do
        statuses <- traverse (Status.parseTrackerStatus . Text.strip . trackerStatus) rows
        Status.recognizeStatusFrontier statuses
    | otherwise -> Nothing
    where
      frame = parseTrackerDocument contents
      rows = trackerFrameRows frame
  _ -> Nothing
 where
  trackerCandidates =
    [ contents
    | (path, contents) <- supplied
    , normalizePath path == trackerPath
    ]

addRecordedFrontierRefusal :: CheckResult -> CheckResult
addRecordedFrontierRefusal result =
  result
    { checkFindings =
        finding
          "PLAN-STATUS-FRONTIER-RECORDED"
          trackerPath
          "the complete tracker status vector must encode exactly one canonical ordered frontier"
          : checkFindings result
    }

phaseContractCheckName :: Text
phaseContractCheckName = "phase-contracts"

phaseDocumentCountObservationValue :: Int -> Text
phaseDocumentCountObservationValue = showText

trackerRowCountObservationValue :: Int -> Text
trackerRowCountObservationValue = showText

gateRowCountObservationValue :: Int -> Text
gateRowCountObservationValue = showText

sprintSectionCountObservationValue :: Int -> Text
sprintSectionCountObservationValue = showText

unresolvedMarkerCountObservationValue :: Int -> Text
unresolvedMarkerCountObservationValue = showText

missingMarkerCountObservationValue :: Int -> Text
missingMarkerCountObservationValue = showText

refusalMarkerCountObservationValue :: Int -> Text
refusalMarkerCountObservationValue = showText

phaseContractInputEnvelopeFindings :: [(FilePath, Text)] -> [Finding]
phaseContractInputEnvelopeFindings supplied
  | phaseContractEntryCountExceeded supplied =
      [ finding
          "PLAN-INPUT-ENTRY-LIMIT"
          "DEVELOPMENT_PLAN/"
          ("supplied phase-contract entry count exceeds " <> showText phaseContractInputEntryLimit)
      ]
  | not (null pathFindings) = pathFindings
  | not (null documentFindings) = documentFindings
  | phaseContractTotalCharactersExceeded supplied =
      [ finding
          "PLAN-INPUT-TOTAL-LIMIT"
          "DEVELOPMENT_PLAN/"
          ("supplied phase-contract character total exceeds " <> showText phaseContractInputTotalCharacterLimit)
      ]
  | otherwise = []
 where
  pathFindings =
    [ finding
        "PLAN-INPUT-PATH-LIMIT"
        "supplied-path"
        ( "entry "
            <> showText ordinal
            <> " path exceeds "
            <> showText phaseContractInputPathCharacterLimit
            <> " characters"
        )
    | (ordinal, (path, _)) <- zip [(1 :: Int) ..] supplied
    , phaseContractPathCharactersExceeded path
    ]
  documentFindings =
    [ finding
        "PLAN-INPUT-DOCUMENT-LIMIT"
        (normalizePath path)
        ("document exceeds " <> showText phaseContractInputDocumentCharacterLimit <> " characters")
    | (path, contents) <- supplied
    , phaseContractDocumentCharactersExceeded contents
    ]

phaseContractEntryCountExceeded :: [(FilePath, Text)] -> Bool
phaseContractEntryCountExceeded = phaseContractHasMoreThan phaseContractInputEntryLimit

phaseContractPathCharactersExceeded :: FilePath -> Bool
phaseContractPathCharactersExceeded = phaseContractHasMoreThan phaseContractInputPathCharacterLimit

phaseContractDocumentCharactersExceeded :: Text -> Bool
phaseContractDocumentCharactersExceeded contents = Text.length contents > phaseContractInputDocumentCharacterLimit

phaseContractTotalCharactersExceeded :: [(FilePath, Text)] -> Bool
phaseContractTotalCharactersExceeded = go 0
 where
  go _ [] = False
  go accumulated ((_, contents) : rest)
    | Text.length contents > phaseContractInputTotalCharacterLimit - accumulated = True
    | otherwise = go (accumulated + Text.length contents) rest

phaseContractHasMoreThan :: Int -> [value] -> Bool
phaseContractHasMoreThan limit = not . null . drop limit

phaseContractInputEntryLimit :: Int
phaseContractInputEntryLimit = 256

phaseContractInputPathCharacterLimit :: Int
phaseContractInputPathCharacterLimit = 4096

phaseContractInputDocumentCharacterLimit :: Int
phaseContractInputDocumentCharacterLimit = 524288

phaseContractInputTotalCharacterLimit :: Int
phaseContractInputTotalCharacterLimit = 8388608

phaseContractInputEnvelopeObservationValue :: Text
phaseContractInputEnvelopeObservationValue = "refused-before-parse"

phaseContractInputEntryLimitObservationValue :: Int -> Text
phaseContractInputEntryLimitObservationValue = showText

phaseContractInputPathLimitObservationValue :: Int -> Text
phaseContractInputPathLimitObservationValue = showText

phaseContractInputDocumentLimitObservationValue :: Int -> Text
phaseContractInputDocumentLimitObservationValue = showText

phaseContractInputTotalLimitObservationValue :: Int -> Text
phaseContractInputTotalLimitObservationValue = showText

phaseContractInputEnvelopeObservations :: [Observation]
phaseContractInputEnvelopeObservations =
  guardedPhaseContractInputEnvelopeObservations
 where
  guardedPhaseContractInputEnvelopeObservations =
    [ observation "phase-contract-input-envelope" phaseContractInputEnvelopeObservationValue
    , observation "phase-contract-input-entry-limit" (phaseContractInputEntryLimitObservationValue phaseContractInputEntryLimit)
    , observation "phase-contract-input-path-character-limit" (phaseContractInputPathLimitObservationValue phaseContractInputPathCharacterLimit)
    , observation "phase-contract-input-document-character-limit" (phaseContractInputDocumentLimitObservationValue phaseContractInputDocumentCharacterLimit)
    , observation "phase-contract-input-total-character-limit" (phaseContractInputTotalLimitObservationValue phaseContractInputTotalCharacterLimit)
    ]

phaseContractInputEnvelopeResultFindings :: [Finding] -> [Finding]
phaseContractInputEnvelopeResultFindings = id

structuralDiagnosticRefusal :: Bool -> [Finding]
structuralDiagnosticRefusal requireSemanticAudit =
  [ finding
      "PLAN-STRUCTURE-DIAGNOSTIC-ONLY"
      "DEVELOPMENT_PLAN/"
      "caller-authored structural input has no semantic, capture, gate-evidence, observer, or gate-pass rule"
  | not requireSemanticAudit
  ]

-- | Explicit name for callers that treat the tracker join as one pure seam.
checkPhaseAndTracker :: [(FilePath, Text)] -> CheckResult
checkPhaseAndTracker = checkPhaseContracts

parsePhaseDocument :: FilePath -> Text -> Maybe PhaseDocument
parsePhaseDocument path contents = do
  number <- phaseNumberFromPath path
  let visible = outsideFences contents
      summaryBodies = sectionBodies "## Phase Summary" visible
      summaryLines = concat summaryBodies
      summaryEntries = fieldEntries summaryLines
      summaryLabels = mapMaybe summaryFieldLabel summaryLines
      fields = Map.fromListWith (<>) [(name, [value]) | (_, name, value) <- summaryEntries]
      summaryLineNumbers = Set.fromList [lineNumber | (lineNumber, _) <- summaryLines]
      allSummaryEntries = fieldEntries visible
      summaryStrays =
        [ (lineNumber, name)
        | (lineNumber, name, _) <- allSummaryEntries
        , not (Set.member lineNumber summaryLineNumbers)
        ]
      gateFrame = analyzeGateFrame (sectionBodies "## Gate integrity" visible)
  pure
    PhaseDocument
      { phaseNumber = number
      , phasePath = path
      , phaseRawLines = Text.lines contents
      , phaseLines = visible
      , phaseTitle = parsePhaseTitle number visible
      , phaseFields = fields
      , phaseSummaryFieldOrder = summaryLabels
      , phaseSummaryFieldStrays = summaryStrays
      , phaseSectionHeadings = [trimAsciiEnd line | (_, line) <- visible, isH2 line]
      , phaseGateRows = gateFrameRows gateFrame
      , phaseGateFrameProblems = gateFrameProblems gateFrame
      }

phaseNumberFromPath :: FilePath -> Maybe Int
phaseNumberFromPath path
  | takeDirectory path /= "DEVELOPMENT_PLAN" = Nothing
  | otherwise = phaseNumberFromFileName path

phaseNumberFromFileName :: FilePath -> Maybe Int
phaseNumberFromFileName path = do
  remainder <- phasePathPrefix (Text.pack (takeFileName path))
  (digits, suffix) <- phasePathDigitPrefix remainder
  if Text.all isDigit digits
      && phasePathSeparatorValid suffix
      && phasePathExtensionValid suffix
      && phasePathSlugNonEmpty suffix
      && phasePathSlugCharactersValid suffix
      && phasePathSlugSegmentsValid suffix
    then readMaybe (Text.unpack digits)
    else Nothing

phasePathPrefix :: Text -> Maybe Text
phasePathPrefix = Text.stripPrefix "phase_"

phasePathDigitPrefix :: Text -> Maybe (Text, Text)
phasePathDigitPrefix remainder =
  let result@(digits, _) = Text.splitAt 2 remainder
   in if Text.length digits == 2 then Just result else Nothing

phasePathSeparatorValid :: Text -> Bool
phasePathSeparatorValid = Text.isPrefixOf "_"

phasePathExtensionValid :: Text -> Bool
phasePathExtensionValid = Text.isSuffixOf ".md"

phasePathSlug :: Text -> Text
phasePathSlug suffix =
  let withoutExtension =
        case Text.stripSuffix ".md" suffix of
          Just value -> value
          Nothing -> maybe suffix id (Text.stripSuffix ".txt" suffix)
   in maybe withoutExtension id (Text.stripPrefix "_" withoutExtension)

phasePathSlugNonEmpty :: Text -> Bool
phasePathSlugNonEmpty = not . Text.null . phasePathSlug

phasePathSlugCharactersValid :: Text -> Bool
phasePathSlugCharactersValid = Text.all phaseSlugCharacter . phasePathSlug

phaseSlugCharacter :: Char -> Bool
phaseSlugCharacter character =
  (character >= 'a' && character <= 'z') || isDigit character || character == '_'

phasePathSlugSegmentsValid :: Text -> Bool
phasePathSlugSegmentsValid suffix =
  let slug = phasePathSlug suffix
   in Text.null slug || all (not . Text.null) (Text.splitOn "_" slug)

parsePhaseTitle :: Int -> [(Int, Text)] -> Maybe Text
parsePhaseTitle number visible =
  selectPhaseTitle
    [ Text.strip title
    | (_, line) <- visible
    , Just title <- [phaseTitleRemainder number (trimAsciiEnd line)]
    , phaseTitleBodyNonEmpty title
    ]

phaseTitleRemainder :: Int -> Text -> Maybe Text
phaseTitleRemainder number = Text.stripPrefix ("# Phase " <> showText number <> ":")

phaseTitleBodyNonEmpty :: Text -> Bool
phaseTitleBodyNonEmpty = not . Text.null . Text.strip

selectPhaseTitle :: [Text] -> Maybe Text
selectPhaseTitle candidates =
  case candidates of
    [title] -> Just title
    _ -> Nothing

summaryFieldNames :: [Text]
summaryFieldNames = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

-- | The one conditional Phase Summary field. It is present exactly when the
-- phase names an artefact a later phase owns, so it is neither required nor
-- free: both its presence and its position are exact.
summaryConditionalFieldNames :: [Text]
summaryConditionalFieldNames = ["Forward-deferred"]

-- | Every field name the summary parser recognises.
summaryParsedFieldNames :: [Text]
summaryParsedFieldNames = summaryFieldNames <> summaryConditionalFieldNames

-- | The two admitted orders: the six unconditional fields, and the same six
-- with @Forward-deferred@ between @Depends on@ and @Gate@. Both are exact; a
-- field anywhere else is still a containment finding.
admittedSummaryFieldOrders :: [[Text]]
admittedSummaryFieldOrders = [summaryFieldNames, before <> summaryConditionalFieldNames <> after]
 where
  (before, after) = break (== "Gate") summaryFieldNames

fieldEntries :: [(Int, Text)] -> [(Int, Text, Text)]
fieldEntries visible = sortOn (\(lineNumber, _, _) -> lineNumber) (concatMap entriesFor summaryParsedFieldNames)
 where
  entriesFor name =
    [ (lineNumber, name, value)
    | (lineNumber, value) <- fieldParagraphs name visible
    ]

summaryFieldLabel :: (Int, Text) -> Maybe Text
summaryFieldLabel (_, line) = do
  afterOpening <- Text.stripPrefix "**" line
  let (label, remainder) = Text.breakOn ":**" afterOpening
  if Text.null label || Text.null remainder
    then Nothing
    else Just label

fieldParagraphs :: Text -> [(Int, Text)] -> [(Int, Text)]
fieldParagraphs name visible = mapMaybe atIndex [0 .. length visible - 1]
 where
  prefix = "**" <> name <> ":**"
  atIndex index = do
    (lineNumber, line) <- atMay visible index
    rest <- Text.stripPrefix prefix line
    let following = takeContinuation (drop (index + 1) visible)
        value = Text.unwords (Text.strip rest : map (Text.strip . snd) following)
    pure (lineNumber, Text.strip value)
  takeContinuation =
    takeWhile
      ( \(_, line) ->
          not (Text.null (Text.strip line))
            && not ("**" `Text.isPrefixOf` Text.stripStart line)
            && not ("## " `Text.isPrefixOf` Text.stripStart line)
      )

sectionBodies :: Text -> [(Int, Text)] -> [[(Int, Text)]]
sectionBodies heading visible = mapMaybe bodyAt [0 .. length visible - 1]
 where
  bodyAt index = do
    (_, line) <- atMay visible index
    if trimAsciiEnd line == heading
      then Just (takeWhile (not . isH2 . snd) (drop (index + 1) visible))
      else Nothing

isH2 :: Text -> Bool
isH2 line = "## " `Text.isPrefixOf` line

data GateFrame = GateFrame
  { gateFrameRows :: [(Text, Text)]
  , gateFrameProblems :: [Text]
  }
  deriving (Eq, Show)

data GateStage
  = GateSeekingHeader
  | GateExpectingDelimiter
  | GateExpectingRow Int
  | GateExpectingEnd
  | GateFinished
  | GateBroken
  deriving (Eq, Show)

data GateScan = GateScan
  { gateScanStage :: GateStage
  , gateScanHeaderCount :: Int
  , gateScanRowsReversed :: [(Text, Text)]
  , gateScanProblemsReversed :: [Text]
  }
  deriving (Eq, Show)

analyzeGateFrame :: [[(Int, Text)]] -> GateFrame
analyzeGateFrame bodies = case bodies of
  [body] -> analyzeBody body
  _ -> GateFrame [] ["exactly one Gate integrity body is required before a table can be parsed"]
 where
  analyzeBody body =
    let scanned = foldl' scanGateLine emptyGateScan body
        completed = finishGateScan scanned
     in GateFrame
          { gateFrameRows = reverse (gateScanRowsReversed completed)
          , gateFrameProblems = reverse (gateScanProblemsReversed completed)
          }

emptyGateScan :: GateScan
emptyGateScan =
  GateScan
    { gateScanStage = GateSeekingHeader
    , gateScanHeaderCount = 0
    , gateScanRowsReversed = []
    , gateScanProblemsReversed = []
    }

scanGateLine :: GateScan -> (Int, Text) -> GateScan
scanGateLine scanned (lineNumber, line)
  | isGateHeader line =
      case gateScanStage scanned of
        GateSeekingHeader ->
          scanned
            { gateScanStage = GateExpectingDelimiter
            , gateScanHeaderCount = 1
            }
        stage ->
          addGateProblem
            ("line " <> showText lineNumber <> ": a second exact gate-table header is not permitted")
            ( scanned
              { gateScanStage = if stage == GateFinished then GateFinished else GateBroken
              , gateScanHeaderCount = gateScanHeaderCount scanned + 1
                }
            )
  | otherwise =
      case gateScanStage scanned of
        GateSeekingHeader ->
          if isGateTableCandidate line
            then
              addGateProblem
                ("line " <> showText lineNumber <> ": a gate-table row occurs before the exact header")
                scanned
            else scanned
        GateExpectingDelimiter ->
          if isGateDelimiter line
            then scanned {gateScanStage = GateExpectingRow 0}
            else
              addGateProblem
                ( "line "
                    <> showText lineNumber
                    <> ": the exact gate header must be followed immediately by '|---|---|'"
                )
                (scanned {gateScanStage = GateBroken})
        GateExpectingRow index ->
          case atMay gateKeys index of
            Nothing -> scanned {gateScanStage = GateExpectingEnd}
            Just expectedKey ->
              case parseExactGateRow expectedKey line of
                Left reason -> handleGateRowFailure scanned lineNumber expectedKey line reason
                Right row ->
                  scanned
                    { gateScanStage =
                        if index + 1 == length gateKeys
                          then GateExpectingEnd
                          else GateExpectingRow (index + 1)
                    , gateScanRowsReversed = row : gateScanRowsReversed scanned
                    }
        GateExpectingEnd ->
          if physicalBlankLine line
            then scanned {gateScanStage = GateFinished}
            else rejectGateTrailingContent scanned lineNumber
        GateFinished ->
          if isGateTableCandidate line
            then rejectOutsideGateRow scanned lineNumber
            else scanned
        GateBroken -> scanned

rejectGateTrailingContent :: GateScan -> Int -> GateScan
rejectGateTrailingContent scanned lineNumber =
  addGateProblem
    ( "line "
        <> showText lineNumber
        <> ": the eighteen-row gate table must end at a physical blank line or section end"
    )
    (scanned {gateScanStage = GateBroken})

rejectOutsideGateRow :: GateScan -> Int -> GateScan
rejectOutsideGateRow scanned lineNumber =
  addGateProblem
    ("line " <> showText lineNumber <> ": a gate-table row occurs outside the single exact frame")
    scanned

handleGateRowFailure :: GateScan -> Int -> Text -> Text -> Text -> GateScan
handleGateRowFailure scanned lineNumber expectedKey line reason =
  ignored `seq` reject
 where
  ignored = legacyIgnorableGateRow line
  reject =
    addGateProblem
      ( "line "
          <> showText lineNumber
          <> ": expected gate row `"
          <> expectedKey
          <> "`; "
          <> reason
      )
      (scanned {gateScanStage = GateBroken})

legacyIgnorableGateRow :: Text -> Bool
legacyIgnorableGateRow line =
  case exactTableCells line of
    Just [keyCell, _] ->
      let key = maybe keyCell id (Text.stripPrefix "`" keyCell >>= Text.stripSuffix "`")
       in Text.null key || key == "Key" || Text.all (`elem` ['-', ':']) key
    _ -> False

finishGateScan :: GateScan -> GateScan
finishGateScan scanned =
  case gateScanStage scanned of
    GateSeekingHeader -> finishGateWithoutHeader scanned
    GateExpectingDelimiter -> finishGateWithoutDelimiter scanned
    GateExpectingRow index -> finishIncompleteGateRows scanned index
    GateExpectingEnd -> scanned {gateScanStage = GateFinished}
    GateFinished -> scanned
    GateBroken -> scanned

finishGateWithoutHeader :: GateScan -> GateScan
finishGateWithoutHeader = addGateProblem "one exact '| Key | Contract |' gate-table header is required"

finishGateWithoutDelimiter :: GateScan -> GateScan
finishGateWithoutDelimiter =
  addGateProblem "the exact gate-table header has no following '|---|---|' delimiter"

finishIncompleteGateRows :: GateScan -> Int -> GateScan
finishIncompleteGateRows scanned index =
  addGateProblem
    ( "the gate table ended after "
        <> showText index
        <> " rows; all eighteen exact ordered rows are required"
    )
    scanned

addGateProblem :: Text -> GateScan -> GateScan
addGateProblem problem scanned =
  scanned {gateScanProblemsReversed = problem : gateScanProblemsReversed scanned}

isGateHeader :: Text -> Bool
isGateHeader line = exactTableCells line == Just gateHeaderCells

isGateDelimiter :: Text -> Bool
isGateDelimiter line = exactTableCells line == Just gateDelimiterCells

gateHeaderCells :: [Text]
gateHeaderCells = ["Key", "Contract"]

gateDelimiterCells :: [Text]
gateDelimiterCells = ["---", "---"]

parseExactGateRow :: Text -> Text -> Either Text (Text, Text)
parseExactGateRow expectedKey line =
  case gateRowCells line of
    Right (keyCell, value)
      | not (gateKeyMatches expectedKey keyCell) ->
          Left ("the key cell must be exactly `" <> expectedKey <> "` including its Markdown code delimiters")
      | gateContractCellEmpty value -> Left "the contract cell is empty"
      | otherwise -> Right (expectedKey, value)
    Left problem -> Left problem

gateRowCells :: Text -> Either Text (Text, Text)
gateRowCells line =
  case exactTableCells line of
    Nothing -> Left "the row must have exact opening and closing pipes on one top-level physical line"
    Just [keyCell, value] -> Right (keyCell, value)
    Just cells -> Left ("the row must have exactly two cells; observed " <> showText (length cells))

gateContractCellEmpty :: Text -> Bool
gateContractCellEmpty = Text.null

gateKeyMatches :: Text -> Text -> Bool
gateKeyMatches expected supplied = supplied == "`" <> expected <> "`"

isGateTableCandidate :: Text -> Bool
isGateTableCandidate = Text.isInfixOf "|"

exactTableCells :: Text -> Maybe [Text]
exactTableCells rawLine = do
  withoutOpen <- stripTableOpeningPipe (trimAsciiEnd rawLine)
  withoutClose <- stripTableClosingPipe withoutOpen
  pure (map trimAscii (Text.splitOn "|" withoutClose))

stripTableOpeningPipe :: Text -> Maybe Text
stripTableOpeningPipe = Text.stripPrefix "|"

stripTableClosingPipe :: Text -> Maybe Text
stripTableClosingPipe = Text.stripSuffix "|"

trimAscii :: Text -> Text
trimAscii = Text.dropWhile asciiWhitespace . trimAsciiEnd

trimAsciiEnd :: Text -> Text
trimAsciiEnd = Text.dropWhileEnd asciiWhitespace

asciiWhitespace :: Char -> Bool
asciiWhitespace character = character == ' ' || character == '\t'

checkPhaseStructure :: SemanticScope -> PhaseDocument -> [Finding]
checkPhaseStructure scope phase =
  titleFindings
    <> statusFindings
    <> summaryFindings
    <> sectionShapeFindings phase
    <> contentsStatusFindings phase
    <> summaryContainmentFindings phase
    <> gateHeadingFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  titleFindings =
    guardedTitleFindings
  guardedTitleFindings =
    [ finding "PLAN-PHASE-TITLE" path ("expected exactly one '# Phase " <> showText number <> ": <title>' heading")
    | phaseTitle phase == Nothing
    ]
  statuses = statusLines phase
  expectedStatus =
    Status.renderPhaseStatusLine
      (Status.phaseStatusAt (statusFrontier scope) number)
  statusBodies = sectionBodies "## Phase Status" (phaseLines phase)
  currentStatusClaims =
    [ Text.strip line
    | body <- statusBodies
    , (_, line) <- body
    , isBareCurrentStatusClaim line
    ]
  additionalStatusFields =
    [ Text.strip line
    | body <- statusBodies
    , (_, line) <- body
    , "**Status**:" `Text.isPrefixOf` Text.stripStart line
    ]
  rawExpectedStatusCount = length (filter (== expectedStatus) (phaseRawLines phase))
  statusFindings =
    guardedStatusFindings
  guardedStatusFindings =
    [ finding
        "PLAN-PHASE-STATUS"
        path
        ("Phase Status must contain exactly one raw canonical current-status line '" <> expectedStatus <> "' and no second bare current-status claim")
    | statuses /= [expectedStatus]
        || currentStatusClaims /= [expectedStatus]
        || not (null additionalStatusFields)
        || rawExpectedStatusCount /= 1
    ]
  summaryFindings =
    guardedSummaryFindings
  guardedSummaryFindings = concatMap checkSummaryField summaryFieldNames
  checkSummaryField name =
    case Map.findWithDefault [] name (phaseFields phase) of
      [value]
        | not (Text.null value) -> []
      _ ->
        [ finding
            "PLAN-SUMMARY-FIELD"
            path
            (name <> " must occur exactly once as a non-empty Phase Summary field")
        ]
  gateHeadings = sectionBodies "## Gate integrity" (phaseLines phase)
  gateHeadingFindings =
    guardedGateHeadingFindings
  guardedGateHeadingFindings =
    [ finding "PLAN-GATE-SECTION" path "exactly one Gate integrity section is required"
    | length gateHeadings /= 1
    ]

sectionShapeFindings :: PhaseDocument -> [Finding]
sectionShapeFindings phase =
  [ finding
      "PLAN-PHASE-SECTION-SHAPE"
      (phasePath phase)
      ( "phase H2 sections must be the exact documented order and cardinality; observed "
          <> Text.intercalate ", " observed
      )
  | observed /= expected
  ]
 where
  observed = phaseSectionHeadings phase
  resources = filter isResourceHeading observed
  sprints = filter (Text.isPrefixOf "## Sprint ") observed
  expected =
    [ "## Contents"
    , "## Phase Status"
    , "## Phase Summary"
    , "## Gate integrity"
    ]
      <> take 1 resources
      <> ["## Doctrine adopted", "## Sprints"]
      <> sprints
      <> ["## Documentation Requirements", "## Related Documents"]
  isResourceHeading heading =
    heading == "## Resource provision"
      || "## Resource provision — " `Text.isPrefixOf` heading

contentsStatusFindings :: PhaseDocument -> [Finding]
contentsStatusFindings phase =
  [ finding
      "PLAN-CONTENTS-STATUS"
      (phasePath phase)
      "Contents navigation is immutable and must not duplicate lifecycle status markers"
  | body <- sectionBodies "## Contents" (phaseLines phase)
  , any (containsStatusMarker . snd) body
  ]
 where
  containsStatusMarker line = any (`Text.isInfixOf` line) ["✅", "🔄", "⏸️"]

summaryContainmentFindings :: PhaseDocument -> [Finding]
summaryContainmentFindings phase =
  [ finding
      "PLAN-SUMMARY-CONTAINMENT"
      (phasePath phase)
      ( "Phase Summary fields must occur inside that section in one of the exact orders "
          <> showText admittedSummaryFieldOrders
          <> "; observed order "
          <> showText (phaseSummaryFieldOrder phase)
          <> "; outside-section fields "
          <> showText (phaseSummaryFieldStrays phase)
      )
  | phaseSummaryFieldOrder phase `notElem` admittedSummaryFieldOrders
      || not (null (phaseSummaryFieldStrays phase))
  ]

statusLines :: PhaseDocument -> [Text]
statusLines phase =
  [ Text.strip line
  | body <- sectionBodies "## Phase Status" (phaseLines phase)
  , (_, line) <- take 1 [(lineNumber, candidate) | (lineNumber, candidate) <- body, not (Text.null (Text.strip candidate))]
  ]

checkDependency :: Map Int PhaseDocument -> PhaseDocument -> [Finding]
checkDependency phases phase =
  case Map.findWithDefault [] "Depends on" (phaseFields phase) of
    [dependency]
      | phaseNumber phase == phaseDomainLowerNumber ->
          genesisFindings dependency
      | otherwise -> checkNumbered dependency
    _ -> []
 where
  number = phaseNumber phase
  genesisFindings dependency =
    guardedGenesisFindings dependency
  guardedGenesisFindings dependency =
    [ finding "PLAN-DEPENDENCY" (phasePath phase) "Phase 0 must depend on genesis only"
    | Text.toCaseFold (Text.strip dependency) /= "genesis"
    ]
  checkNumbered dependency =
    let predecessor = policyPredecessorNumber number
        expectedLabel = "Phase " <> showText predecessor
        (targets, linkProblems) =
          case dependencyLinkTarget expectedLabel dependency of
            Left problem -> ([], [problem])
            Right target -> ([target], [])
        expectedTarget = Text.pack . takeFileName . phasePath <$> Map.lookup predecessor phases
        forward =
          [ targetNumber
          | target <- targets
          , Just targetNumber <- [phaseNumberFromPath ("DEVELOPMENT_PLAN/" <> Text.unpack target)]
          , targetNumber >= number
          ]
     in dependencyLinkFindings linkProblems
          <> predecessorFindings targets expectedTarget predecessor
          <> forwardFindings forward
  dependencyLinkFindings linkProblems =
    guardedDependencyLinkFindings linkProblems
  guardedDependencyLinkFindings linkProblems =
    [ finding
        "PLAN-DEPENDENCY-LINK"
        (phasePath phase)
        ("Depends on is not one structurally valid inline Markdown link: " <> problem)
    | problem <- linkProblems
    ]
  predecessorFindings targets expectedTarget predecessor =
    guardedPredecessorFindings targets expectedTarget predecessor
  guardedPredecessorFindings targets expectedTarget predecessor =
    [ finding
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath phase)
            ("Depends on must contain only one link, to immediate Phase " <> showText predecessor)
    | targets /= maybeToList expectedTarget
    ]
  forwardFindings forward =
    guardedForwardFindings forward
  guardedForwardFindings forward =
    [ finding
        "PLAN-DEPENDENCY-FORWARD"
        (phasePath phase)
        ("Depends on contains a same-or-forward phase edge to Phase " <> showText targetNumber)
    | targetNumber <- forward
    ]

checkGate :: SemanticScope -> PhaseDocument -> [Finding]
checkGate scope phase =
  gateFrameFindings phase
    <> shapeFindings
    <> unresolvedFindings
    <> commandFindings
    <> summaryCommandFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  rows = phaseGateRows phase
  keys = map fst rows
  rowMap = Map.fromList rows
  commandText = "pb validate phase " <> formatPhase number
  expectedCommand = "`" <> commandText <> "`"
  expectedSummaryValue =
    expectedCommand
      <> "; see [Gate integrity](#gate-integrity)."
  expectedSummaryLine = "**Gate:** " <> expectedSummaryValue
  shapeFindings =
    guardedShapeFindings
  guardedShapeFindings =
    [ finding
        "PLAN-GATE-SHAPE"
        path
        ( "Gate table keys must be the exact ordered eighteen-row contract; observed "
            <> Text.intercalate ", " keys
        )
    | keys /= gateKeys
    ]
  unresolvedFindings =
    [ finding
        "PLAN-GATE-UNRESOLVED"
        path
        (key <> " contains a fail-closed UNRESOLVED/MISSING marker")
    | (key, value) <- rows
    , containsRefusalMarker value
    , unresolvedContractIsDue scope number
    ]
  commandFindings =
    guardedCommandFindings
  guardedCommandFindings = case Map.lookup "Command" rowMap of
    Just value ->
      [ finding
          "PLAN-GATE-COMMAND"
          path
          ("Command row must name exactly one canonical " <> expectedCommand)
      | validationCommandSpans value /= [(1, commandText)]
          || gateCommandCountMismatch expectedCommand value
      ]
    Nothing -> []
  summaryCommandFindings =
    guardedSummaryCommandFindings
  guardedSummaryCommandFindings = case Map.findWithDefault [] "Gate" (phaseFields phase) of
    [value] ->
      [ finding
          "PLAN-GATE-SUMMARY-COMMAND"
          path
          ("Gate summary must be the exact immutable command/link form '" <> expectedSummaryLine <> "'")
      | gateSummaryValueMismatch expectedSummaryValue value
          || validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
          || gateSummaryRawLineCountMismatch expectedSummaryLine (phaseRawLines phase)
      ]
    _ -> []

unresolvedContractIsDue :: SemanticScope -> Int -> Bool
unresolvedContractIsDue scope ordinal = case scope of
  StructuralOnly -> True
  GateScope phaseUnderValidation _ -> ordinal <= phaseUnderValidation
  PostPassScope passedPhase _ -> ordinal <= passedPhase
  RecordedScope completedPrefix _ -> ordinal <= completedPrefix

gateCommandCountMismatch :: Text -> Text -> Bool
gateCommandCountMismatch expected value = countOccurrences expected value /= 1

gateSummaryValueMismatch :: Text -> Text -> Bool
gateSummaryValueMismatch = (/=)

gateSummaryRawLineCountMismatch :: Text -> [Text] -> Bool
gateSummaryRawLineCountMismatch expected rawLines =
  length (filter (== expected) rawLines) /= 1

gateFrameFindings :: PhaseDocument -> [Finding]
gateFrameFindings phase =
  [ finding "PLAN-GATE-TABLE-FRAME" (phasePath phase) problem
  | problem <- phaseGateFrameProblems phase
  ]

inlineCodeSpans :: Text -> [(Int, Text)]
inlineCodeSpans = go . Text.unpack
 where
  go [] = []
  go source@('`' : _) =
    let (opening, rest) = span (== '`') source
        width = length opening
     in case close width [] rest of
          Nothing -> []
          Just (contents, remaining) -> (width, Text.pack (reverse contents)) : go remaining
  go (_ : rest) = go rest
  close _ _ [] = Nothing
  close width reversed source@('`' : _) =
    let (candidate, rest) = span (== '`') source
     in if length candidate == width
          then Just (reversed, rest)
          else close width (reverse candidate <> reversed) rest
  close width reversed (character : rest) = close width (character : reversed) rest

validationCommandSpans :: Text -> [(Int, Text)]
validationCommandSpans =
  filter (Text.isPrefixOf "pb validate" . Text.toCaseFold . snd) . inlineCodeSpans

containsRefusalMarker :: Text -> Bool
containsRefusalMarker value = containsUnresolvedMarker value || containsMissingMarker value

containsUnresolvedMarker :: Text -> Bool
containsUnresolvedMarker = Text.isInfixOf "UNRESOLVED"

containsMissingMarker :: Text -> Bool
containsMissingMarker value =
  "`MISSING`" `Text.isInfixOf` value
    || "MISSING —" `Text.isInfixOf` value
    || "MISSING:" `Text.isInfixOf` value

gateKeys :: [Text]
gateKeys =
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

checkSprintContracts :: Map Int PhaseDocument -> SemanticScope -> Bool -> PhaseDocument -> [Finding]
checkSprintContracts phases scope enforceCanonicalInventory phase =
  inventoryFindings <> concatMap checkSection sprintSections
 where
  sprintSections = sprintSectionsFor phase
  parsedOrdinals = map (parseSprintOrdinal (phaseNumber phase) . fst) sprintSections
  -- Sprint identities must be contiguous from one.  This is a property of the
  -- document being checked, not a count recorded centrally: a per-phase sprint
  -- census made adding or removing a sprint anywhere in the plan a
  -- documentation-suite refusal, and because the gate chain re-derives gate 0
  -- inside every later phase's gate, ordinary planning work owned by another
  -- phase reopened a closed Phase 0.
  expectedOrdinals = [1 .. length parsedOrdinals]
  inventoryFindings =
    guardedInventoryFindings
  guardedInventoryFindings =
    [ finding
        "PLAN-SPRINT-INVENTORY"
        (phasePath phase)
        ( "sprint identities must be contiguous from one; expected "
            <> showText (map Just expectedOrdinals)
            <> ", observed "
            <> showText parsedOrdinals
        )
    | enforceCanonicalInventory && parsedOrdinals /= map Just expectedOrdinals
    ]
  checkSection (heading, body) =
    let ordinal = parseSprintOrdinal (phaseNumber phase) heading
        statusEntries =
          [ (lineNumber, Text.strip value)
          | (lineNumber, line) <- body
          , Just value <- [Text.stripPrefix "**Status**:" line]
          ]
        statuses = map snd statusEntries
        expectedStatus = expectedSprintStatus scope (phaseNumber phase) <$> ordinal
        expectedMarker = expectedSprintMarker scope (phaseNumber phase) <$> ordinal
        observedMarker = sprintHeadingMarker <$> parseSprintHeading (phaseNumber phase) heading
        bareStatusClaims = [Text.strip line | (_, line) <- body, isBareCurrentStatusClaim line]
        rawStatusIsCanonical = case expectedStatus of
          Nothing -> False
          Just expected ->
            case statusEntries of
              [(lineNumber, _)] -> atMay (phaseRawLines phase) (lineNumber - 1) == Just ("**Status**: " <> expected)
              _ -> False
        guardedSprintStatusFindings =
          [ finding
              "PLAN-SPRINT-STATUS"
              (phasePath phase)
              ( Text.strip heading
                  <> " must contain exactly the recorded reset status "
                  <> maybe "for a valid sprint ordinal" ("'" <>) ((<> "'") <$> expectedStatus)
              )
          | case expectedStatus of
              Just expected ->
                statuses /= [expected]
                  || not rawStatusIsCanonical
                  || not (null bareStatusClaims)
                  || observedMarker /= expectedMarker
              Nothing -> True
          ]
        sprintStatusFindings =
          guardedSprintStatusFindings
        sprintIdentityFindings =
          guardedSprintIdentityFindings
        guardedSprintIdentityFindings =
          [ finding
            "PLAN-SPRINT-IDENTITY"
            (phasePath phase)
            ("sprint heading is not the exact current-phase identity/title/status-marker form: " <> Text.strip heading)
          | parseSprintHeading (phaseNumber phase) heading == Nothing
          ]
     in sprintIdentityFindings
          <> sprintStatusFindings
          <> sprintSchemaFindings phase heading body
          <> sprintBlockerFindings phases phase heading body

data SprintHeading = SprintHeading
  { sprintHeadingOrdinal :: Int
  , sprintHeadingTitle :: Text
  , sprintHeadingMarker :: Text
  }
  deriving (Eq, Show)

parseSprintHeading :: Int -> Text -> Maybe SprintHeading
parseSprintHeading owner heading = do
  remainder <- sprintHeadingPrefix owner (trimAsciiEnd heading)
  let (digits, afterDigits) = Text.span isDigit remainder
  ordinal <- readMaybe (Text.unpack digits)
  if sprintHeadingOrdinalCanonical digits ordinal && sprintHeadingOrdinalPositive ordinal
    then pure ()
    else Nothing
  afterColon <- sprintHeadingSeparator afterDigits
  (title, marker) <-
    listToMaybe
      [ (Text.strip candidateTitle, candidateMarker)
      | candidateMarker <- sprintHeadingMarkers
      , Just candidateTitle <- [Text.stripSuffix (" " <> candidateMarker) afterColon]
      , sprintHeadingTitleNonEmpty candidateTitle
      ]
  pure (SprintHeading ordinal title marker)

sprintHeadingPrefix :: Int -> Text -> Maybe Text
sprintHeadingPrefix owner = Text.stripPrefix ("## Sprint " <> showText owner <> ".")

sprintHeadingOrdinalCanonical :: Text -> Int -> Bool
sprintHeadingOrdinalCanonical digits ordinal = digits == showText ordinal

sprintHeadingOrdinalPositive :: Int -> Bool
sprintHeadingOrdinalPositive = (> 0)

sprintHeadingSeparator :: Text -> Maybe Text
sprintHeadingSeparator = Text.stripPrefix ": "

sprintHeadingMarkers :: [Text]
sprintHeadingMarkers = currentStatusMarkers

sprintHeadingTitleNonEmpty :: Text -> Bool
sprintHeadingTitleNonEmpty = not . Text.null . Text.strip

sprintFieldNames :: [Text]
sprintFieldNames =
  [ "Status"
  , "Implementation"
  , "Blocked by"
  , "Forward-deferred"
  , "Requires"
  , "Independent Validation"
  , "Oracle"
  , "Legacy IDs"
  , "Docs to update"
  ]

optionalSprintFieldNames :: [Text]
optionalSprintFieldNames = ["Forward-deferred", "Requires"]

sprintSubsectionNames :: [Text]
sprintSubsectionNames = ["Objective", "Deliverables", "Validation", "Remaining Work"]

sprintFieldEntry :: (Int, Text) -> Maybe (Int, Text, Text)
sprintFieldEntry (lineNumber, line) = do
  afterOpening <- Text.stripPrefix "**" line
  let (label, remainder) = Text.breakOn "**:" afterOpening
  value <- Text.stripPrefix "**:" remainder
  if Text.null label
    then Nothing
    else Just (lineNumber, label, Text.strip value)

sprintSchemaFindings :: PhaseDocument -> Text -> [(Int, Text)] -> [Finding]
sprintSchemaFindings phase heading body =
  schemaFindings
 where
  schemaFindings =
    [ finding
        "PLAN-SPRINT-SCHEMA"
        (phasePath phase)
        ( Text.strip heading
            <> " must contain the exact ordered mandatory field set and four non-empty ordered subsections; observed fields "
            <> showText observedFieldNames
            <> ", observed subsections "
            <> showText observedSubsections
        )
    | not schemaSatisfied
    ]
  firstSubsectionIndex = maybe (length body) id (findIndex (isH3 . snd) body)
  (preamble, laterBody) = splitAt firstSubsectionIndex body
  preambleEntries = mapMaybe sprintFieldEntry preamble
  laterKnownEntries =
    [ name
    | (_, name, _) <- mapMaybe sprintFieldEntry laterBody
    , name `elem` sprintFieldNames
    ]
  observedFieldNames = [name | (_, name, _) <- preambleEntries]
  expectedFieldNames =
    [ name
    | name <- sprintFieldNames
    , name `notElem` optionalSprintFieldNames || name `elem` observedFieldNames
    ]
  nonEmptyFields = all (not . Text.null . third) preambleEntries
  observedSubsections = [Text.strip line | (_, line) <- body, isH3 line]
  expectedSubsections = map ("### " <>) sprintSubsectionNames
  nonEmptySubsections = all (hasNonEmptySubsection body) expectedSubsections
  schemaSatisfied =
    sprintSchemaFieldOrderValid observedFieldNames expectedFieldNames
      && sprintSchemaFieldsNonEmpty nonEmptyFields
      && sprintSchemaLaterFieldsAbsent laterKnownEntries
      && sprintSchemaSubsectionOrderValid observedSubsections expectedSubsections
      && sprintSchemaSubsectionsNonEmpty nonEmptySubsections
  third (_, _, value) = value

sprintSchemaFieldOrderValid :: [Text] -> [Text] -> Bool
sprintSchemaFieldOrderValid = (==)

sprintSchemaFieldsNonEmpty :: Bool -> Bool
sprintSchemaFieldsNonEmpty = id

sprintSchemaLaterFieldsAbsent :: [Text] -> Bool
sprintSchemaLaterFieldsAbsent = null

sprintSchemaSubsectionOrderValid :: [Text] -> [Text] -> Bool
sprintSchemaSubsectionOrderValid = (==)

sprintSchemaSubsectionsNonEmpty :: Bool -> Bool
sprintSchemaSubsectionsNonEmpty = id

isH3 :: Text -> Bool
isH3 line = "### " `Text.isPrefixOf` line && not ("#### " `Text.isPrefixOf` line)

hasNonEmptySubsection :: [(Int, Text)] -> Text -> Bool
hasNonEmptySubsection body heading = case findIndex ((== heading) . trimAsciiEnd . snd) body of
  Nothing -> False
  Just index ->
    any
      (not . Text.null . Text.strip . snd)
      (takeWhile (not . startsSection . snd) (drop (index + 1) body))
 where
  startsSection line = isH2 line || isH3 line

sprintBlockerFindings :: Map Int PhaseDocument -> PhaseDocument -> Text -> [(Int, Text)] -> [Finding]
sprintBlockerFindings phases phase heading body =
  [ finding
      "PLAN-SPRINT-BLOCKER"
      (phasePath phase)
      (Text.strip heading <> " must equal its one canonical immediate prior plan edge with no appended dependency or check prose")
  | not blockerSatisfied
  ]
 where
  owner = phaseNumber phase
  ordinal = parseSprintOrdinal owner heading
  entries =
    [ value
    | (_, name, value) <- mapMaybe sprintFieldEntry (takeWhile (not . isH3 . snd) body)
    , name == "Blocked by"
    ]
  blockerSatisfied = case (ordinal, entries) of
    (Just 1, [value])
      | owner == phaseDomainLowerNumber ->
          sprintGenesisBlockerValid value
      | otherwise ->
          let predecessor = policyPredecessorNumber owner
              linkedEdge = do
                predecessorPhase <- Map.lookup predecessor phases
                pure
                  ( "[Phase "
                      <> showText predecessor
                      <> "](" <> Text.pack (takeFileName (phasePath predecessorPhase))
                      <> ") gate pass"
                  )
           in sprintPredecessorBlockerValid value linkedEdge
    (Just sprintOrdinal, [value]) ->
      sprintPriorSprintBlockerValid owner sprintOrdinal value
    _ -> False

sprintGenesisBlockerValid :: Text -> Bool
sprintGenesisBlockerValid value = Text.strip value == "`genesis`"

sprintPredecessorBlockerValid :: Text -> Maybe Text -> Bool
sprintPredecessorBlockerValid value linkedEdge = Text.strip value `elem` maybeToList linkedEdge

sprintPriorSprintBlockerValid :: Int -> Int -> Text -> Bool
sprintPriorSprintBlockerValid owner sprintOrdinal value =
  Text.strip value == "Sprint " <> showText owner <> "." <> showText (sprintOrdinal - 1)

isBareCurrentStatusClaim :: Text -> Bool
isBareCurrentStatusClaim line =
  Text.toCaseFold (Text.dropWhileEnd (== '.') (Text.strip (stripStatusIcon (Text.strip line))))
    `elem` map Text.toCaseFold currentStatusBodies
 where
  currentStatusBodies =
    [ "Done"
    , "Active — NOT VALIDATED"
    , "Planned — NOT VALIDATED"
    , "Blocked — NOT VALIDATED"
    , "Live-proof pending — NOT VALIDATED"
    ]

currentStatusMarkers :: [Text]
currentStatusMarkers = ["✅", "🔄", "⏸️"]

-- Retired markers remain recognizable as competing status claims, but cannot
-- become admissible sprint-heading markers through that broader detector.
statusClaimMarkers :: [Text]
statusClaimMarkers = currentStatusMarkers <> ["📋", "🧪"]

stripStatusIcon :: Text -> Text
stripStatusIcon value =
  case
      [ Text.stripStart rest
      | icon <- statusClaimMarkers <> ["❌", "🟢", "🔴"]
      , Just rest <- [Text.stripPrefix icon value]
      ] of
    stripped : _ -> stripped
    [] -> value

sprintSectionsFor :: PhaseDocument -> [(Text, [(Int, Text)])]
sprintSectionsFor phase =
    [ (heading, takeWhile (not . isH2 . snd) (drop (index + 1) (phaseLines phase)))
    | index <- [0 .. length (phaseLines phase) - 1]
    , Just (_, heading) <- [atMay (phaseLines phase) index]
    , "## Sprint " `Text.isPrefixOf` heading
    ]

parseSprintOrdinal :: Int -> Text -> Maybe Int
parseSprintOrdinal owner = fmap sprintHeadingOrdinal . parseSprintHeading owner

expectedSprintStatus :: SemanticScope -> Int -> Int -> Text
expectedSprintStatus scope phaseNumberValue sprintNumber =
  Status.renderSprintStatus
    (Status.sprintStatusAt (statusFrontier scope) phaseNumberValue sprintNumber)

expectedSprintMarker :: SemanticScope -> Int -> Int -> Text
expectedSprintMarker scope phaseNumberValue sprintNumber =
  Status.renderStatusMarker
    (Status.sprintStatusAt (statusFrontier scope) phaseNumberValue sprintNumber)

parseTrackerDocument :: Text -> TrackerFrame
parseTrackerDocument contents =
  let scanned = foldl' scanTrackerLine emptyTrackerScan (lexPlanLines contents)
      completed = finishTrackerScan scanned
   in TrackerFrame
        { trackerFrameRows = reverse (trackerScanRowsReversed completed)
        , trackerFrameProblems = reverse (trackerScanProblemsReversed completed)
        }

emptyTrackerScan :: TrackerScan
emptyTrackerScan =
  TrackerScan
    { trackerScanStage = TrackerSeekingHeader
    , trackerScanHeaderCount = 0
    , trackerScanRowsReversed = []
    , trackerScanProblemsReversed = []
    }

scanTrackerLine :: TrackerScan -> PlanLine -> TrackerScan
scanTrackerLine scanned planLine =
  case planLine of
    StructuralLine lineNumber line
      | isTrackerHeader line ->
          case trackerScanStage scanned of
            TrackerSeekingHeader ->
              scanned
                { trackerScanStage = TrackerExpectingDelimiter
                , trackerScanHeaderCount = 1
                }
            stage ->
              addTrackerProblem
                ("line " <> showText lineNumber <> ": a second exact tracker header is not permitted")
                ( scanned
                  { trackerScanStage = if stage == TrackerFinished then TrackerFinished else TrackerBroken
                  , trackerScanHeaderCount = trackerScanHeaderCount scanned + 1
                    }
                )
      | otherwise -> scanNonHeaderTrackerLine scanned lineNumber line
    OpaqueBoundary lineNumber -> scanTrackerBoundary scanned lineNumber

scanNonHeaderTrackerLine :: TrackerScan -> Int -> Text -> TrackerScan
scanNonHeaderTrackerLine scanned lineNumber line =
  case trackerScanStage scanned of
    TrackerSeekingHeader -> scanSeekingTrackerLine scanned lineNumber line
    TrackerExpectingDelimiter ->
      if isTrackerDelimiter line
        then scanned {trackerScanStage = TrackerExpectingRow phaseDomainLowerNumber}
        else
          addTrackerProblem
            ( "line "
                <> showText lineNumber
                <> ": the exact tracker header must be followed immediately by the exact seven-cell delimiter"
            )
            (scanned {trackerScanStage = TrackerBroken})
    TrackerExpectingRow expectedNumber ->
      case parseExactTrackerRow expectedNumber line of
        Left reason ->
          addTrackerProblem
            ( "line "
                <> showText lineNumber
                <> ": expected canonical tracker row for Phase "
                <> showText expectedNumber
                <> "; "
                <> reason
            )
            (scanned {trackerScanStage = TrackerBroken})
        Right row ->
          scanned
            { trackerScanStage =
                maybe TrackerExpectingEnd TrackerExpectingRow (PhaseIdentity.successorOrdinal expectedNumber)
            , trackerScanRowsReversed = row : trackerScanRowsReversed scanned
            }
    TrackerExpectingEnd ->
      if physicalBlankLine line
        then scanned {trackerScanStage = TrackerFinished}
        else rejectTrackerTrailingContent scanned lineNumber
    TrackerFinished ->
      if isTrackerRawCandidate line
        then rejectOutsideTrackerRow scanned lineNumber
        else scanned
    TrackerBroken -> scanned

rejectTrackerTrailingContent :: TrackerScan -> Int -> TrackerScan
rejectTrackerTrailingContent scanned lineNumber =
  addTrackerProblem
    ( "line "
        <> showText lineNumber
        <> ": the " <> showText (length PhaseIdentity.phaseOrdinals) <> "-row tracker table must end at a physical blank line or end of file"
    )
    (scanned {trackerScanStage = TrackerBroken})

rejectOutsideTrackerRow :: TrackerScan -> Int -> TrackerScan
rejectOutsideTrackerRow scanned lineNumber =
  addTrackerProblem
    ("line " <> showText lineNumber <> ": a tracker candidate occurs outside the single exact frame")
    scanned

scanSeekingTrackerLine :: TrackerScan -> Int -> Text -> TrackerScan
scanSeekingTrackerLine scanned lineNumber line =
  if isTrackerRawCandidate line
    then
      addTrackerProblem
        ("line " <> showText lineNumber <> ": a seven-cell tracker candidate occurs before the exact header")
        scanned
    else scanned

scanTrackerBoundary :: TrackerScan -> Int -> TrackerScan
scanTrackerBoundary scanned lineNumber =
  case trackerScanStage scanned of
    TrackerExpectingDelimiter -> interruptTrackerDelimiterBoundary scanned lineNumber
    TrackerExpectingRow expectedNumber -> interruptTrackerRowBoundary scanned lineNumber expectedNumber
    TrackerExpectingEnd -> interruptTrackerEndBoundary scanned lineNumber
    _ -> scanned

interruptTrackerDelimiterBoundary :: TrackerScan -> Int -> TrackerScan
interruptTrackerDelimiterBoundary scanned lineNumber =
  interruptTrackerBoundary scanned lineNumber "delimiter"

interruptTrackerRowBoundary :: TrackerScan -> Int -> Int -> TrackerScan
interruptTrackerRowBoundary scanned lineNumber expectedNumber =
  interruptTrackerBoundary scanned lineNumber ("Phase " <> showText expectedNumber <> " row")

interruptTrackerEndBoundary :: TrackerScan -> Int -> TrackerScan
interruptTrackerEndBoundary scanned lineNumber =
  interruptTrackerBoundary scanned lineNumber "physical table terminator"

interruptTrackerBoundary :: TrackerScan -> Int -> Text -> TrackerScan
interruptTrackerBoundary scanned lineNumber expected =
  addTrackerProblem
    ( "line "
        <> showText lineNumber
        <> ": an opaque Markdown boundary interrupts the expected tracker "
        <> expected
    )
    (scanned {trackerScanStage = TrackerBroken})

finishTrackerScan :: TrackerScan -> TrackerScan
finishTrackerScan scanned =
  case trackerScanStage scanned of
    TrackerSeekingHeader -> finishTrackerWithoutHeader scanned
    TrackerExpectingDelimiter -> finishTrackerWithoutDelimiter scanned
    TrackerExpectingRow expectedNumber -> finishIncompleteTrackerRows scanned expectedNumber
    TrackerExpectingEnd -> scanned {trackerScanStage = TrackerFinished}
    TrackerFinished -> scanned
    TrackerBroken -> scanned

finishTrackerWithoutHeader :: TrackerScan -> TrackerScan
finishTrackerWithoutHeader =
  addTrackerProblem
    "one exact '| Phase | Name | Substrate | Lane | Register | Status | Validation contract |' tracker header is required"

finishTrackerWithoutDelimiter :: TrackerScan -> TrackerScan
finishTrackerWithoutDelimiter =
  addTrackerProblem "the exact tracker header has no following seven-cell delimiter"

finishIncompleteTrackerRows :: TrackerScan -> Int -> TrackerScan
finishIncompleteTrackerRows scanned expectedNumber =
  addTrackerProblem
    ( "the tracker table ended before canonical Phase "
        <> showText expectedNumber
        <> "; exact ordered rows " <> phaseDomainLabel <> " are required"
    )
    scanned

addTrackerProblem :: Text -> TrackerScan -> TrackerScan
addTrackerProblem problem scanned =
  scanned {trackerScanProblemsReversed = problem : trackerScanProblemsReversed scanned}

isTrackerHeader :: Text -> Bool
isTrackerHeader line = exactTableCells line == Just trackerHeaderCells

trackerHeaderCells :: [Text]
trackerHeaderCells =
  [ "Phase"
  , "Name"
  , "Substrate"
  , "Lane"
  , "Register"
  , "Status"
  , "Validation contract"
  ]

isTrackerDelimiter :: Text -> Bool
isTrackerDelimiter line = exactTableCells line == Just (replicate 7 "---")

isTrackerRawCandidate :: Text -> Bool
isTrackerRawCandidate line =
  case firstPipeCell line of
    Just "Phase" -> pipeCount >= 7
    Just ordinal ->
      pipeCount >= 7
        && maybe False (const True) (readMaybe (Text.unpack ordinal) :: Maybe Integer)
    Nothing -> False
 where
  pipeCount = Text.count "|" line

firstPipeCell :: Text -> Maybe Text
firstPipeCell rawLine =
  let line = trimAscii rawLine
      afterOpen = maybe line id (Text.stripPrefix "|" line)
      (firstCell, remainder) = Text.breakOn "|" afterOpen
   in if Text.null remainder then Nothing else Just (trimAscii firstCell)

parseExactTrackerRow :: Int -> Text -> Either Text TrackerRow
parseExactTrackerRow expectedNumber line =
  case trackerRowCells line of
    Left problem -> Left problem
    Right [number, title, substrate, lane, register, status, contract] -> do
      parsedNumber <- trackerRowOrdinal expectedNumber number
      if trackerRequiredCellEmpty [title, substrate, lane, register, status, contract]
        then Left "one or more required tracker cells are empty"
        else
          if trackerLinkTarget contract == Nothing
            then Left "the Validation contract cell must be exactly one closed Markdown link with no surrounding prose or title"
            else
              Right
                TrackerRow
                  { trackerNumber = parsedNumber
                  , trackerTitle = title
                  , trackerSubstrate = stripExactWrappingCode substrate
                  , trackerLane = stripExactWrappingCode lane
                  , trackerRegister = stripExactWrappingCode register
                  , trackerStatus = status
                  , trackerContract = contract
                  }
    Right cells -> Left ("internal tracker row arity mismatch: " <> showText (length cells))

trackerRequiredCellEmpty :: [Text] -> Bool
trackerRequiredCellEmpty = any Text.null

trackerRowCells :: Text -> Either Text [Text]
trackerRowCells line =
  case exactTableCells line of
    Nothing -> Left "the row must have exact opening and closing pipes on one top-level physical line"
    Just cells -> selectCells cells
 where
  selectCells cells
    | length cells == 7 = Right cells
    | otherwise = Left ("the row must have exactly seven cells; observed " <> showText (length cells))

trackerRowOrdinal :: Int -> Text -> Either Text Int
trackerRowOrdinal expectedNumber supplied
  | supplied == showText expectedNumber = Right expectedNumber
  | otherwise =
      Left
        ( "the ordinal must be the canonical unsigned spelling '"
            <> showText expectedNumber
            <> "' with no leading zeroes"
        )

stripExactWrappingCode :: Text -> Text
stripExactWrappingCode value =
  case Text.stripPrefix "`" value >>= Text.stripSuffix "`" of
    Just unquoted
      | not (Text.null unquoted)
      , not ("`" `Text.isInfixOf` unquoted) -> unquoted
    _ -> value

trackerLinkTarget :: Text -> Maybe Text
trackerLinkTarget value =
  markdownTargets value `seq` case exactClosedMarkdownLink value of
    Just ("Contract", target) -> Just target
    _ -> Nothing

dependencyLinkTarget :: Text -> Text -> Either Text Text
dependencyLinkTarget expectedLabel value =
  markdownTargets value `seq` case exactClosedMarkdownLink value of
    Just (label, target)
      | label == expectedLabel -> Right target
    _ ->
      Left
        ( "the complete field value must be exactly one closed Markdown link labelled '"
            <> expectedLabel
            <> "' with no surrounding prose or title"
        )

exactClosedMarkdownLink :: Text -> Maybe (Text, Text)
exactClosedMarkdownLink value = do
  afterLabelOpen <- Text.stripPrefix "[" value
  let (label, afterLabel) = Text.breakOn "](" afterLabelOpen
  afterTargetOpen <- Text.stripPrefix "](" afterLabel
  let (target, afterTarget) = Text.breakOn ")" afterTargetOpen
  if not (exactLinkTargetNonEmpty target)
      || not (exactLinkTrailingContentClosed afterTarget)
      || not (Text.all isCanonicalLinkTargetCharacter target)
    then Nothing
    else Just (label, target)

exactLinkTargetNonEmpty :: Text -> Bool
exactLinkTargetNonEmpty = not . Text.null

exactLinkTrailingContentClosed :: Text -> Bool
exactLinkTrailingContentClosed = (== ")")

isCanonicalLinkTargetCharacter :: Char -> Bool
isCanonicalLinkTargetCharacter character =
  isAlphaNum character || character `elem` ['/', '.', '_', '-', '#']

checkTrackerShape :: SemanticScope -> [TrackerRow] -> [Finding]
checkTrackerShape scope rows =
  missingFindings <> statusFindings
 where
  actual = Set.fromList (map trackerNumber rows)
  expected = Set.fromList PhaseIdentity.phaseOrdinals
  missingFindings =
    guardedMissingFindings
  guardedMissingFindings =
    [ finding "PLAN-TRACKER-MISSING" trackerPath ("tracker omits Phase " <> showText number)
    | number <- Set.toAscList (expected Set.\\ actual)
    ]
  statusFindings =
    guardedStatusFindings
  guardedStatusFindings = concatMap checkStatus rows
  checkStatus row =
    let expectedStatus =
          Status.renderTrackerStatus
            (Status.phaseStatusAt (statusFrontier scope) (trackerNumber row))
     in [ finding
            "PLAN-TRACKER-STATUS"
            trackerPath
            ("Phase " <> showText (trackerNumber row) <> " tracker status must equal '" <> expectedStatus <> "'")
        | Text.strip (trackerStatus row) /= expectedStatus
        ]

checkTrackerJoin :: Map Int PhaseDocument -> [TrackerRow] -> [Finding]
checkTrackerJoin phases rows = concatMap checkRow rows
 where
  checkRow row = case Map.lookup (trackerNumber row) phases of
    Nothing -> []
    Just phase ->
      titleFinding phase row
        <> contractFinding phase row
        <> projectionFinding phase row "Substrate" trackerSubstrate
        <> projectionFinding phase row "Lane" trackerLane
        <> projectionFinding phase row "Register" trackerRegister
  titleFinding phase row =
    guardedTitleFinding phase row
  guardedTitleFinding phase row =
    [ finding
        "PLAN-TRACKER-TITLE"
        trackerPath
        ("Phase " <> showText (trackerNumber row) <> " tracker name differs from its H1 title")
    | phaseTitle phase /= Just (trackerTitle row)
    ]
  contractFinding phase row =
    guardedContractFinding phase row
  guardedContractFinding phase row =
    let suppliedTarget = trackerLinkTarget (trackerContract row)
        expectedTarget = Text.pack (takeFileName (phasePath phase))
     in [ finding
            "PLAN-TRACKER-CONTRACT"
            trackerPath
            ("Phase " <> showText (trackerNumber row) <> " must contain one structurally valid link to " <> Text.pack (phasePath phase))
        | suppliedTarget /= Just expectedTarget
        ]
  projectionFinding phase row field accessor =
    guardedProjectionFinding phase row field accessor
  guardedProjectionFinding phase row field accessor =
    case Map.findWithDefault [] field (phaseFields phase) of
      [value] ->
        [ finding
            "PLAN-TRACKER-PROJECTION"
            trackerPath
            ( "Phase "
                <> showText (trackerNumber row)
                <> " "
                <> field
                <> " differs between tracker and contract"
            )
        | not (trackerProjectionMatches value (accessor row))
        ]
      _ -> []

trackerProjectionMatches :: Text -> Text -> Bool
trackerProjectionMatches phaseValue trackerValue = firstToken phaseValue == trackerValue

checkProjectionVocabulary :: Map Int PhaseDocument -> [TrackerRow] -> [Finding]
checkProjectionVocabulary phases rows =
  vocabularyFindings
 where
  vocabularyFindings = concatMap checkPhase (Map.elems phases) <> concatMap checkTracker rows
  checkPhase phase =
    checkPhaseValue (phasePath phase) "Substrate" substrateVocabulary (phaseValue phase "Substrate")
      <> checkPhaseValue (phasePath phase) "Lane" laneVocabulary (phaseValue phase "Lane")
      <> checkPhaseValue (phasePath phase) "Register" registerVocabulary (phaseValue phase "Register")
      <> checkPair
        (phasePath phase)
        (closedVocabularyToken <$> phaseValue phase "Substrate")
        (closedVocabularyToken <$> phaseValue phase "Lane")
  checkTracker row =
    checkTrackerValue trackerPath (phaseLabel row "Substrate") substrateVocabulary (trackerSubstrate row)
      <> checkTrackerValue trackerPath (phaseLabel row "Lane") laneVocabulary (trackerLane row)
      <> checkTrackerValue trackerPath (phaseLabel row "Register") registerVocabulary (trackerRegister row)
      <> checkPair
        (Text.unpack (phaseLabel row "Substrate/Lane"))
        (Just (trackerSubstrate row))
        (Just (trackerLane row))
  checkPair subject substrate lane =
    [ finding
        "PLAN-SUBSTRATE-LANE-PAIR"
        subject
        ( "lane "
            <> showText observedLane
            <> " is not admissible on substrate "
            <> showText observedSubstrate
            <> "; a phase declares at most one specialized substrate, so a specialized lane pins"
            <> " exactly the substrate that provides it"
        )
    | Just observedSubstrate <- [substrate]
    , Just observedLane <- [lane]
    , observedSubstrate `elem` substrateVocabulary
    , observedLane `elem` laneVocabulary
    , not (laneAdmissibleOn observedSubstrate observedLane)
    ]
  phaseValue phase field = case Map.findWithDefault [] field (phaseFields phase) of
    [value] -> Just value
    _ -> Nothing
  phaseLabel row field = "Phase " <> showText (trackerNumber row) <> " " <> field
  checkPhaseValue subject field vocabulary supplied =
    [ finding
        "PLAN-PROJECTION-VOCABULARY"
        subject
        (field <> " must begin with one closed vocabulary value " <> showText vocabulary)
    | maybe True ((`notElem` vocabulary) . closedVocabularyToken) supplied
    ]
  checkTrackerValue subject field vocabulary supplied =
    [ finding
        "PLAN-PROJECTION-VOCABULARY"
        subject
        (field <> " must be exactly one closed vocabulary value " <> showText vocabulary)
    | supplied `notElem` vocabulary
    ]

substrateVocabulary :: [Text]
substrateVocabulary = ["none", "apple", "linux-cpu", "linux-cuda", "windows"]

laneVocabulary :: [Text]
laneVocabulary = ["none", "linux-cpu/amd64", "linux-cpu/arm64", "metal", "cuda", "provider"]

-- | Which lanes a substrate can carry.
--
-- Substrate and lane were each checked against a closed vocabulary but never
-- against each other, so @apple@ paired with @cuda@, or @windows@ with
-- @metal@, passed. Either pair would need two specialized machines for one
-- gate, which is what
-- @development_plan_phase_model.md@ section L forecloses when it says a phase
-- "declares exactly one" substrate "plus its natural lane".
--
-- A specialized lane therefore pins exactly the substrate that provides it:
-- @metal@ only on @apple@, @cuda@ only on @linux-cuda@. A baseline lane pins
-- the natural architecture instead, and never a second specialized substrate:
-- Lima gives Apple @arm64@, WSL2 gives Windows @amd64@, Incus gives Linux and
-- Linux-CUDA their own. @provider@ is a managed target driven from one
-- @linux-cpu@ parent rather than a substrate of its own.
laneAdmissibleOn :: Text -> Text -> Bool
laneAdmissibleOn substrate lane = case lane of
  "none" -> substrate == "none"
  "metal" -> substrate == "apple"
  "cuda" -> substrate == "linux-cuda"
  "provider" -> substrate == "linux-cpu"
  "linux-cpu/arm64" -> substrate `elem` ["apple", "linux-cpu"]
  "linux-cpu/amd64" -> substrate `elem` ["linux-cpu", "linux-cuda", "windows"]
  _ -> False

registerVocabulary :: [Text]
registerVocabulary = ["—", "1", "2", "3"]

closedVocabularyToken :: Text -> Text
closedVocabularyToken =
  Text.toCaseFold
    . Text.takeWhile (\character -> not (isSpace character) && character `notElem` ['`', ';', ','])
    . Text.dropWhile (\character -> isSpace character || character == '`')

firstToken :: Text -> Text
firstToken =
  Text.toCaseFold
    . Text.takeWhile (\character -> not (isSpace character) && character `notElem` ['`', '.', ';', ','])
    . Text.dropWhile (\character -> isSpace character || character == '`')

markdownTargets :: Text -> ([Text], [Text])
markdownTargets = go
 where
  go source =
    let (before, marker) = Text.breakOn "](" source
     in if Text.null marker
          then ([], [])
          else
            let afterMarker = Text.drop 2 marker
             in if escapedAtEnd before
                  then go afterMarker
                  else
                    if openBracketDepth before == 0
                      then
                        let (laterTargets, laterProblems) = go afterMarker
                         in (laterTargets, "orphan ](" : laterProblems)
                      else case takeBalancedDestination afterMarker of
                        Nothing -> ([], ["unbalanced link destination"])
                        Just (rawTarget, remaining) ->
                          let target = Text.takeWhile (not . isSpace) (Text.strip rawTarget)
                              (laterTargets, laterProblems) = go remaining
                           in if Text.null target
                                then (laterTargets, "empty link destination" : laterProblems)
                                else (target : laterTargets, laterProblems)

takeBalancedDestination :: Text -> Maybe (Text, Text)
takeBalancedDestination = go (1 :: Int) False [] . Text.unpack
 where
  go _ _ _ [] = Nothing
  go depth escaped reversed (character : rest)
    | escaped = go depth False (character : reversed) rest
    | character == '\\' = go depth True (character : reversed) rest
    | character == '(' = go (depth + 1) False (character : reversed) rest
    | character == ')' =
        if depth == 1
          then Just (Text.pack (reverse reversed), Text.pack rest)
          else go (depth - 1) False (character : reversed) rest
    | otherwise = go depth False (character : reversed) rest

openBracketDepth :: Text -> Int
openBracketDepth = go 0 False . Text.unpack
 where
  go depth _ [] = depth
  go depth True (_ : rest) = go depth False rest
  go depth False ('\\' : rest) = go depth True rest
  go depth False ('[' : rest) = go (depth + 1) False rest
  go depth False (']' : rest) = go (max 0 (depth - 1)) False rest
  go depth False (_ : rest) = go depth False rest

escapedAtEnd :: Text -> Bool
escapedAtEnd = odd . length . takeWhile (== '\\') . reverse . Text.unpack

outsideFences :: Text -> [(Int, Text)]
outsideFences = map planLinePair . lexPlanLines

planLinePair :: PlanLine -> (Int, Text)
planLinePair planLine = case planLine of
  StructuralLine lineNumber line -> (lineNumber, line)
  OpaqueBoundary lineNumber -> (lineNumber, opaqueBoundaryMarker)

opaqueBoundaryMarker :: Text
opaqueBoundaryMarker = "\NULAMOEBIUS-OPAQUE-MARKDOWN-BOUNDARY\NUL"

lexPlanLines :: Text -> [PlanLine]
lexPlanLines contents = reverse visibleReversed
 where
  (_, _, _, _, visibleReversed) =
    foldl'
      lexPlanLine
      (Nothing, False, Nothing, False, [])
      (zip [1 ..] (Text.lines contents))

lexPlanLine
  :: (Maybe Fence, Bool, Maybe HtmlBlock, Bool, [PlanLine])
  -> (Int, Text)
  -> (Maybe Fence, Bool, Maybe HtmlBlock, Bool, [PlanLine])
lexPlanLine (Just activeFence, _, _, _, visible) (_, rawLine)
  | isFenceCloser activeFence rawLine = (Nothing, False, Nothing, False, visible)
  | otherwise = (Just activeFence, False, Nothing, False, visible)
lexPlanLine (Nothing, _, Just HtmlUntilBlank, _, visible) (lineNumber, rawLine)
  | physicalBlankLine rawLine =
      (Nothing, False, Nothing, False, StructuralLine lineNumber "" : visible)
  | otherwise = (Nothing, False, Just HtmlUntilBlank, False, visible)
lexPlanLine (Nothing, _, Just block@(HtmlUntilMarker marker), _, visible) (_, rawLine)
  | marker `Text.isInfixOf` Text.toCaseFold rawLine =
      (Nothing, False, Nothing, False, visible)
  | otherwise = (Nothing, False, Just block, False, visible)
lexPlanLine (Nothing, True, Nothing, _, visible) (lineNumber, rawLine) =
  let (nextCommentActive, maskedLine) = maskHtmlComments True rawLine
   in case topLevelStructuralLine maskedLine of
        Nothing ->
          (Nothing, nextCommentActive, Nothing, False, OpaqueBoundary lineNumber : visible)
        Just line ->
          (Nothing, nextCommentActive, Nothing, False, StructuralLine lineNumber line : visible)
lexPlanLine (Nothing, False, Nothing, containerActive, visible) (lineNumber, rawLine) =
  case containerDisposition containerActive rawLine of
    ContainerBlank ->
      (Nothing, False, Nothing, True, StructuralLine lineNumber "" : visible)
    ContainerOwned ->
      (Nothing, False, Nothing, True, OpaqueBoundary lineNumber : visible)
    ContainerTopLevel candidateLine ->
      let (nextCommentActive, maskedLine) = maskHtmlComments False candidateLine
       in case topLevelStructuralLine maskedLine of
            Nothing ->
              (Nothing, nextCommentActive, Nothing, False, OpaqueBoundary lineNumber : visible)
            Just line -> lexTopLevelPlanLine nextCommentActive lineNumber line visible

lexTopLevelPlanLine
  :: Bool
  -> Int
  -> Text
  -> [PlanLine]
  -> (Maybe Fence, Bool, Maybe HtmlBlock, Bool, [PlanLine])
lexTopLevelPlanLine nextCommentActive lineNumber line visible =
  case fenceOpener line of
    Just openedFence ->
      ( Just openedFence
      , False
      , Nothing
      , False
      , prependFenceBoundary lineNumber visible
      )
    Nothing -> case htmlBlockOpener line of
      Just block
        | htmlBlockClosesOnLine block line ->
            (Nothing, False, Nothing, False, OpaqueBoundary lineNumber : visible)
        | otherwise ->
            (Nothing, False, Just block, False, OpaqueBoundary lineNumber : visible)
      Nothing ->
        ( Nothing
        , nextCommentActive
        , Nothing
        , False
        , StructuralLine lineNumber line : visible
        )

data ContainerDisposition
  = ContainerBlank
  | ContainerOwned
  | ContainerTopLevel Text
  deriving (Eq, Show)

containerDisposition :: Bool -> Text -> ContainerDisposition
containerDisposition active rawLine =
  containerSyntaxLine rawLine `seq`
    if physicalBlankLine rawLine
      then if active then ContainerBlank else ContainerTopLevel rawLine
      else
        if hasExplicitContainerMarker rawLine
          then ContainerOwned
          else
            if active && hasContainerContinuationIndent rawLine
              then ContainerOwned
              else ContainerTopLevel rawLine

hasContainerContinuationIndent :: Text -> Bool
hasContainerContinuationIndent line =
  case Text.uncons line of
    Just ('\t', _) -> True
    Just (' ', _) -> True
    _ -> False

hasExplicitContainerMarker :: Text -> Bool
hasExplicitContainerMarker rawLine =
  case dropFenceIndent rawLine of
    Nothing -> False
    Just line ->
      case Text.stripPrefix ">" line of
        Just _ -> True
        Nothing -> case Text.uncons line of
          Just (marker, remainder)
            | marker `elem` ['-', '+', '*'] -> beginsWithAsciiWhitespace remainder
          _ ->
            let (digits, remainder) = Text.span isDigit line
             in not (Text.null digits)
                  && Text.length digits <= 9
                  && case Text.uncons remainder of
                    Just (marker, afterMarker)
                      | marker == '.' || marker == ')' -> beginsWithAsciiWhitespace afterMarker
                    _ -> False
 where
  beginsWithAsciiWhitespace value = maybe False (asciiWhitespace . fst) (Text.uncons value)

prependFenceBoundary :: Int -> [PlanLine] -> [PlanLine]
prependFenceBoundary lineNumber visible = OpaqueBoundary lineNumber : visible

topLevelStructuralLine :: Text -> Maybe Text
topLevelStructuralLine line =
  let (indent, remainder) = Text.span (== ' ') line
   in if Text.length indent <= 3 && not ("\t" `Text.isPrefixOf` remainder)
        then Just remainder
        else Nothing

maskHtmlComments :: Bool -> Text -> (Bool, Text)
maskHtmlComments initiallyActive input =
  guardedMaskHtmlComments initiallyActive input

guardedMaskHtmlComments :: Bool -> Text -> (Bool, Text)
guardedMaskHtmlComments initiallyActive input = go initiallyActive input initialChunks
 where
  initialChunks = [phaseContractCommentSentinel | initiallyActive]

  go True remaining chunks =
    let (_, closing) = Text.breakOn "-->" remaining
     in if Text.null closing
          then finish True chunks
          else go False (Text.drop 3 closing) chunks
  go False remaining chunks =
    case Text.breakOn "<!--" remaining of
      (before, opening)
        | Text.null opening -> finish False (before : chunks)
        | otherwise ->
            go
              True
              (Text.drop 4 opening)
              (phaseContractCommentSentinel : before : chunks)

  finish active chunks = (active, Text.concat (reverse chunks))

phaseContractCommentSentinel :: Text
phaseContractCommentSentinel = "!"

htmlBlockOpener :: Text -> Maybe HtmlBlock
htmlBlockOpener = classifiedHtmlBlockOpener

classifiedHtmlBlockOpener :: Text -> Maybe HtmlBlock
classifiedHtmlBlockOpener line =
  let folded = Text.toCaseFold line
   in case [name | name <- ["script", "pre", "style", "textarea"], name `htmlTagStarts` folded] of
        tagName : _ -> Just (HtmlUntilMarker ("</" <> tagName <> ">"))
        []
          | "<?" `Text.isPrefixOf` line -> Just (HtmlUntilMarker "?>")
          | "<![CDATA[" `Text.isPrefixOf` line -> Just (HtmlUntilMarker "]]>")
          | htmlDeclarationStarts line -> Just (HtmlUntilMarker ">")
          | isBlockHtmlTag folded || isCompleteHtmlTagLine line -> Just HtmlUntilBlank
          | otherwise -> Nothing

htmlBlockClosesOnLine :: HtmlBlock -> Text -> Bool
htmlBlockClosesOnLine HtmlUntilBlank _ = False
htmlBlockClosesOnLine (HtmlUntilMarker marker) line =
  marker `Text.isInfixOf` Text.toCaseFold line

htmlTagStarts :: Text -> Text -> Bool
htmlTagStarts name line =
  case Text.stripPrefix ("<" <> name) line of
    Just remainder ->
      case Text.uncons remainder of
        Nothing -> True
        Just (character, _) -> character == ' ' || character == '\t' || character == '>'
    Nothing -> False

htmlDeclarationStarts :: Text -> Bool
htmlDeclarationStarts line =
  case Text.stripPrefix "<!" line >>= (fmap fst . Text.uncons) of
    Just character -> character >= 'A' && character <= 'Z'
    Nothing -> False

isBlockHtmlTag :: Text -> Bool
isBlockHtmlTag line = maybe False (`elem` blockHtmlTagNames) (htmlTagName line)

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
  let afterSlash = maybe afterOpen id (Text.stripPrefix "/" afterOpen)
      (name, remainder) = Text.span (\character -> isAlphaNum character || character == '-') afterSlash
  case Text.uncons name of
    Just (first, _)
      | isAlpha first
      , case Text.uncons remainder of
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
      let (throughClose, afterClose) = Text.breakOnEnd ">" line
       in not (Text.null throughClose)
            && Text.all asciiWhitespace afterClose
            && balancedHtmlQuotes (Text.drop 1 (Text.dropEnd 1 throughClose))

balancedHtmlQuotes :: Text -> Bool
balancedHtmlQuotes = go Nothing . Text.unpack
 where
  go Nothing [] = True
  go (Just _) [] = False
  go quote (character : rest) = case quote of
    Nothing
      | character == '\'' || character == '"' -> go (Just character) rest
      | character == '<' || character == '>' || character == '`' -> False
      | otherwise -> go Nothing rest
    Just wanted
      | character == wanted -> go Nothing rest
      | otherwise -> go quote rest

containerSyntaxLine :: Text -> Text
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
        | marker `elem` ['-', '+', '*'] -> whitespaceDelimited remainder
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
        | asciiWhitespace character -> Just (dropMarkerWhitespace remainder)
      _ -> Nothing

  dropMarkerWhitespace = Text.dropWhile asciiWhitespace
  dropContainerIndent line =
    let (indent, remainder) = Text.span (== ' ') line
     in if Text.length indent <= 3 then remainder else line

fenceOpener :: Text -> Maybe Fence
fenceOpener line =
  classifiedFenceOpener line

classifiedFenceOpener :: Text -> Maybe Fence
classifiedFenceOpener line = do
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
        && Text.all asciiWhitespace trailing
    Nothing -> False

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

physicalBlankLine :: Text -> Bool
physicalBlankLine = Text.all asciiWhitespace

normalizePath :: FilePath -> FilePath
normalizePath = dropDot . normalise . map slash
 where
  slash '\\' = '/'
  slash character = character
  dropDot ('.' : '/' : rest) = dropDot rest
  dropDot path = path

sortOnPath :: [PhaseDocument] -> [PhaseDocument]
sortOnPath = sortByPath
 where
  sortByPath [] = []
  sortByPath (first : rest) =
    sortByPath [value | value <- rest, phasePath value <= phasePath first]
      <> [first]
      <> sortByPath [value | value <- rest, phasePath value > phasePath first]

selectPhaseDocument :: [PhaseDocument] -> Maybe PhaseDocument
selectPhaseDocument = listToMaybe . sortOnPath

renderPaths :: [PhaseDocument] -> Text
renderPaths = Text.intercalate ", " . map (Text.pack . phasePath) . sortOnPath

formatPhase :: Int -> Text
formatPhase number
  | number < 10 = "0" <> showText number
  | otherwise = showText number

countOccurrences :: Text -> Text -> Int
countOccurrences needle source
  | Text.null needle = 0
  | otherwise = go source
 where
  go remaining =
    let (_, match) = Text.breakOn needle remaining
     in if Text.null match
          then 0
          else 1 + go (Text.drop (Text.length needle) match)

atMay :: [value] -> Int -> Maybe value
atMay values index
  | index < 0 = Nothing
  | otherwise = case drop index values of
      value : _ -> Just value
      [] -> Nothing

showText :: Show value => value -> Text
showText = Text.pack . show

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"

statusFrontier :: SemanticScope -> Status.StatusFrontier
statusFrontier scope = case scope of
  StructuralOnly -> Status.initialFrontier
  GateScope _ frontier -> frontier
  PostPassScope _ frontier -> frontier
  RecordedScope _ frontier -> frontier

semanticDueOrdinal :: SemanticScope -> Int
semanticDueOrdinal scope = case scope of
  StructuralOnly -> phaseDomainLowerNumber
  GateScope phaseUnderValidation _ -> phaseUnderValidation
  PostPassScope passedPhase _ -> passedPhase
  RecordedScope completedPrefix _ -> completedPrefix

phaseDomainLowerNumber :: Int
phaseDomainLowerNumber = PhaseIdentity.phaseDomainLowerOrdinal

phaseDomainUpperNumber :: Int
phaseDomainUpperNumber = PhaseIdentity.phaseDomainUpperOrdinal

phaseDomainLabel :: Text
phaseDomainLabel = showText phaseDomainLowerNumber <> "..9,50.." <> showText phaseDomainUpperNumber

policyPredecessorNumber :: Int -> Int
policyPredecessorNumber number = fromMaybe (number - 1) (PhaseIdentity.predecessorOrdinal number)
