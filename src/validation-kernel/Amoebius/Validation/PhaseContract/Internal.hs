{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseContract.Internal
  ( checkPhaseAndTracker
  , checkPhaseContractStructure
  , checkPhaseContracts
  ) where

import Amoebius.Validation.PolicyContract.Internal qualified as Policy
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
  , Finding
  , Observation
  , finding
  , observation
  )
import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import Data.List (findIndex, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (listToMaybe, mapMaybe, maybeToList)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath.Posix (normalise, takeDirectory, takeFileName)
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

-- | Pure phase/tracker check. The supplied paths are repository-relative and
-- the caller controls every byte, which lets independent oracle tests construct
-- minimal positive and paired-negative corpora without filesystem effects.
checkPhaseContracts :: [(FilePath, Text)] -> CheckResult
checkPhaseContracts = checkPhaseContractsWithSemanticBarrier True

-- | Structural parser seam for small oracle corpora. It always carries an
-- exact diagnostic-only refusal: caller-authored Markdown bytes cannot become
-- a candidate-shaped green 'CheckResult'.
checkPhaseContractStructure :: [(FilePath, Text)] -> CheckResult
checkPhaseContractStructure = checkPhaseContractsWithSemanticBarrier False

checkPhaseContractsWithSemanticBarrier :: Bool -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsWithSemanticBarrier requireSemanticAudit supplied =
  case phaseContractInputEnvelopeFindings supplied of
    [] -> checkPhaseContractsWithinEnvelope requireSemanticAudit supplied
    envelopeFindings ->
      CheckResult
        { checkName = phaseContractCheckName
        , checkObservations = phaseContractInputEnvelopeObservations
        , checkFindings = structuralDiagnosticRefusal requireSemanticAudit <> phaseContractInputEnvelopeResultFindings envelopeFindings
        }

checkPhaseContractsWithinEnvelope :: Bool -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsWithinEnvelope requireSemanticAudit supplied =
  CheckResult
    { checkName = phaseContractCheckName
    , checkObservations = structuralResultObservations
          <> concatMap checkObservations semanticDiagnostics
    , checkFindings =
        phaseDomainResultFindings
          <> phaseStructureResultFindings
          <> dependencyResultFindings
          <> gateResultFindings
          <> sprintResultFindings
          <> trackerResultFindings
          <> trackerJoinResultFindings
          <> projectionVocabularyResultFindings
          <> structuralDiagnosticRefusal requireSemanticAudit
          <> concatMap checkFindings semanticDiagnostics
    }
 where
  normalized = [(normalizePath path, contents) | (path, contents) <- supplied]
  parsed = mapMaybe (uncurry parsePhaseDocument) normalized
  grouped = Map.fromListWith (<>) [(phaseNumber phase, [phase]) | phase <- parsed]
  phases = Map.mapMaybe (listToMaybe . sortOnPath) grouped
  structuralResultObservations =
    guardedStructuralResultObservations
#if defined(VALIDATION_PHASE_CONTRACT_OBSERVATION_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_DOMAIN_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedPhaseDomainResultFindings = phaseDomainFindings
  phaseStructureResultFindings =
    guardedPhaseStructureResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_STRUCTURE_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedPhaseStructureResultFindings = concatMap checkPhaseStructure (Map.elems phases)
  dependencyResultFindings =
    guardedDependencyResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedDependencyResultFindings = concatMap (checkDependency phases) (Map.elems phases)
  gateResultFindings =
    guardedGateResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_GATE_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedGateResultFindings = concatMap checkGate (Map.elems phases)
  sprintResultFindings =
    guardedSprintResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedSprintResultFindings = concatMap (checkSprintContracts phases requireSemanticAudit) (Map.elems phases)
  trackerResultFindings =
    guardedTrackerResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedTrackerResultFindings = trackerFindings
  trackerJoinResultFindings =
    guardedTrackerJoinResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_JOIN_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedTrackerJoinResultFindings = checkTrackerJoin phases trackerRows
  projectionVocabularyResultFindings =
    guardedProjectionVocabularyResultFindings
#if defined(VALIDATION_PHASE_CONTRACT_PROJECTION_RESULT_COMPOSITION_BYPASS_MUTANT)
      `seq` []
#endif
  guardedProjectionVocabularyResultFindings = checkProjectionVocabulary phases trackerRows
  duplicatePhaseFindings =
    guardedDuplicatePhaseFindings
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_DUPLICATE_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedDuplicatePhaseFindings =
    [ finding
        "PLAN-PHASE-DUPLICATE"
        (phasePath first)
        ("phase ordinal occurs in more than one contract path: " <> renderPaths candidates)
    | candidates@(first : _) <- Map.elems grouped
    , length candidates /= 1
    ]
  expectedNumbers = Set.fromList [phaseDomainLowerNumber .. phaseDomainUpperNumber]
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
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_MISSING_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedMissingPhaseFindings =
    [finding "PLAN-PHASE-MISSING" "DEVELOPMENT_PLAN/" ("missing Phase " <> showText number) | number <- missingNumbers]
  extraPhaseFindings =
    guardedExtraPhaseFindings
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_EXTRA_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedExtraPhaseFindings =
    [finding "PLAN-PHASE-EXTRA" (phasePath phase) ("phase ordinal lies outside the closed " <> phaseDomainLabel <> " domain") | number <- extraNumbers, Just phase <- [Map.lookup number phases]]
  discoveryPhaseFindings =
    guardedDiscoveryPhaseFindings
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_DISCOVERY_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
      <> checkTrackerShape trackerRows
  trackerCardinalityFindings =
    guardedTrackerCardinalityFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_CARDINALITY_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
  semanticDiagnostics =
    if requireSemanticAudit
      then
        [ phaseSemanticContractDiagnostic
        , resourceProvisionContractDiagnostic
        , phaseSemanticJoinDiagnostic supplied
        ]
      else []

trackerFrameFindings :: TrackerFrame -> [Finding]
trackerFrameFindings frame =
  guardedTrackerFrameFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_FRAME_FINDING_BYPASS_MUTANT)
    `seq` []
#endif
 where
  guardedTrackerFrameFindings =
    [ finding "PLAN-TRACKER-TABLE-FRAME" trackerPath problem
    | problem <- trackerFrameProblems frame
    ]

phaseContractCheckName :: Text
#if defined(VALIDATION_PHASE_CONTRACT_CHECK_NAME_BYPASS_MUTANT)
phaseContractCheckName = "phase-contracts-mutant"
#else
phaseContractCheckName = "phase-contracts"
#endif

phaseDocumentCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_DOCUMENT_COUNT_OBSERVATION_BYPASS_MUTANT)
phaseDocumentCountObservationValue value = value `seq` "0"
#else
phaseDocumentCountObservationValue = showText
#endif

trackerRowCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_ROW_COUNT_OBSERVATION_BYPASS_MUTANT)
trackerRowCountObservationValue value = value `seq` "0"
#else
trackerRowCountObservationValue = showText
#endif

gateRowCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_GATE_ROW_COUNT_OBSERVATION_BYPASS_MUTANT)
gateRowCountObservationValue value = value `seq` "0"
#else
gateRowCountObservationValue = showText
#endif

sprintSectionCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SECTION_COUNT_OBSERVATION_BYPASS_MUTANT)
sprintSectionCountObservationValue value = value `seq` "0"
#else
sprintSectionCountObservationValue = showText
#endif

unresolvedMarkerCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_UNRESOLVED_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT)
unresolvedMarkerCountObservationValue value = value `seq` "0"
#else
unresolvedMarkerCountObservationValue = showText
#endif

missingMarkerCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_MISSING_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT)
missingMarkerCountObservationValue value = value `seq` "0"
#else
missingMarkerCountObservationValue = showText
#endif

refusalMarkerCountObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_REFUSAL_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT)
refusalMarkerCountObservationValue value = value `seq` "0"
#else
refusalMarkerCountObservationValue = showText
#endif

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
#ifdef VALIDATION_PHASE_CONTRACT_INPUT_ENTRY_LIMIT_BYPASS_MUTANT
phaseContractEntryCountExceeded _ = False
#else
phaseContractEntryCountExceeded = phaseContractHasMoreThan phaseContractInputEntryLimit
#endif

phaseContractPathCharactersExceeded :: FilePath -> Bool
#ifdef VALIDATION_PHASE_CONTRACT_INPUT_PATH_LIMIT_BYPASS_MUTANT
phaseContractPathCharactersExceeded _ = False
#else
phaseContractPathCharactersExceeded = phaseContractHasMoreThan phaseContractInputPathCharacterLimit
#endif

phaseContractDocumentCharactersExceeded :: Text -> Bool
#ifdef VALIDATION_PHASE_CONTRACT_INPUT_DOCUMENT_LIMIT_BYPASS_MUTANT
phaseContractDocumentCharactersExceeded _ = False
#else
phaseContractDocumentCharactersExceeded contents = Text.length contents > phaseContractInputDocumentCharacterLimit
#endif

phaseContractTotalCharactersExceeded :: [(FilePath, Text)] -> Bool
#ifdef VALIDATION_PHASE_CONTRACT_INPUT_TOTAL_LIMIT_BYPASS_MUTANT
phaseContractTotalCharactersExceeded _ = False
#else
phaseContractTotalCharactersExceeded = go 0
 where
  go _ [] = False
  go accumulated ((_, contents) : rest)
    | Text.length contents > phaseContractInputTotalCharacterLimit - accumulated = True
    | otherwise = go (accumulated + Text.length contents) rest
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_OBSERVATION_BYPASS_MUTANT)
phaseContractInputEnvelopeObservationValue = "parse-state-unknown"
#else
phaseContractInputEnvelopeObservationValue = "refused-before-parse"
#endif

phaseContractInputEntryLimitObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_ENTRY_LIMIT_OBSERVATION_BYPASS_MUTANT)
phaseContractInputEntryLimitObservationValue value = value `seq` "0"
#else
phaseContractInputEntryLimitObservationValue = showText
#endif

phaseContractInputPathLimitObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_PATH_LIMIT_OBSERVATION_BYPASS_MUTANT)
phaseContractInputPathLimitObservationValue value = value `seq` "0"
#else
phaseContractInputPathLimitObservationValue = showText
#endif

phaseContractInputDocumentLimitObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_DOCUMENT_LIMIT_OBSERVATION_BYPASS_MUTANT)
phaseContractInputDocumentLimitObservationValue value = value `seq` "0"
#else
phaseContractInputDocumentLimitObservationValue = showText
#endif

phaseContractInputTotalLimitObservationValue :: Int -> Text
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_TOTAL_LIMIT_OBSERVATION_BYPASS_MUTANT)
phaseContractInputTotalLimitObservationValue value = value `seq` "0"
#else
phaseContractInputTotalLimitObservationValue = showText
#endif

phaseContractInputEnvelopeObservations :: [Observation]
phaseContractInputEnvelopeObservations =
  guardedPhaseContractInputEnvelopeObservations
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_OBSERVATION_COMPOSITION_BYPASS_MUTANT)
    `seq` []
#endif
 where
  guardedPhaseContractInputEnvelopeObservations =
    [ observation "phase-contract-input-envelope" phaseContractInputEnvelopeObservationValue
    , observation "phase-contract-input-entry-limit" (phaseContractInputEntryLimitObservationValue phaseContractInputEntryLimit)
    , observation "phase-contract-input-path-character-limit" (phaseContractInputPathLimitObservationValue phaseContractInputPathCharacterLimit)
    , observation "phase-contract-input-document-character-limit" (phaseContractInputDocumentLimitObservationValue phaseContractInputDocumentCharacterLimit)
    , observation "phase-contract-input-total-character-limit" (phaseContractInputTotalLimitObservationValue phaseContractInputTotalCharacterLimit)
    ]

phaseContractInputEnvelopeResultFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_FINDING_COMPOSITION_BYPASS_MUTANT)
phaseContractInputEnvelopeResultFindings findings = length findings `seq` []
#else
phaseContractInputEnvelopeResultFindings = id
#endif

structuralDiagnosticRefusal :: Bool -> [Finding]
#if defined(VALIDATION_PHASE_CONTRACT_STRUCTURE_DIAGNOSTIC_BYPASS_MUTANT)
structuralDiagnosticRefusal _ = []
#else
structuralDiagnosticRefusal requireSemanticAudit =
  [ finding
      "PLAN-STRUCTURE-DIAGNOSTIC-ONLY"
      "DEVELOPMENT_PLAN/"
      "caller-authored structural input has no semantic, acquisition, reviewer-custody, observer, or promotion authority"
  | not requireSemanticAudit
  ]
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_DIRECTORY_BYPASS_MUTANT)
phaseNumberFromPath path = takeDirectory path `seq` phaseNumberFromFileName path
#else
phaseNumberFromPath path
  | takeDirectory path /= "DEVELOPMENT_PLAN" = Nothing
  | otherwise = phaseNumberFromFileName path
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_PREFIX_BYPASS_MUTANT)
phasePathPrefix fileName =
  case Text.stripPrefix "phase_" fileName of
    Just remainder -> Just remainder
    Nothing -> Text.stripPrefix "stage_" fileName
#else
phasePathPrefix = Text.stripPrefix "phase_"
#endif

phasePathDigitPrefix :: Text -> Maybe (Text, Text)
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_DIGIT_WIDTH_BYPASS_MUTANT)
phasePathDigitPrefix remainder =
  let result@(digits, _) = Text.span isDigit remainder
   in if Text.null digits then Nothing else Just result
#else
phasePathDigitPrefix remainder =
  let result@(digits, _) = Text.splitAt 2 remainder
   in if Text.length digits == 2 then Just result else Nothing
#endif

phasePathSeparatorValid :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_SEPARATOR_BYPASS_MUTANT)
phasePathSeparatorValid suffix = not (Text.null suffix)
#else
phasePathSeparatorValid = Text.isPrefixOf "_"
#endif

phasePathExtensionValid :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_EXTENSION_BYPASS_MUTANT)
phasePathExtensionValid suffix =
  Text.length suffix `seq` (Text.isSuffixOf ".md" suffix || Text.isSuffixOf ".txt" suffix)
#else
phasePathExtensionValid = Text.isSuffixOf ".md"
#endif

phasePathSlug :: Text -> Text
phasePathSlug suffix =
  let withoutExtension =
        case Text.stripSuffix ".md" suffix of
          Just value -> value
          Nothing -> maybe suffix id (Text.stripSuffix ".txt" suffix)
   in maybe withoutExtension id (Text.stripPrefix "_" withoutExtension)

phasePathSlugNonEmpty :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_EMPTY_BYPASS_MUTANT)
phasePathSlugNonEmpty suffix = Text.null (phasePathSlug suffix) `seq` True
#else
phasePathSlugNonEmpty = not . Text.null . phasePathSlug
#endif

phasePathSlugCharactersValid :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_CHARACTER_BYPASS_MUTANT)
phasePathSlugCharactersValid suffix =
  Text.all phaseSlugCharacter (phasePathSlug suffix) `seq` True
#else
phasePathSlugCharactersValid = Text.all phaseSlugCharacter . phasePathSlug
#endif

phaseSlugCharacter :: Char -> Bool
phaseSlugCharacter character =
  (character >= 'a' && character <= 'z') || isDigit character || character == '_'

phasePathSlugSegmentsValid :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_SEGMENT_BYPASS_MUTANT)
phasePathSlugSegmentsValid suffix =
  any Text.null (Text.splitOn "_" (phasePathSlug suffix)) `seq` True
#else
phasePathSlugSegmentsValid suffix =
  let slug = phasePathSlug suffix
   in Text.null slug || all (not . Text.null) (Text.splitOn "_" slug)
#endif

parsePhaseTitle :: Int -> [(Int, Text)] -> Maybe Text
parsePhaseTitle number visible =
  selectPhaseTitle
    [ Text.strip title
    | (_, line) <- visible
    , Just title <- [phaseTitleRemainder number (trimAsciiEnd line)]
    , phaseTitleBodyNonEmpty title
    ]

phaseTitleRemainder :: Int -> Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_TITLE_PREFIX_BYPASS_MUTANT)
phaseTitleRemainder number line =
  case Text.stripPrefix ("# Phase " <> showText number <> ":") line of
    Just title -> Just title
    Nothing -> Text.stripPrefix ("# Stage " <> showText number <> ":") line
#else
phaseTitleRemainder number = Text.stripPrefix ("# Phase " <> showText number <> ":")
#endif

phaseTitleBodyNonEmpty :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_TITLE_EMPTY_BYPASS_MUTANT)
phaseTitleBodyNonEmpty title = Text.null (Text.strip title) `seq` True
#else
phaseTitleBodyNonEmpty = not . Text.null . Text.strip
#endif

selectPhaseTitle :: [Text] -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_TITLE_CARDINALITY_BYPASS_MUTANT)
selectPhaseTitle = listToMaybe
#else
selectPhaseTitle candidates =
  case candidates of
    [title] -> Just title
    _ -> Nothing
#endif

summaryFieldNames :: [Text]
summaryFieldNames = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

fieldEntries :: [(Int, Text)] -> [(Int, Text, Text)]
fieldEntries visible = sortOn (\(lineNumber, _, _) -> lineNumber) (concatMap entriesFor summaryFieldNames)
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SECOND_HEADER_BYPASS_MUTANT)
          stage `seq` lineNumber `seq` scanned
#else
          addGateProblem
            ("line " <> showText lineNumber <> ": a second exact gate-table header is not permitted")
            ( scanned
              { gateScanStage = if stage == GateFinished then GateFinished else GateBroken
              , gateScanHeaderCount = gateScanHeaderCount scanned + 1
                }
            )
#endif
  | otherwise =
      case gateScanStage scanned of
        GateSeekingHeader ->
          if isGateTableCandidate line
            then
#if defined(VALIDATION_PHASE_CONTRACT_GATE_UNFRAMED_ROW_BYPASS_MUTANT)
              lineNumber `seq` scanned
#else
              addGateProblem
                ("line " <> showText lineNumber <> ": a gate-table row occurs before the exact header")
                scanned
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_END_CONTENT_BYPASS_MUTANT)
rejectGateTrailingContent scanned lineNumber = lineNumber `seq` scanned {gateScanStage = GateFinished}
#else
rejectGateTrailingContent scanned lineNumber =
  addGateProblem
    ( "line "
        <> showText lineNumber
        <> ": the eighteen-row gate table must end at a physical blank line or section end"
    )
    (scanned {gateScanStage = GateBroken})
#endif

rejectOutsideGateRow :: GateScan -> Int -> GateScan
#if defined(VALIDATION_PHASE_CONTRACT_GATE_OUTSIDE_ROW_BYPASS_MUTANT)
rejectOutsideGateRow scanned lineNumber = lineNumber `seq` scanned
#else
rejectOutsideGateRow scanned lineNumber =
  addGateProblem
    ("line " <> showText lineNumber <> ": a gate-table row occurs outside the single exact frame")
    scanned
#endif

handleGateRowFailure :: GateScan -> Int -> Text -> Text -> Text -> GateScan
handleGateRowFailure scanned lineNumber expectedKey line reason =
#if defined(VALIDATION_PHASE_CONTRACT_GATE_IGNORED_ROW_BYPASS_MUTANT)
  if ignored then scanned else reject
#else
  ignored `seq` reject
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_MISSING_HEADER_FINDING_BYPASS_MUTANT)
finishGateWithoutHeader scanned = scanned
#else
finishGateWithoutHeader = addGateProblem "one exact '| Key | Contract |' gate-table header is required"
#endif

finishGateWithoutDelimiter :: GateScan -> GateScan
#if defined(VALIDATION_PHASE_CONTRACT_GATE_MISSING_DELIMITER_FINDING_BYPASS_MUTANT)
finishGateWithoutDelimiter scanned = scanned
#else
finishGateWithoutDelimiter =
  addGateProblem "the exact gate-table header has no following '|---|---|' delimiter"
#endif

finishIncompleteGateRows :: GateScan -> Int -> GateScan
#if defined(VALIDATION_PHASE_CONTRACT_GATE_INCOMPLETE_ROWS_FINDING_BYPASS_MUTANT)
finishIncompleteGateRows scanned index = index `seq` scanned
#else
finishIncompleteGateRows scanned index =
  addGateProblem
    ( "the gate table ended after "
        <> showText index
        <> " rows; all eighteen exact ordered rows are required"
    )
    scanned
#endif

addGateProblem :: Text -> GateScan -> GateScan
addGateProblem problem scanned =
  scanned {gateScanProblemsReversed = problem : gateScanProblemsReversed scanned}

isGateHeader :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_HEADER_WILDCARD_BYPASS_MUTANT)
isGateHeader line =
  gateHeaderCells
    `seq` case exactTableCells line of
      Just ["Key", _] -> True
      _ -> False
#else
isGateHeader line = exactTableCells line == Just gateHeaderCells
#endif

isGateDelimiter :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_DELIMITER_SHAPE_BYPASS_MUTANT)
isGateDelimiter line =
  gateDelimiterCells
    `seq` maybe False ((== 2) . length) (exactTableCells line)
#else
isGateDelimiter line = exactTableCells line == Just gateDelimiterCells
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_ROW_ARITY_BYPASS_MUTANT)
    Just (keyCell : value : _) -> Right (keyCell, value)
    Just cells -> Left ("the row must have at least two cells; observed " <> showText (length cells))
#else
    Just [keyCell, value] -> Right (keyCell, value)
    Just cells -> Left ("the row must have exactly two cells; observed " <> showText (length cells))
#endif

gateContractCellEmpty :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_ROW_EMPTY_BYPASS_MUTANT)
gateContractCellEmpty value = Text.null value `seq` False
#else
gateContractCellEmpty = Text.null
#endif

gateKeyMatches :: Text -> Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_KEY_CODE_BYPASS_MUTANT)
gateKeyMatches expected supplied = supplied == expected || supplied == "`" <> expected <> "`"
#else
gateKeyMatches expected supplied = supplied == "`" <> expected <> "`"
#endif

isGateTableCandidate :: Text -> Bool
isGateTableCandidate = Text.isInfixOf "|"

exactTableCells :: Text -> Maybe [Text]
exactTableCells rawLine = do
  withoutOpen <- stripTableOpeningPipe (trimAsciiEnd rawLine)
  withoutClose <- stripTableClosingPipe withoutOpen
  pure (map trimAscii (Text.splitOn "|" withoutClose))

stripTableOpeningPipe :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_TABLE_OPENING_PIPE_BYPASS_MUTANT)
stripTableOpeningPipe line = Just (maybe line id (Text.stripPrefix "|" line))
#else
stripTableOpeningPipe = Text.stripPrefix "|"
#endif

stripTableClosingPipe :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_TABLE_CLOSING_PIPE_BYPASS_MUTANT)
stripTableClosingPipe line = Just (maybe line id (Text.stripSuffix "|" line))
#else
stripTableClosingPipe = Text.stripSuffix "|"
#endif

trimAscii :: Text -> Text
trimAscii = Text.dropWhile asciiWhitespace . trimAsciiEnd

trimAsciiEnd :: Text -> Text
trimAsciiEnd = Text.dropWhileEnd asciiWhitespace

asciiWhitespace :: Char -> Bool
asciiWhitespace character = character == ' ' || character == '\t'

checkPhaseStructure :: PhaseDocument -> [Finding]
checkPhaseStructure phase =
  titleFindings
    <> statusFindings
    <> summaryFindings
    <> sectionShapeFindings phase
    <> summaryContainmentFindings phase
    <> gateHeadingFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  titleFindings =
    guardedTitleFindings
#if defined(VALIDATION_PHASE_CONTRACT_PHASE_TITLE_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedTitleFindings =
    [ finding "PLAN-PHASE-TITLE" path ("expected exactly one '# Phase " <> showText number <> ": <title>' heading")
    | phaseTitle phase == Nothing
    ]
  statuses = statusLines phase
  expectedStatus = Policy.resetPhaseStatusText (policyResetStatus number) <> "."
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
#if defined(VALIDATION_PHASE_CONTRACT_STATUS_BYPASS_MUTANT)
    length guardedStatusFindings `seq` []
#else
    guardedStatusFindings
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_SUMMARY_FIELD_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SECTION_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedGateHeadingFindings =
    [ finding "PLAN-GATE-SECTION" path "exactly one Gate integrity section is required"
    | length gateHeadings /= 1
    ]

sectionShapeFindings :: PhaseDocument -> [Finding]
#if defined(VALIDATION_PHASE_CONTRACT_SECTION_SHAPE_BYPASS_MUTANT)
sectionShapeFindings _ = []
#else
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
#endif

summaryContainmentFindings :: PhaseDocument -> [Finding]
#if defined(VALIDATION_PHASE_CONTRACT_SUMMARY_CONTAINMENT_BYPASS_MUTANT)
summaryContainmentFindings _ = []
#else
summaryContainmentFindings phase =
  [ finding
      "PLAN-SUMMARY-CONTAINMENT"
      (phasePath phase)
      ( "Phase Summary fields must occur inside that section in exact order "
          <> showText summaryFieldNames
          <> "; observed order "
          <> showText (phaseSummaryFieldOrder phase)
          <> "; outside-section fields "
          <> showText (phaseSummaryFieldStrays phase)
      )
  | phaseSummaryFieldOrder phase /= summaryFieldNames
      || not (null (phaseSummaryFieldStrays phase))
  ]
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_GENESIS_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedDependencyLinkFindings linkProblems =
    [ finding
        "PLAN-DEPENDENCY-LINK"
        (phasePath phase)
        ("Depends on is not one structurally valid inline Markdown link: " <> problem)
    | problem <- linkProblems
    ]
  predecessorFindings targets expectedTarget predecessor =
    guardedPredecessorFindings targets expectedTarget predecessor
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_PREDECESSOR_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedPredecessorFindings targets expectedTarget predecessor =
    [ finding
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath phase)
            ("Depends on must contain only one link, to immediate Phase " <> showText predecessor)
    | targets /= maybeToList expectedTarget
    ]
  forwardFindings forward =
    guardedForwardFindings forward
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_FORWARD_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedForwardFindings forward =
    [ finding
        "PLAN-DEPENDENCY-FORWARD"
        (phasePath phase)
        ("Depends on contains a same-or-forward phase edge to Phase " <> showText targetNumber)
    | targetNumber <- forward
    ]

checkGate :: PhaseDocument -> [Finding]
checkGate phase =
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
  expectedSummaryValue = expectedCommand <> "; see [Gate integrity](#gate-integrity). NOT VALIDATED."
  expectedSummaryLine = "**Gate:** " <> expectedSummaryValue
  shapeFindings =
    guardedShapeFindings
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SHAPE_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_REFUSAL_BYPASS_MUTANT)
    []
#else
    [ finding
        "PLAN-GATE-UNRESOLVED"
        path
        (key <> " contains a fail-closed UNRESOLVED/MISSING marker")
    | (key, value) <- rows
    , containsRefusalMarker value
    ]
#endif
  commandFindings =
    guardedCommandFindings
#if defined(VALIDATION_PHASE_CONTRACT_GATE_COMMAND_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_COMMAND_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedSummaryCommandFindings = case Map.findWithDefault [] "Gate" (phaseFields phase) of
    [value] ->
      [ finding
          "PLAN-GATE-SUMMARY-COMMAND"
          path
          ("Gate summary must be the exact one-line reset form '" <> expectedSummaryLine <> "'")
      | gateSummaryValueMismatch expectedSummaryValue value
          || validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
          || gateSummaryRawLineCountMismatch expectedSummaryLine (phaseRawLines phase)
      ]
    _ -> []

gateCommandCountMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_COMMAND_COUNT_BYPASS_MUTANT)
gateCommandCountMismatch expected value = countOccurrences expected value `seq` False
#else
gateCommandCountMismatch expected value = countOccurrences expected value /= 1
#endif

gateSummaryValueMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_VALUE_BYPASS_MUTANT)
gateSummaryValueMismatch expected value = (value /= expected) `seq` False
#else
gateSummaryValueMismatch = (/=)
#endif

gateSummaryRawLineCountMismatch :: Text -> [Text] -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_RAW_LINE_COUNT_BYPASS_MUTANT)
gateSummaryRawLineCountMismatch expected rawLines =
  length (filter (== expected) rawLines) `seq` False
#else
gateSummaryRawLineCountMismatch expected rawLines =
  length (filter (== expected) rawLines) /= 1
#endif

gateFrameFindings :: PhaseDocument -> [Finding]
#if defined(VALIDATION_PHASE_CONTRACT_TABLE_FRAME_BYPASS_MUTANT)
gateFrameFindings _ = []
#else
gateFrameFindings phase =
  [ finding "PLAN-GATE-TABLE-FRAME" (phasePath phase) problem
  | problem <- phaseGateFrameProblems phase
  ]
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_INLINE_CODE_WIDTH_BYPASS_MUTANT)
validationCommandSpans =
  map (\(_, contents) -> (1, contents))
    . filter (Text.isPrefixOf "pb validate" . Text.toCaseFold . snd)
    . inlineCodeSpans
#else
validationCommandSpans =
  filter (Text.isPrefixOf "pb validate" . Text.toCaseFold . snd) . inlineCodeSpans
#endif

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
  , "Human authority"
  ]

checkSprintContracts :: Map Int PhaseDocument -> Bool -> PhaseDocument -> [Finding]
checkSprintContracts phases enforceCanonicalInventory phase =
  inventoryFindings <> concatMap checkSection sprintSections
 where
  sprintSections = sprintSectionsFor phase
  parsedOrdinals = map (parseSprintOrdinal (phaseNumber phase) . fst) sprintSections
  expectedOrdinals = [1 .. Map.findWithDefault 0 (phaseNumber phase) canonicalSprintCounts]
  inventoryFindings =
    [ finding
        "PLAN-SPRINT-INVENTORY"
        (phasePath phase)
        ( "sprint identities must be the reviewed contiguous inventory "
            <> showText expectedOrdinals
            <> "; observed "
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
        expectedStatus = expectedSprintStatus (phaseNumber phase) <$> ordinal
        expectedMarker = expectedSprintMarker (phaseNumber phase) <$> ordinal
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
                  <> " must contain exactly the reviewed reset status "
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
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_STATUS_BYPASS_MUTANT)
          length guardedSprintStatusFindings `seq` []
#else
          guardedSprintStatusFindings
#endif
        sprintIdentityFindings =
          guardedSprintIdentityFindings
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_IDENTITY_FINDING_BYPASS_MUTANT)
            `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_ORDINAL_CANONICAL_BYPASS_MUTANT)
sprintHeadingOrdinalCanonical digits ordinal = digits `seq` ordinal `seq` True
#else
sprintHeadingOrdinalCanonical digits ordinal = digits == showText ordinal
#endif

sprintHeadingOrdinalPositive :: Int -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_ORDINAL_POSITIVE_BYPASS_MUTANT)
sprintHeadingOrdinalPositive ordinal = ordinal `seq` True
#else
sprintHeadingOrdinalPositive = (> 0)
#endif

sprintHeadingSeparator :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_SEPARATOR_BYPASS_MUTANT)
sprintHeadingSeparator value =
  case Text.stripPrefix ": " value of
    Just remainder -> Just remainder
    Nothing -> Text.stripPrefix ":" value
#else
sprintHeadingSeparator = Text.stripPrefix ": "
#endif

sprintHeadingMarkers :: [Text]
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_MARKER_BYPASS_MUTANT)
sprintHeadingMarkers = currentStatusMarkers <> ["❌"]
#else
sprintHeadingMarkers = currentStatusMarkers
#endif

sprintHeadingTitleNonEmpty :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_TITLE_EMPTY_BYPASS_MUTANT)
sprintHeadingTitleNonEmpty title = Text.null (Text.strip title) `seq` True
#else
sprintHeadingTitleNonEmpty = not . Text.null . Text.strip
#endif

sprintFieldNames :: [Text]
sprintFieldNames =
  [ "Status"
  , "Implementation"
  , "Blocked by"
  , "Requires"
  , "Independent Validation"
  , "Oracle"
  , "Legacy IDs"
  , "Docs to update"
  ]

requiredSprintFieldNames :: [Text]
requiredSprintFieldNames = filter (/= "Requires") sprintFieldNames

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
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_BYPASS_MUTANT)
  length schemaFindings `seq` []
#else
  schemaFindings
#endif
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
    if "Requires" `elem` observedFieldNames
      then sprintFieldNames
      else requiredSprintFieldNames
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
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_FIELD_ORDER_BYPASS_MUTANT)
sprintSchemaFieldOrderValid observed expected = observed `seq` expected `seq` True
#else
sprintSchemaFieldOrderValid = (==)
#endif

sprintSchemaFieldsNonEmpty :: Bool -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_FIELD_NONEMPTY_BYPASS_MUTANT)
sprintSchemaFieldsNonEmpty value = value `seq` True
#else
sprintSchemaFieldsNonEmpty = id
#endif

sprintSchemaLaterFieldsAbsent :: [Text] -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_LATE_FIELD_BYPASS_MUTANT)
sprintSchemaLaterFieldsAbsent values = length values `seq` True
#else
sprintSchemaLaterFieldsAbsent = null
#endif

sprintSchemaSubsectionOrderValid :: [Text] -> [Text] -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_SUBSECTION_ORDER_BYPASS_MUTANT)
sprintSchemaSubsectionOrderValid observed expected = observed `seq` expected `seq` True
#else
sprintSchemaSubsectionOrderValid = (==)
#endif

sprintSchemaSubsectionsNonEmpty :: Bool -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_SUBSECTION_NONEMPTY_BYPASS_MUTANT)
sprintSchemaSubsectionsNonEmpty value = value `seq` True
#else
sprintSchemaSubsectionsNonEmpty = id
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_BYPASS_MUTANT)
sprintBlockerFindings _ _ _ _ = []
#else
sprintBlockerFindings phases phase heading body =
  [ finding
      "PLAN-SPRINT-BLOCKER"
      (phasePath phase)
      (Text.strip heading <> " must equal its one canonical immediate prior plan edge with no appended dependency or review prose")
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
                      <> ") human approval"
                  )
           in sprintPredecessorBlockerValid value linkedEdge
    (Just sprintOrdinal, [value]) ->
      sprintPriorSprintBlockerValid owner sprintOrdinal value
    _ -> False
#endif

sprintGenesisBlockerValid :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_GENESIS_BYPASS_MUTANT)
sprintGenesisBlockerValid value = Text.strip value `elem` ["`genesis`", "genesis"]
#else
sprintGenesisBlockerValid value = Text.strip value == "`genesis`"
#endif

sprintPredecessorBlockerValid :: Text -> Maybe Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_PREDECESSOR_BYPASS_MUTANT)
sprintPredecessorBlockerValid value linkedEdge =
  maybe False (`Text.isPrefixOf` Text.strip value) linkedEdge
#else
sprintPredecessorBlockerValid value linkedEdge = Text.strip value `elem` maybeToList linkedEdge
#endif

sprintPriorSprintBlockerValid :: Int -> Int -> Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_PRIOR_SPRINT_BYPASS_MUTANT)
sprintPriorSprintBlockerValid owner sprintOrdinal value =
  Text.strip value
    `elem` [ "Sprint " <> showText owner <> "." <> showText (sprintOrdinal - 1)
           , "Sprint " <> showText owner <> "." <> showText sprintOrdinal
           ]
#else
sprintPriorSprintBlockerValid owner sprintOrdinal value =
  Text.strip value == "Sprint " <> showText owner <> "." <> showText (sprintOrdinal - 1)
#endif

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
currentStatusMarkers = ["✅", "🔄", "📋", "⏸️", "🧪"]

stripStatusIcon :: Text -> Text
stripStatusIcon value =
  case
      [ Text.stripStart rest
      | icon <- currentStatusMarkers <> ["❌", "🟢", "🔴"]
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

expectedSprintStatus :: Int -> Int -> Text
expectedSprintStatus phaseNumberValue sprintNumber
  | phaseNumberValue == 0 && sprintNumber == 1 = "Active — NOT VALIDATED"
  | otherwise = "Blocked — NOT VALIDATED"

expectedSprintMarker :: Int -> Int -> Text
expectedSprintMarker phaseNumberValue sprintNumber
  | phaseNumberValue == 0 && sprintNumber == 1 = "🔄"
  | otherwise = "⏸️"

canonicalSprintCounts :: Map Int Int
canonicalSprintCounts =
  Map.fromList
    ( [ (0, 8)
      , (1, 8)
      , (2, 6)
      ]
        <> [(phase, 1) | phase <- [3 .. 10]]
        <> [(phase, 2) | phase <- [11 .. 15]]
        <> [(phase, 3) | phase <- [16 .. 19]]
        <> [(phase, 1) | phase <- [20 .. 24]]
        <> [ (25, 4)
           , (26, 5)
           , (27, 4)
           , (28, 4)
           , (29, 5)
           , (30, 3)
           , (31, 4)
           , (32, 2)
           , (33, 3)
           , (34, 9)
           , (35, 4)
           , (36, 4)
           , (37, 3)
           , (38, 3)
           , (39, 3)
           , (40, 3)
           , (41, 3)
           ]
        <> [(phase, 1) | phase <- [42 .. 47]]
        <> [ (48, 5)
           , (49, 4)
           , (50, 4)
           , (51, 5)
           , (52, 5)
           , (53, 5)
           , (54, 5)
           , (55, 4)
           , (56, 4)
           , (57, 3)
           , (58, 5)
           , (59, 5)
           , (60, 3)
           , (61, 4)
           , (62, 3)
           , (63, 4)
           , (64, 4)
           , (65, 4)
           , (66, 1)
           , (67, 5)
           , (68, 1)
           , (69, 4)
           , (70, 1)
           , (71, 4)
           , (72, 1)
           , (73, 3)
           , (74, 2)
           , (75, 4)
           , (76, 1)
           , (77, 4)
           , (78, 5)
           , (79, 2)
           , (80, 8)
           ]
        <> [(phase, 1) | phase <- [81 .. 88]]
        <> [(89, 5)]
        <> [(phase, 1) | phase <- [90 .. 95]]
    )

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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_SECOND_HEADER_BYPASS_MUTANT)
              stage `seq` lineNumber `seq` scanned
#else
              addTrackerProblem
                ("line " <> showText lineNumber <> ": a second exact tracker header is not permitted")
                ( scanned
                  { trackerScanStage = if stage == TrackerFinished then TrackerFinished else TrackerBroken
                  , trackerScanHeaderCount = trackerScanHeaderCount scanned + 1
                    }
                )
#endif
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
                if expectedNumber == phaseDomainUpperNumber
                  then TrackerExpectingEnd
                  else TrackerExpectingRow (expectedNumber + 1)
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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_END_CONTENT_BYPASS_MUTANT)
rejectTrackerTrailingContent scanned lineNumber = lineNumber `seq` scanned {trackerScanStage = TrackerFinished}
#else
rejectTrackerTrailingContent scanned lineNumber =
  addTrackerProblem
    ( "line "
        <> showText lineNumber
        <> ": the 96-row tracker table must end at a physical blank line or end of file"
    )
    (scanned {trackerScanStage = TrackerBroken})
#endif

rejectOutsideTrackerRow :: TrackerScan -> Int -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_OUTSIDE_ROW_BYPASS_MUTANT)
rejectOutsideTrackerRow scanned lineNumber = lineNumber `seq` scanned
#else
rejectOutsideTrackerRow scanned lineNumber =
  addTrackerProblem
    ("line " <> showText lineNumber <> ": a tracker candidate occurs outside the single exact frame")
    scanned
#endif

scanSeekingTrackerLine :: TrackerScan -> Int -> Text -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_UNFRAMED_ROWS_BYPASS_MUTANT)
scanSeekingTrackerLine scanned _ line =
  case parseExactTrackerRow phaseDomainLowerNumber line of
    Right row ->
      scanned
        { trackerScanStage = TrackerExpectingRow (phaseDomainLowerNumber + 1)
        , trackerScanRowsReversed = [row]
        }
    Left _ -> scanned
#else
scanSeekingTrackerLine scanned lineNumber line =
  if isTrackerRawCandidate line
    then
      addTrackerProblem
        ("line " <> showText lineNumber <> ": a seven-cell tracker candidate occurs before the exact header")
        scanned
    else scanned
#endif

scanTrackerBoundary :: TrackerScan -> Int -> TrackerScan
scanTrackerBoundary scanned lineNumber =
  case trackerScanStage scanned of
    TrackerExpectingDelimiter -> interruptTrackerDelimiterBoundary scanned lineNumber
    TrackerExpectingRow expectedNumber -> interruptTrackerRowBoundary scanned lineNumber expectedNumber
    TrackerExpectingEnd -> interruptTrackerEndBoundary scanned lineNumber
    _ -> scanned

interruptTrackerDelimiterBoundary :: TrackerScan -> Int -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_DELIMITER_BOUNDARY_BYPASS_MUTANT)
interruptTrackerDelimiterBoundary scanned lineNumber = lineNumber `seq` scanned
#else
interruptTrackerDelimiterBoundary scanned lineNumber =
  interruptTrackerBoundary scanned lineNumber "delimiter"
#endif

interruptTrackerRowBoundary :: TrackerScan -> Int -> Int -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_ROW_BOUNDARY_BYPASS_MUTANT)
interruptTrackerRowBoundary scanned lineNumber expectedNumber =
  lineNumber `seq` expectedNumber `seq` scanned
#else
interruptTrackerRowBoundary scanned lineNumber expectedNumber =
  interruptTrackerBoundary scanned lineNumber ("Phase " <> showText expectedNumber <> " row")
#endif

interruptTrackerEndBoundary :: TrackerScan -> Int -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_END_BOUNDARY_BYPASS_MUTANT)
interruptTrackerEndBoundary scanned lineNumber = lineNumber `seq` scanned
#else
interruptTrackerEndBoundary scanned lineNumber =
  interruptTrackerBoundary scanned lineNumber "physical table terminator"
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_HEADER_FINDING_BYPASS_MUTANT)
finishTrackerWithoutHeader scanned = scanned
#else
finishTrackerWithoutHeader =
  addTrackerProblem
    "one exact '| Phase | Name | Substrate | Lane | Register | Status | Validation contract |' tracker header is required"
#endif

finishTrackerWithoutDelimiter :: TrackerScan -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_DELIMITER_FINDING_BYPASS_MUTANT)
finishTrackerWithoutDelimiter scanned = scanned
#else
finishTrackerWithoutDelimiter =
  addTrackerProblem "the exact tracker header has no following seven-cell delimiter"
#endif

finishIncompleteTrackerRows :: TrackerScan -> Int -> TrackerScan
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_INCOMPLETE_ROWS_FINDING_BYPASS_MUTANT)
finishIncompleteTrackerRows scanned expectedNumber = expectedNumber `seq` scanned
#else
finishIncompleteTrackerRows scanned expectedNumber =
  addTrackerProblem
    ( "the tracker table ended before canonical Phase "
        <> showText expectedNumber
        <> "; exact ordered rows 0..95 are required"
    )
    scanned
#endif

addTrackerProblem :: Text -> TrackerScan -> TrackerScan
addTrackerProblem problem scanned =
  scanned {trackerScanProblemsReversed = problem : trackerScanProblemsReversed scanned}

isTrackerHeader :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_HEADER_WILDCARD_BYPASS_MUTANT)
isTrackerHeader line =
  trackerHeaderCells
    `seq` case exactTableCells line of
      Just ["Phase", _, "Substrate", "Lane", "Register", "Status", _] -> True
      _ -> False
#else
isTrackerHeader line = exactTableCells line == Just trackerHeaderCells
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_DELIMITER_SHAPE_BYPASS_MUTANT)
isTrackerDelimiter line = maybe False ((== 7) . length) (exactTableCells line)
#else
isTrackerDelimiter line = exactTableCells line == Just (replicate 7 "---")
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_ROW_EMPTY_BYPASS_MUTANT)
trackerRequiredCellEmpty cells = any Text.null cells `seq` False
#else
trackerRequiredCellEmpty = any Text.null
#endif

trackerRowCells :: Text -> Either Text [Text]
trackerRowCells line =
  case exactTableCells line of
    Nothing -> Left "the row must have exact opening and closing pipes on one top-level physical line"
    Just cells -> selectCells cells
 where
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_EXTRA_CELL_BYPASS_MUTANT)
  selectCells cells
    | length cells >= 7 = Right (take 7 cells)
    | otherwise = Left ("the row must have at least seven cells; observed " <> showText (length cells))
#else
  selectCells cells
    | length cells == 7 = Right cells
    | otherwise = Left ("the row must have exactly seven cells; observed " <> showText (length cells))
#endif

trackerRowOrdinal :: Int -> Text -> Either Text Int
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_ORDER_BYPASS_MUTANT)
trackerRowOrdinal _ supplied =
  case readMaybe (Text.unpack supplied) of
    Just parsed
      | parsed >= phaseDomainLowerNumber
      , parsed <= phaseDomainUpperNumber
      , supplied == showText parsed -> Right parsed
    _ -> Left "the ordinal must be one canonical unsigned value in the closed 0..95 domain"
#elif defined(VALIDATION_PHASE_CONTRACT_TRACKER_ORDINAL_CANONICAL_BYPASS_MUTANT)
trackerRowOrdinal expectedNumber supplied =
  case readMaybe (Text.unpack supplied) of
    Just parsed
      | parsed == expectedNumber -> Right expectedNumber
    _ -> Left ("the ordinal must identify expected Phase " <> showText expectedNumber)
#else
trackerRowOrdinal expectedNumber supplied
  | supplied == showText expectedNumber = Right expectedNumber
  | otherwise =
      Left
        ( "the ordinal must be the canonical unsigned spelling '"
            <> showText expectedNumber
            <> "' with no leading zeroes"
        )
#endif

stripExactWrappingCode :: Text -> Text
stripExactWrappingCode value =
  case Text.stripPrefix "`" value >>= Text.stripSuffix "`" of
    Just unquoted
      | not (Text.null unquoted)
      , not ("`" `Text.isInfixOf` unquoted) -> unquoted
    _ -> value

trackerLinkTarget :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_LINK_PROSE_BYPASS_MUTANT)
trackerLinkTarget value =
  case markdownTargets value of
    ([target], []) -> Just target
    _ -> Nothing
#else
trackerLinkTarget value =
  markdownTargets value `seq` case exactClosedMarkdownLink value of
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_LINK_LABEL_BYPASS_MUTANT)
    Just (label, target)
      | not (Text.null label) -> Just target
#else
    Just ("Contract", target) -> Just target
#endif
    _ -> Nothing
#endif

dependencyLinkTarget :: Text -> Text -> Either Text Text
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_PROSE_BYPASS_MUTANT)
dependencyLinkTarget _ value =
  case markdownTargets value of
    ([target], []) -> Right target
    _ -> Left "the field must contain exactly one resolvable Markdown target"
#else
dependencyLinkTarget expectedLabel value =
  markdownTargets value `seq` case exactClosedMarkdownLink value of
    Just (label, target)
#if defined(VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_LABEL_BYPASS_MUTANT)
      | expectedLabel `seq` not (Text.null label) -> Right target
#else
      | label == expectedLabel -> Right target
#endif
    _ ->
      Left
        ( "the complete field value must be exactly one closed Markdown link labelled '"
            <> expectedLabel
            <> "' with no surrounding prose or title"
        )
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_LINK_TARGET_EMPTY_BYPASS_MUTANT)
exactLinkTargetNonEmpty target = Text.null target `seq` True
#else
exactLinkTargetNonEmpty = not . Text.null
#endif

exactLinkTrailingContentClosed :: Text -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_LINK_TRAILING_CONTENT_BYPASS_MUTANT)
exactLinkTrailingContentClosed value = not (Text.null value) && ")" `Text.isPrefixOf` value
#else
exactLinkTrailingContentClosed = (== ")")
#endif

isCanonicalLinkTargetCharacter :: Char -> Bool
#if defined(VALIDATION_PHASE_CONTRACT_LINK_TARGET_CHARACTER_BYPASS_MUTANT)
isCanonicalLinkTargetCharacter character =
  (isAlphaNum character || character `elem` ['/', '.', '_', '-', '#']) `seq` True
#else
isCanonicalLinkTargetCharacter character =
  isAlphaNum character || character `elem` ['/', '.', '_', '-', '#']
#endif

checkTrackerShape :: [TrackerRow] -> [Finding]
checkTrackerShape rows =
  missingFindings <> statusFindings
 where
  actual = Set.fromList (map trackerNumber rows)
  expected = Set.fromList [phaseDomainLowerNumber .. phaseDomainUpperNumber]
  missingFindings =
    guardedMissingFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedMissingFindings =
    [ finding "PLAN-TRACKER-MISSING" trackerPath ("tracker omits Phase " <> showText number)
    | number <- Set.toAscList (expected Set.\\ actual)
    ]
  statusFindings =
    guardedStatusFindings
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_STATUS_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedStatusFindings = concatMap checkStatus rows
  checkStatus row =
    let expectedStatus = Policy.resetPhaseStatusText (policyResetStatus (trackerNumber row))
     in [ finding
            "PLAN-TRACKER-STATUS"
            trackerPath
            ("Phase " <> showText (trackerNumber row) <> " tracker status must equal '" <> expectedStatus <> "'")
        | Text.strip (trackerStatus row) /= expectedStatus
        ]
          <> [ finding
                 "PLAN-TRACKER-STATUS"
                 trackerPath
                 ("Phase " <> showText (trackerNumber row) <> " tracker status carries a forbidden Done marker")
             | "Done" `Text.isInfixOf` trackerStatus row || "✅" `Text.isInfixOf` trackerStatus row
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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_TITLE_JOIN_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
  guardedTitleFinding phase row =
    [ finding
        "PLAN-TRACKER-TITLE"
        trackerPath
        ("Phase " <> showText (trackerNumber row) <> " tracker name differs from its H1 title")
    | phaseTitle phase /= Just (trackerTitle row)
    ]
  contractFinding phase row =
    guardedContractFinding phase row
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_CONTRACT_JOIN_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_PROJECTION_JOIN_FINDING_BYPASS_MUTANT)
      `seq` []
#endif
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
#if defined(VALIDATION_PHASE_CONTRACT_TRACKER_PROJECTION_PREFIX_BYPASS_MUTANT)
trackerProjectionMatches phaseValue trackerValue = firstToken phaseValue == firstToken trackerValue
#else
trackerProjectionMatches phaseValue trackerValue = firstToken phaseValue == trackerValue
#endif

checkProjectionVocabulary :: Map Int PhaseDocument -> [TrackerRow] -> [Finding]
checkProjectionVocabulary phases rows =
#if defined(VALIDATION_PHASE_CONTRACT_PROJECTION_VOCABULARY_BYPASS_MUTANT)
  length vocabularyFindings `seq` []
#else
  vocabularyFindings
#endif
 where
  vocabularyFindings = concatMap checkPhase (Map.elems phases) <> concatMap checkTracker rows
  checkPhase phase =
    checkPhaseValue (phasePath phase) "Substrate" substrateVocabulary (phaseValue phase "Substrate")
      <> checkPhaseValue (phasePath phase) "Lane" laneVocabulary (phaseValue phase "Lane")
      <> checkPhaseValue (phasePath phase) "Register" registerVocabulary (phaseValue phase "Register")
  checkTracker row =
    checkTrackerValue trackerPath (phaseLabel row "Substrate") substrateVocabulary (trackerSubstrate row)
      <> checkTrackerValue trackerPath (phaseLabel row "Lane") laneVocabulary (trackerLane row)
      <> checkTrackerValue trackerPath (phaseLabel row "Register") registerVocabulary (trackerRegister row)
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
#if defined(VALIDATION_PHASE_CONTRACT_CONTAINER_PREFIX_BYPASS_MUTANT)
containerDisposition active rawLine =
  active
    `seq` hasExplicitContainerMarker rawLine
    `seq` hasContainerContinuationIndent rawLine
    `seq` ContainerTopLevel (containerSyntaxLine rawLine)
#else
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
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_FENCE_BOUNDARY_BYPASS_MUTANT)
prependFenceBoundary _ visible = visible
#else
prependFenceBoundary lineNumber visible = OpaqueBoundary lineNumber : visible
#endif

topLevelStructuralLine :: Text -> Maybe Text
#if defined(VALIDATION_PHASE_CONTRACT_INDENTED_CODE_BYPASS_MUTANT)
topLevelStructuralLine = Just . Text.stripStart
#else
topLevelStructuralLine line =
  let (indent, remainder) = Text.span (== ' ') line
   in if Text.length indent <= 3 && not ("\t" `Text.isPrefixOf` remainder)
        then Just remainder
        else Nothing
#endif

maskHtmlComments :: Bool -> Text -> (Bool, Text)
maskHtmlComments initiallyActive input =
#if defined(VALIDATION_PHASE_CONTRACT_COMMENT_OPACITY_BYPASS_MUTANT)
  guardedMaskHtmlComments initiallyActive input `seq` (False, input)
#else
  guardedMaskHtmlComments initiallyActive input
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_COMMENT_SPLICE_BYPASS_MUTANT)
phaseContractCommentSentinel = ""
#else
phaseContractCommentSentinel = "!"
#endif

htmlBlockOpener :: Text -> Maybe HtmlBlock
#if defined(VALIDATION_PHASE_CONTRACT_RAW_HTML_BYPASS_MUTANT)
htmlBlockOpener line = classifiedHtmlBlockOpener line `seq` Nothing
#else
htmlBlockOpener = classifiedHtmlBlockOpener
#endif

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
#if defined(VALIDATION_PHASE_CONTRACT_FENCE_OPACITY_BYPASS_MUTANT)
  classifiedFenceOpener line `seq` Nothing
#else
  classifiedFenceOpener line
#endif

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

policyOrdering :: Policy.OrderingContract
policyOrdering = Policy.orderingContract Policy.canonicalPolicyContract

policyStatusReset :: Policy.StatusResetContract
policyStatusReset = Policy.statusResetContract Policy.canonicalPolicyContract

policyResetStatus :: Int -> Policy.ResetPhaseStatus
policyResetStatus number
  | number == phaseDomainLowerNumber = Policy.phaseZeroResetStatus policyStatusReset
  | otherwise = Policy.laterPhaseResetStatus policyStatusReset

phaseDomainLowerNumber :: Int
phaseDomainLowerNumber = Policy.phaseOrdinalNumber (Policy.phaseDomainLower policyOrdering)

phaseDomainUpperNumber :: Int
phaseDomainUpperNumber = Policy.phaseOrdinalNumber (Policy.phaseDomainUpper policyOrdering)

phaseDomainLabel :: Text
phaseDomainLabel = showText phaseDomainLowerNumber <> ".." <> showText phaseDomainUpperNumber

policyPredecessorNumber :: Int -> Int
policyPredecessorNumber number = case Policy.predecessorRule policyOrdering of
  Policy.ImmediateNumericPredecessor -> number - 1
