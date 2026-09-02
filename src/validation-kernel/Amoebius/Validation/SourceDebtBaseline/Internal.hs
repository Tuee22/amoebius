{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceDebtBaseline.Internal
  ( SourceDebtEvidence
  , analyzeAcquiredSourceDebt
  , foldAcquiredSourceDebtState
  , sourceDebtClosureDiagnosticCheck
  , sourceDebtEvidenceCheck
  , sourceDebtRawDiagnosticCheck
#if defined(VALIDATION_SOURCE_DEBT_INTERNAL_TEST_HOOKS)
  , sourceDebtInternalTestIntegrityFindings
  , sourceDebtInternalTestProblemFindings
  , sourceDebtInternalTestStateResults
#endif
  ) where

-- The frozen baseline, observations, comparison problems, and comparison
-- functions are deliberately private. A caller-authored SourceClosure can
-- exercise this component only through the permanently refusing diagnostic
-- front. Candidate composition starts from AcquiredSourceSnapshot and carries
-- opaque, snapshot-bound evidence into every consumer.

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , ClassifiedPath (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SourceClosure
  , SourceClass (..)
  , SourceDebtId (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  , classifySnapshot
  , closurePaths
  , pbTrackedFilesFromSnapshot
  , renderSourceDebtId
  , snapshotIdentity
  )
import Amoebius.Validation.PbBootstrapGrammar.Internal qualified as Pb
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation
  , checkPassed
  , finding
  , observation
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, ord)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

data SourceDebtBaseline = SourceDebtBaseline Int
  deriving (Eq, Ord, Show)

data SourceDebtObservation = SourceDebtObservation Int Text Text
  deriving (Eq, Ord, Show)

data SourceDebtProblem
  = SourceDebtBaselineFamilySetMismatch (Set SourceDebtId) (Set SourceDebtId)
  | SourceDebtFamilySetMismatch (Set SourceDebtId) (Set SourceDebtId)
  | SourcePbObservationPresent SourceDebtObservation
  | SourceDebtPathCountMismatch SourceDebtId Int Int
  deriving (Eq, Ord, Show)

data SourceDebtState
  = SourceDebtStateOpen Int Text
  | SourceDebtStateZero
  | SourceDebtStateRefused Text
  deriving (Eq, Ord, Show)

-- | Candidate evidence is inseparable from the exact acquired snapshot that
-- produced it. Its constructor and every projection remain private.
data SourceDebtEvidence
  = SourceDebtEvidence AcquiredSourceSnapshot CheckResult (Map SourceDebtId SourceDebtState)

data SourceDebtAnalysis
  = SourceDebtAnalysis CheckResult (Map SourceDebtId SourceDebtState)

data BoundedPrefix value
  = PrefixWithin [value]
  | PrefixExceeded Int

data SourceDebtResourceFailure
  = SourceDebtPathUtf8LimitExceeded Integer
  | SourceDebtObjectIdLimitExceeded Integer
  | SourceDebtBlobLimitExceeded Integer
  | SourceDebtAggregateBlobLimitExceeded Integer

data PreparedSourceDebt
  = PreparedSourceDebt (Map SourceDebtId [TrackedEntry])

maximumSourceDebtPreallocationEntries :: Int
#if defined(VALIDATION_SOURCE_DEBT_PREALLOCATION_LIMIT_WIDEN_MUTANT)
maximumSourceDebtPreallocationEntries = 1469
#else
maximumSourceDebtPreallocationEntries = 1468
#endif

maximumSourceDebtTraversalEntries :: Int
#if defined(VALIDATION_SOURCE_DEBT_TRAVERSAL_LIMIT_WIDEN_MUTANT)
maximumSourceDebtTraversalEntries = 16385
#else
maximumSourceDebtTraversalEntries = 16384
#endif

maximumSourceDebtProblems :: Int
#if defined(VALIDATION_SOURCE_DEBT_PROBLEM_LIMIT_WIDEN_MUTANT)
maximumSourceDebtProblems = 25
#else
maximumSourceDebtProblems = 24
#endif

maximumSourceDebtObservations :: Int
#if defined(VALIDATION_SOURCE_DEBT_OBSERVATION_LIMIT_NARROW_MUTANT)
maximumSourceDebtObservations = 28
#else
maximumSourceDebtObservations = 29
#endif

maximumSourceDebtPathUtf8Bytes :: Integer
#if defined(VALIDATION_SOURCE_DEBT_PATH_UTF8_LIMIT_WIDEN_MUTANT)
maximumSourceDebtPathUtf8Bytes = 1025
#else
maximumSourceDebtPathUtf8Bytes = 1024
#endif

maximumSourceDebtObjectIdUtf8Bytes :: Integer
#if defined(VALIDATION_SOURCE_DEBT_OBJECT_ID_LIMIT_WIDEN_MUTANT)
maximumSourceDebtObjectIdUtf8Bytes = 65
#else
maximumSourceDebtObjectIdUtf8Bytes = 64
#endif

maximumSourceDebtBlobBytes :: Integer
#if defined(VALIDATION_SOURCE_DEBT_BLOB_LIMIT_WIDEN_MUTANT)
maximumSourceDebtBlobBytes = 16777217
#else
maximumSourceDebtBlobBytes = 16777216
#endif

maximumSourceDebtAggregateBlobBytes :: Integer
#if defined(VALIDATION_SOURCE_DEBT_AGGREGATE_BLOB_LIMIT_WIDEN_MUTANT)
maximumSourceDebtAggregateBlobBytes = 33554433
#else
maximumSourceDebtAggregateBlobBytes = 33554432
#endif

allSourceDebtIds :: [SourceDebtId]
allSourceDebtIds =
  concat
    [
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_TOOLS_OMISSION_MUTANT)
      []
#else
      [SourceTools]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_DHALL_OMISSION_MUTANT)
    , []
#else
    , [SourceDhall]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_PROTO_OMISSION_MUTANT)
    , []
#else
    , [SourceProto]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_UI_OMISSION_MUTANT)
    , []
#else
    , [SourceUi]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_PULUMI_OMISSION_MUTANT)
    , []
#else
    , [SourcePulumi]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_TEST_OMISSION_MUTANT)
    , []
#else
    , [SourceTest]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_PROBE_OMISSION_MUTANT)
    , []
#else
    , [SourceProbe]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_PB_OMISSION_MUTANT)
    , []
#else
    , [SourcePb]
#endif
#if defined(VALIDATION_SOURCE_DEBT_ALL_ID_VENDOR_OMISSION_MUTANT)
    , []
#else
    , [SourceVendor]
#endif
    ]

laterOwnedSourceDebtIds :: Set SourceDebtId
laterOwnedSourceDebtIds =
  Set.fromList
    ( concat
        [
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_TOOLS_OMISSION_MUTANT)
          []
#else
          [SourceTools]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_DHALL_OMISSION_MUTANT)
        , []
#else
        , [SourceDhall]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_PROTO_OMISSION_MUTANT)
        , []
#else
        , [SourceProto]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_UI_OMISSION_MUTANT)
        , []
#else
        , [SourceUi]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_PULUMI_OMISSION_MUTANT)
        , []
#else
        , [SourcePulumi]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_TEST_OMISSION_MUTANT)
        , []
#else
        , [SourceTest]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_PROBE_OMISSION_MUTANT)
        , []
#else
        , [SourceProbe]
#endif
#if defined(VALIDATION_SOURCE_DEBT_LATER_ID_VENDOR_OMISSION_MUTANT)
        , []
#else
        , [SourceVendor]
#endif
        ]
    )

laterOwnedSourceDebtBaselines :: Map SourceDebtId SourceDebtBaseline
laterOwnedSourceDebtBaselines =
  Map.fromList
    [ (identifier, baseline)
    | identifier <- Set.toAscList laterOwnedSourceDebtIds
    , Just baseline <- [sourceDebtBaseline identifier]
    ]

-- Total over the closed SourceDebtId universe. Pb is Phase-0-owned and has no
-- later-owned baseline; every other constructor has one exact frozen row.
sourceDebtBaseline :: SourceDebtId -> Maybe SourceDebtBaseline
sourceDebtBaseline SourceTools =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_TOOLS_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_MUTANT)
        238
#else
        237
#endif
    )
#endif
sourceDebtBaseline SourceDhall =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_DHALL_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_DHALL_COUNT_MUTANT)
        280
#else
        279
#endif
    )
#endif
sourceDebtBaseline SourceProto =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROTO_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROTO_COUNT_MUTANT)
        2
#else
        1
#endif
    )
#endif
sourceDebtBaseline SourceUi =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_UI_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_UI_COUNT_MUTANT)
        17
#else
        16
#endif
    )
#endif
sourceDebtBaseline SourcePulumi =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_COUNT_MUTANT)
        2
#else
        1
#endif
    )
#endif
sourceDebtBaseline SourceTest =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_TEST_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_TEST_COUNT_MUTANT)
        891
#else
        890
#endif
    )
#endif
sourceDebtBaseline SourceProbe =
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROBE_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROBE_COUNT_MUTANT)
        8
#else
        7
#endif
    )
#endif
sourceDebtBaseline SourcePb = Nothing
sourceDebtBaseline SourceVendor =
#if defined(VALIDATION_SOURCE_DEBT_OMISSION_MUTANT)
  Nothing
#else
  Just
    ( SourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_COUNT_MUTANT)
        29
#else
        28
#endif
    )
#endif

-- | Analyze only an opaque acquired snapshot. There is no public constructor
-- for the resulting evidence and no public baseline, observation, or problem
-- projection with which a caller can fabricate an accepted comparison.
analyzeAcquiredSourceDebt :: AcquiredSourceSnapshot -> SourceDebtEvidence
analyzeAcquiredSourceDebt acquired =
  SourceDebtEvidence
    acquired
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_RESULT_ASSEMBLY_MUTANT)
    (result {checkObservations = []})
#else
    admittedResult
#endif
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_STATE_ASSEMBLY_MUTANT)
    (states `seq` Map.empty)
#else
    admittedStates
#endif
 where
  snapshot = acquiredSourceSnapshot acquired
  closure = classifySnapshot snapshot
  SourceDebtAnalysis result states = analyzeSourceDebt closure
  pbAdmitted = checkPassed (Pb.pbBootstrapGrammarCandidate (pbTrackedFilesFromSnapshot snapshot))
  admittedResult
    | pbAdmitted =
        result
          { checkFindings = filter (not . isPbDebtPresenceFinding) (checkFindings result)
          }
    | otherwise = result
  admittedStates
    | pbAdmitted = Map.insert SourcePb SourceDebtStateZero states
    | otherwise = states

isPbDebtPresenceFinding :: Finding -> Bool
isPbDebtPresenceFinding item =
  findingCode item == "SOURCE-DEBT-PB-NOT-ZERO"
    && findingSubject item == "LTD-SRC-008"

-- | Extract the candidate CheckResult only while rejoining the evidence to the
-- exact opaque capture. A value analyzed from another snapshot refuses.
sourceDebtEvidenceCheck
  :: AcquiredSourceSnapshot
  -> SourceDebtEvidence
  -> CheckResult
sourceDebtEvidenceCheck acquired (SourceDebtEvidence evidenceAcquired result _)
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_MATCH_PREDICATE_MUTANT)
  | acquired /= evidenceAcquired = result
#else
  | acquired == evidenceAcquired = result
#endif
  | otherwise =
      result
        { checkFindings =
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_COMPOSITION_MUTANT)
            checkFindings result `seq` [sourceDebtEvidenceMismatchFinding expectedIdentity evidenceIdentity]
#else
            checkFindings result
              <> [sourceDebtEvidenceMismatchFinding expectedIdentity evidenceIdentity]
#endif
        }
 where
  expectedIdentity = snapshotIdentity (acquiredSourceSnapshot acquired)
  evidenceIdentity = snapshotIdentity (acquiredSourceSnapshot evidenceAcquired)

-- | The only source-debt state eliminator used by Legacy. Callers choose how
-- to represent open/zero/refused states, but cannot construct the state being
-- eliminated. Missing registry entries and cross-snapshot evidence refuse.
foldAcquiredSourceDebtState
  :: AcquiredSourceSnapshot
  -> SourceDebtEvidence
  -> SourceDebtId
  -> (Text -> result)
  -> result
  -> (Int -> Text -> result)
  -> result
foldAcquiredSourceDebtState acquired (SourceDebtEvidence evidenceAcquired _ states) identifier onRefused onZero onOpen
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_SNAPSHOT_PREDICATE_MUTANT)
  | acquired == evidenceAcquired =
      expectedIdentity `seq` evidenceIdentity `seq` onRefused "source-debt evidence snapshot mismatch mutant"
#else
  | acquired /= evidenceAcquired =
      onRefused
        ( "source-debt evidence snapshot mismatch: expected="
            <> expectedIdentity
            <> ", actual="
            <> evidenceIdentity
        )
#endif
  | otherwise = case Map.lookup identifier states of
      Nothing -> onRefused ("closed source-debt evidence is missing " <> renderSourceDebtId identifier)
      Just state -> foldSourceDebtState state onRefused onZero onOpen
 where
  expectedIdentity = snapshotIdentity (acquiredSourceSnapshot acquired)
  evidenceIdentity = snapshotIdentity (acquiredSourceSnapshot evidenceAcquired)

sourceDebtEvidenceMismatchFinding :: Text -> Text -> Finding
sourceDebtEvidenceMismatchFinding expected actual =
  finding
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_CODE_MUTANT)
    "SOURCE-DEBT-EVIDENCE-SNAPSHOT-MISMATCH-MUTANT"
#else
    "SOURCE-DEBT-EVIDENCE-SNAPSHOT-MISMATCH"
#endif
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_SUBJECT_MUTANT)
    "source-debt-baseline-mutant"
#else
    "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_DETAIL_MUTANT)
    (expected `seq` actual `seq` "mutant")
#else
    ("expected=" <> expected <> ", actual=" <> actual)
#endif

foldSourceDebtState
  :: SourceDebtState
  -> (Text -> result)
  -> result
  -> (Int -> Text -> result)
  -> result
foldSourceDebtState state onRefused onZero onOpen = case state of
  SourceDebtStateOpen count fingerprint ->
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_ROUTE_MUTANT)
    count `seq` fingerprint `seq` onOpen 0 "" `seq` onZero
#else
    onOpen
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_COUNT_MUTANT)
      (count `seq` 0)
#else
      count
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_FINGERPRINT_MUTANT)
      (fingerprint `seq` "")
#else
      fingerprint
#endif
#endif
  SourceDebtStateZero ->
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_ZERO_ROUTE_MUTANT)
    onZero `seq` onRefused "source-debt zero route mutant"
#else
    onZero
#endif
  SourceDebtStateRefused detail ->
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_ROUTE_MUTANT)
    detail `seq` onRefused "" `seq` onZero
#else
    onRefused
#if defined(VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_DETAIL_MUTANT)
      (detail `seq` "mutant")
#else
      detail
#endif
#endif

-- | The raw standard-value facade is bounded before it constructs production
-- source types. Mode text has one closed interpretation and invalid values
-- refuse explicitly instead of being coerced to a production constructor.
sourceDebtRawDiagnosticCheck
  :: [(FilePath, Text, Text, ByteString.ByteString)]
  -> CheckResult
sourceDebtRawDiagnosticCheck rawEntries =
  case boundedPrefix maximumSourceDebtTraversalEntries rawEntries of
    PrefixExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_RAW_TRAVERSAL_RESULT_ROUTE_MUTANT)
      observedAtLeast `seq`
        diagnosticResult (analysisResult (analyzeBoundedSourceDebt (PreparedSourceDebt Map.empty)))
#else
      diagnosticResult
        ( analysisResult
            ( limitAnalysis
                "traversal"
                "SOURCE-DEBT-TRAVERSAL-LIMIT"
                maximumSourceDebtTraversalEntries
                observedAtLeast
            )
        )
#endif
    PrefixWithin boundedEntries ->
      case rawSourceDebtResourceFailure boundedEntries of
        Just resourceFailure ->
#if defined(VALIDATION_SOURCE_DEBT_RAW_RESOURCE_RESULT_ROUTE_MUTANT)
          resourceFailure `seq`
            diagnosticResult (analysisResult (analyzeBoundedSourceDebt (PreparedSourceDebt Map.empty)))
#else
          diagnosticResult
            (analysisResult (resourceLimitAnalysis resourceFailure))
#endif
        Nothing ->
          case traverse rawTrackedEntry boundedEntries of
            Left _ ->
              CheckResult
                { checkName =
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_RESULT_NAME_MUTANT)
                    "source-debt-baseline-mutant"
#else
                    "source-debt-baseline"
#endif
                , checkObservations =
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_RESULT_OBSERVATIONS_MUTANT)
                    [observation "source-debt.raw-mode-mutant" "mutant"]
#else
                    []
#endif
                , checkFindings =
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_FINDING_COMPOSITION_MUTANT)
                    sourceDebtDiagnosticFindings `seq`
                      [ finding
#else
                    sourceDebtDiagnosticFindings
                      <> [ finding
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_FINDING_CODE_MUTANT)
                             "SOURCE-DEBT-RAW-MODE-INVALID-MUTANT"
#else
                             "SOURCE-DEBT-RAW-MODE-INVALID"
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_FINDING_SUBJECT_MUTANT)
                             "source-debt-baseline-mutant"
#else
                             "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_FINDING_DETAIL_MUTANT)
                             "mutant"
#else
                             "raw mode must be exactly one of 100644,100755,120000"
#endif
                         ]
                }
            Right entries ->
              sourceDebtClosureDiagnosticCheck
                ( classifySnapshot
                    SourceSnapshot
                      { snapshotRoot = "<caller-supplied-source-debt>"
                      , snapshotIdentity = "<caller-supplied-source-debt>"
                      , snapshotEntries = entries
                      }
                )

-- Bound every caller-supplied field before SourceClosure classifies paths or
-- inspects bytes.  The later acquired-closure preparation repeats the same
-- limits over registered members because it cannot trust this diagnostic
-- ingress, but the raw facade must not reach that semantic traversal first.
rawSourceDebtResourceFailure
  :: [(FilePath, Text, Text, ByteString.ByteString)]
  -> Maybe SourceDebtResourceFailure
rawSourceDebtResourceFailure = go 0
 where
  go _ [] = Nothing
  go aggregateBytes ((path, _mode, objectId, bytes) : rest) =
    let pathBytes =
#if defined(VALIDATION_SOURCE_DEBT_RAW_PATH_RESOURCE_PROJECTION_MUTANT)
          boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes path `seq` 0
#else
          boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes path
#endif
        objectIdBytes =
#if defined(VALIDATION_SOURCE_DEBT_RAW_OBJECT_ID_RESOURCE_PROJECTION_MUTANT)
          boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes objectId `seq` 0
#else
          boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes objectId
#endif
        blobBytes =
#if defined(VALIDATION_SOURCE_DEBT_RAW_BLOB_RESOURCE_PROJECTION_MUTANT)
          boundedByteStringLength maximumSourceDebtBlobBytes bytes `seq` 0
#else
          boundedByteStringLength maximumSourceDebtBlobBytes bytes
#endif
        nextAggregate =
#if defined(VALIDATION_SOURCE_DEBT_RAW_AGGREGATE_RESOURCE_TRANSITION_MUTANT)
          min
            (maximumSourceDebtAggregateBlobBytes + 1)
            aggregateBytes
#else
          min
            (maximumSourceDebtAggregateBlobBytes + 1)
            (aggregateBytes + blobBytes)
#endif
     in if
#if defined(VALIDATION_SOURCE_DEBT_RAW_PATH_RESOURCE_PREDICATE_MUTANT)
          pathBytes `seq` False
#else
          pathBytes > maximumSourceDebtPathUtf8Bytes
#endif
          then Just (SourceDebtPathUtf8LimitExceeded pathBytes)
          else
            if
#if defined(VALIDATION_SOURCE_DEBT_RAW_OBJECT_ID_RESOURCE_PREDICATE_MUTANT)
              objectIdBytes `seq` False
#else
              objectIdBytes > maximumSourceDebtObjectIdUtf8Bytes
#endif
              then Just (SourceDebtObjectIdLimitExceeded objectIdBytes)
              else
                if
#if defined(VALIDATION_SOURCE_DEBT_RAW_BLOB_RESOURCE_PREDICATE_MUTANT)
                  blobBytes `seq` False
#else
                  blobBytes > maximumSourceDebtBlobBytes
#endif
                  then Just (SourceDebtBlobLimitExceeded blobBytes)
                  else
                    if
#if defined(VALIDATION_SOURCE_DEBT_RAW_AGGREGATE_RESOURCE_PREDICATE_MUTANT)
                      nextAggregate `seq` False
#else
                      nextAggregate > maximumSourceDebtAggregateBlobBytes
#endif
                      then Just (SourceDebtAggregateBlobLimitExceeded nextAggregate)
                      else go nextAggregate rest

rawTrackedEntry
  :: (FilePath, Text, Text, ByteString.ByteString)
  -> Either (FilePath, Text) TrackedEntry
rawTrackedEntry (path, mode, objectId, bytes) =
  case rawIndexMode mode of
    Nothing -> Left (path, mode)
    Just indexMode ->
      Right
        TrackedEntry
          { trackedIndex =
              IndexEntry
#if defined(VALIDATION_SOURCE_DEBT_RAW_ENTRY_PATH_PROJECTION_MUTANT)
                (path `seq` "src/ValidationSourceDebtMutant.hs")
#else
                path
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_ENTRY_MODE_PROJECTION_MUTANT)
                (indexMode `seq` SymbolicLink)
#else
                indexMode
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_ENTRY_OBJECT_ID_PROJECTION_MUTANT)
                (objectId `seq` "0000000000000000000000000000000000000000")
#else
                objectId
#endif
          , trackedBytes =
#if defined(VALIDATION_SOURCE_DEBT_RAW_ENTRY_BLOB_PROJECTION_MUTANT)
              bytes `seq` ByteString.empty
#else
              bytes
#endif
          }

rawIndexMode :: Text -> Maybe IndexMode
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_REGULAR_MAPPING_MUTANT)
rawIndexMode "100644" = Just ExecutableFile
#else
rawIndexMode "100644" = Just RegularFile
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_EXECUTABLE_MAPPING_MUTANT)
rawIndexMode "100755" = Just RegularFile
#else
rawIndexMode "100755" = Just ExecutableFile
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_SYMLINK_MAPPING_MUTANT)
rawIndexMode "120000" = Just RegularFile
#else
rawIndexMode "120000" = Just SymbolicLink
#endif
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_BYPASS_MUTANT)
rawIndexMode _ = Just RegularFile
#else
rawIndexMode _ = Nothing
#endif

analysisResult :: SourceDebtAnalysis -> CheckResult
#if defined(VALIDATION_SOURCE_DEBT_ANALYSIS_RESULT_PROJECTION_MUTANT)
analysisResult (SourceDebtAnalysis result _) = result {checkFindings = []}
#else
analysisResult (SourceDebtAnalysis result _) = result
#endif

diagnosticResult :: CheckResult -> CheckResult
diagnosticResult result =
#if defined(VALIDATION_SOURCE_DEBT_DIAGNOSTIC_RESULT_COMPOSITION_MUTANT)
  result {checkFindings = checkFindings result `seq` sourceDebtDiagnosticFindings}
#else
  result {checkFindings = sourceDebtDiagnosticFindings <> checkFindings result}
#endif

-- | The private raw-closure front is permanently diagnostic. Even exact
-- frozen bytes
-- retain this refusal, so a caller-authored closure can never become candidate
-- evidence by happening to produce no comparison findings.
sourceDebtClosureDiagnosticCheck :: SourceClosure -> CheckResult
sourceDebtClosureDiagnosticCheck = diagnosticResult . analysisResult . analyzeSourceDebt

sourceDebtDiagnosticFindings :: [Finding]
#if defined(VALIDATION_SOURCE_DEBT_DIAGNOSTIC_BYPASS_MUTANT)
sourceDebtDiagnosticFindings = []
#else
sourceDebtDiagnosticFindings =
  [ finding
#if defined(VALIDATION_SOURCE_DEBT_DIAGNOSTIC_FINDING_CODE_MUTANT)
      "SOURCE-DEBT-DIAGNOSTIC-ONLY-MUTANT"
#else
      "SOURCE-DEBT-DIAGNOSTIC-ONLY"
#endif
#if defined(VALIDATION_SOURCE_DEBT_DIAGNOSTIC_FINDING_SUBJECT_MUTANT)
      "<caller-supplied-source-closure-mutant>"
#else
      "<caller-supplied-source-closure>"
#endif
#if defined(VALIDATION_SOURCE_DEBT_DIAGNOSTIC_FINDING_DETAIL_MUTANT)
      "mutant"
#else
      "caller-supplied source-debt observations are diagnostic input, not candidate capture authority"
#endif
  ]
#endif

analyzeSourceDebt :: SourceClosure -> SourceDebtAnalysis
analyzeSourceDebt closure =
  case boundedPrefix maximumSourceDebtTraversalEntries (closurePaths closure) of
    PrefixExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_ANALYSIS_TRAVERSAL_RESULT_ROUTE_MUTANT)
      observedAtLeast `seq` analyzeBoundedSourceDebt (PreparedSourceDebt Map.empty)
#else
      limitAnalysis
        "traversal"
        "SOURCE-DEBT-TRAVERSAL-LIMIT"
        maximumSourceDebtTraversalEntries
        observedAtLeast
#endif
    PrefixWithin _ ->
      case boundedPrefix maximumSourceDebtPreallocationEntries registeredPaths of
        PrefixExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_ANALYSIS_PREALLOCATION_RESULT_ROUTE_MUTANT)
          observedAtLeast `seq` analyzeBoundedSourceDebt (PreparedSourceDebt Map.empty)
#else
          limitAnalysis
            "preallocation"
            "SOURCE-DEBT-PREALLOCATION-LIMIT"
            maximumSourceDebtPreallocationEntries
            observedAtLeast
#endif
        PrefixWithin _ -> case prepareSourceDebt closure of
          Left resourceFailure ->
#if defined(VALIDATION_SOURCE_DEBT_ANALYSIS_RESOURCE_RESULT_ROUTE_MUTANT)
            resourceFailure `seq` analyzeBoundedSourceDebt (PreparedSourceDebt Map.empty)
#else
            resourceLimitAnalysis resourceFailure
#endif
          Right prepared -> analyzeBoundedSourceDebt prepared
 where
  registeredPaths =
    [ ()
    | classified <- closurePaths closure
#if defined(VALIDATION_SOURCE_DEBT_REGISTERED_PATH_CLASSIFICATION_MUTANT)
    , classifiedAs classified `seq` False
#else
    , RegisteredLegacy _ <- [classifiedAs classified]
#endif
    ]

prepareSourceDebt :: SourceClosure -> Either SourceDebtResourceFailure PreparedSourceDebt
prepareSourceDebt closure =
  go 0 Map.empty (closurePaths closure)
 where
  go _ members [] = Right (PreparedSourceDebt members)
  go aggregateBytes members (classified : rest) =
    case classifiedAs classified of
      RegisteredLegacy identifier ->
        let entry = classifiedEntry classified
            indexed = trackedIndex entry
            pathBytes =
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PROJECTION_MUTANT)
              boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes (indexPath indexed) `seq` 0
#else
              boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes (indexPath indexed)
#endif
            objectIdBytes =
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PROJECTION_MUTANT)
              boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes (indexObjectId indexed) `seq` 0
#else
              boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes (indexObjectId indexed)
#endif
            blobBytes =
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PROJECTION_MUTANT)
              boundedByteStringLength maximumSourceDebtBlobBytes (trackedBytes entry) `seq` 0
#else
              boundedByteStringLength maximumSourceDebtBlobBytes (trackedBytes entry)
#endif
            nextAggregate =
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_TRANSITION_MUTANT)
              min
                (maximumSourceDebtAggregateBlobBytes + 1)
                aggregateBytes
#else
              min
                (maximumSourceDebtAggregateBlobBytes + 1)
                (aggregateBytes + blobBytes)
#endif
         in if
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PREDICATE_MUTANT)
              pathBytes `seq` False
#else
              pathBytes > maximumSourceDebtPathUtf8Bytes
#endif
              then Left (SourceDebtPathUtf8LimitExceeded pathBytes)
              else
                if
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PREDICATE_MUTANT)
                  objectIdBytes `seq` False
#else
                  objectIdBytes > maximumSourceDebtObjectIdUtf8Bytes
#endif
                  then Left (SourceDebtObjectIdLimitExceeded objectIdBytes)
                  else
                    if
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PREDICATE_MUTANT)
                      blobBytes `seq` False
#else
                      blobBytes > maximumSourceDebtBlobBytes
#endif
                      then Left (SourceDebtBlobLimitExceeded blobBytes)
                      else
                        if
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_PREDICATE_MUTANT)
                          nextAggregate `seq` False
#else
                          nextAggregate > maximumSourceDebtAggregateBlobBytes
#endif
                          then Left (SourceDebtAggregateBlobLimitExceeded nextAggregate)
                          else
                            go
                              nextAggregate
                              ( Map.insertWith
                                  (<>)
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_FAMILY_PROJECTION_MUTANT)
                                  (identifier `seq` SourceTools)
#else
                                  identifier
#endif
#if defined(VALIDATION_SOURCE_DEBT_PREPARED_ENTRY_PROJECTION_MUTANT)
                                  (entry `seq` [])
#else
                                  [entry]
#endif
                                  members
                              )
                              rest
      _ -> go aggregateBytes members rest

boundedFilePathUtf8Length :: Integer -> FilePath -> Integer
boundedFilePathUtf8Length maximumBytes = go 0
 where
  go observed _
#if defined(VALIDATION_SOURCE_DEBT_PATH_LENGTH_EARLY_PREDICATE_MUTANT)
    | observed >= maximumBytes = maximumBytes + 1
#else
    | observed > maximumBytes = maximumBytes + 1
#endif
  go observed [] = observed
  go observed (character : rest) =
#if defined(VALIDATION_SOURCE_DEBT_PATH_LENGTH_TRANSITION_MUTANT)
    utf8CharacterBytes character `seq` go observed rest
#else
    go (min (maximumBytes + 1) (observed + utf8CharacterBytes character)) rest
#endif

boundedTextUtf8Length :: Integer -> Text -> Integer
boundedTextUtf8Length maximumBytes = go 0
 where
  go observed _
#if defined(VALIDATION_SOURCE_DEBT_TEXT_LENGTH_EARLY_PREDICATE_MUTANT)
    | observed >= maximumBytes = maximumBytes + 1
#else
    | observed > maximumBytes = maximumBytes + 1
#endif
  go observed remaining = case Text.uncons remaining of
    Nothing -> observed
    Just (character, rest) ->
#if defined(VALIDATION_SOURCE_DEBT_TEXT_LENGTH_TRANSITION_MUTANT)
      utf8CharacterBytes character `seq` go observed rest
#else
      go (min (maximumBytes + 1) (observed + utf8CharacterBytes character)) rest
#endif

boundedByteStringLength :: Integer -> ByteString.ByteString -> Integer
#if defined(VALIDATION_SOURCE_DEBT_BYTESTRING_LENGTH_PROJECTION_MUTANT)
boundedByteStringLength maximumBytes bytes = maximumBytes `seq` ByteString.length bytes `seq` 0
#else
boundedByteStringLength maximumBytes =
  min (maximumBytes + 1) . fromIntegral . ByteString.length
#endif

utf8CharacterBytes :: Char -> Integer
utf8CharacterBytes character
  | codePoint <= 0x7f =
#if defined(VALIDATION_SOURCE_DEBT_UTF8_ASCII_WIDTH_MUTANT)
      0
#else
      1
#endif
  | codePoint <= 0x7ff =
#if defined(VALIDATION_SOURCE_DEBT_UTF8_TWO_BYTE_WIDTH_MUTANT)
      0
#else
      2
#endif
  | codePoint <= 0xffff =
#if defined(VALIDATION_SOURCE_DEBT_UTF8_THREE_BYTE_WIDTH_MUTANT)
      0
#else
      3
#endif
  | otherwise =
#if defined(VALIDATION_SOURCE_DEBT_UTF8_FOUR_BYTE_WIDTH_MUTANT)
      0
#else
      4
#endif
 where
  codePoint = ord character

analyzeBoundedSourceDebt :: PreparedSourceDebt -> SourceDebtAnalysis
analyzeBoundedSourceDebt prepared =
  SourceDebtAnalysis result states
 where
  observed = observeSourceDebt prepared
  rawObservations =
    [ observation
        "source-debt.expected-family-count"
#if defined(VALIDATION_SOURCE_DEBT_EXPECTED_FAMILY_COUNT_PROJECTION_MUTANT)
        (renderInt (Set.size laterOwnedSourceDebtIds) `seq` "0")
#else
        (renderInt (Set.size laterOwnedSourceDebtIds))
#endif
    , observation
        "source-debt.actual-family-count"
#if defined(VALIDATION_SOURCE_DEBT_ACTUAL_FAMILY_COUNT_PROJECTION_MUTANT)
        (renderInt (Map.size observed) `seq` "0")
#else
        (renderInt (Map.size observed))
#endif
    ]
#if defined(VALIDATION_SOURCE_DEBT_OBSERVED_FAMILY_ORDER_MUTANT)
      <> concatMap renderObserved (reverse (Map.toAscList observed))
#else
      <> concatMap renderObserved (Map.toAscList observed)
#endif
  rawProblems = sourceDebtProblems observed
  observationBound = boundedPrefix maximumSourceDebtObservations rawObservations
  problemBound = boundedPrefix maximumSourceDebtProblems rawProblems
  observationLimitFindings = case observationBound of
    PrefixWithin _ -> []
    PrefixExceeded observedAtLeast ->
      [limitFinding "SOURCE-DEBT-OBSERVATION-LIMIT" maximumSourceDebtObservations observedAtLeast]
  boundedObservations = case observationBound of
    PrefixWithin values ->
#if defined(VALIDATION_SOURCE_DEBT_BOUNDED_OBSERVATION_PROJECTION_MUTANT)
      values `seq` []
#else
      values
#endif
    PrefixExceeded observedAtLeast ->
      limitObservations "observation" maximumSourceDebtObservations observedAtLeast
  boundedProblemFindings = case problemBound of
    PrefixWithin problems ->
#if defined(VALIDATION_SOURCE_DEBT_BOUNDED_PROBLEM_PROJECTION_MUTANT)
      map problemFinding problems `seq` []
#else
      map problemFinding problems
#endif
    PrefixExceeded observedAtLeast ->
      [limitFinding "SOURCE-DEBT-PROBLEM-LIMIT" maximumSourceDebtProblems observedAtLeast]
  result =
    CheckResult
      { checkName =
#if defined(VALIDATION_SOURCE_DEBT_RESULT_NAME_PROJECTION_MUTANT)
          "source-debt-baseline-mutant"
#else
          "source-debt-baseline"
#endif
      , checkObservations =
#if defined(VALIDATION_SOURCE_DEBT_RESULT_OBSERVATION_PROJECTION_MUTANT)
          boundedObservations `seq` []
#else
          boundedObservations
#endif
      , checkFindings =
#if defined(VALIDATION_SOURCE_DEBT_RESULT_FINDING_COMPOSITION_MUTANT)
          observationLimitFindings `seq` boundedProblemFindings `seq` stateIntegrityFindings states
#elif defined(VALIDATION_SOURCE_DEBT_RESULT_FINDING_ORDER_MUTANT)
          stateIntegrityFindings states <> boundedProblemFindings <> observationLimitFindings
#else
          observationLimitFindings <> boundedProblemFindings <> stateIntegrityFindings states
#endif
      }
  states = boundedSourceDebtStates observationBound problemBound observed

boundedSourceDebtStates
  :: BoundedPrefix Observation
  -> BoundedPrefix SourceDebtProblem
  -> Map SourceDebtId SourceDebtObservation
  -> Map SourceDebtId SourceDebtState
boundedSourceDebtStates observationBound problemBound observed
  | sourceDebtObservationBoundWithin observationBound
      && sourceDebtProblemBoundWithin problemBound =
      sourceDebtStates observed
  | otherwise =
      refusedStates "source-debt analysis exceeded a closed result bound"

sourceDebtObservationBoundWithin :: BoundedPrefix Observation -> Bool
sourceDebtObservationBoundWithin (PrefixWithin _) = True
sourceDebtObservationBoundWithin (PrefixExceeded _) =
#if defined(VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_BOUND_PREDICATE_MUTANT)
  True
#else
  False
#endif

sourceDebtProblemBoundWithin :: BoundedPrefix SourceDebtProblem -> Bool
sourceDebtProblemBoundWithin (PrefixWithin _) = True
sourceDebtProblemBoundWithin (PrefixExceeded _) =
#if defined(VALIDATION_SOURCE_DEBT_STATE_PROBLEM_BOUND_PREDICATE_MUTANT)
  True
#else
  False
#endif

observeSourceDebt :: PreparedSourceDebt -> Map SourceDebtId SourceDebtObservation
observeSourceDebt (PreparedSourceDebt membersByFamily) =
#if defined(VALIDATION_SOURCE_DEBT_OBSERVED_MAP_PROJECTION_MUTANT)
  Map.mapWithKey observeOne (Map.deleteMin membersByFamily)
#else
  Map.mapWithKey observeOne membersByFamily
#endif

observeOne :: SourceDebtId -> [TrackedEntry] -> SourceDebtObservation
observeOne identifier unsortedMembers =
  let actual =
        SourceDebtObservation
          (observedPathCount members)
          (observedFingerprint identifier members)
          (observedPathInventoryDigest identifier members)
      members =
#if defined(VALIDATION_SOURCE_DEBT_MEMBER_ORDER_PROJECTION_MUTANT)
        sortOn (indexPath . trackedIndex) unsortedMembers `seq` unsortedMembers
#else
        sortOn (indexPath . trackedIndex) unsortedMembers
#endif
#if defined(VALIDATION_SOURCE_DEBT_OBSERVER_FABRICATION_MUTANT)
   in actual `seq` SourceDebtObservation 0 _zeroDigest _zeroDigest
#else
   in actual
#endif

observedPathCount :: [TrackedEntry] -> Int
#if defined(VALIDATION_SOURCE_DEBT_COUNT_OBSERVER_FABRICATION_MUTANT)
observedPathCount members = length members `seq` 0
#else
observedPathCount = length
#endif

observedFingerprint :: SourceDebtId -> [TrackedEntry] -> Text
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_OBSERVER_FABRICATION_MUTANT)
observedFingerprint identifier members = sourceDebtFingerprintIncremental identifier members `seq` _zeroDigest
#else
observedFingerprint = sourceDebtFingerprintIncremental
#endif

observedPathInventoryDigest :: SourceDebtId -> [TrackedEntry] -> Text
#if defined(VALIDATION_SOURCE_DEBT_PATH_OBSERVER_FABRICATION_MUTANT)
observedPathInventoryDigest identifier members = sourceDebtPathInventoryDigest identifier members `seq` _zeroDigest
#else
observedPathInventoryDigest = sourceDebtPathInventoryDigest
#endif

sourceDebtFingerprintIncremental :: SourceDebtId -> [TrackedEntry] -> Text
sourceDebtFingerprintIncremental identifier members =
  hex (SHA256.finalize finalContext)
 where
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_DOMAIN_PROJECTION_MUTANT)
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-v1\0"
#else
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-v2\0"
#endif
  identifierContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_IDENTITY_PROJECTION_MUTANT)
    updateText domainContext (renderSourceDebtId identifier) `seq` domainContext
#else
    updateText domainContext (renderSourceDebtId identifier)
#endif
  prefixContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_IDENTIFIER_SEPARATOR_MUTANT)
    SHA256.update identifierContext nulByte `seq` identifierContext
#else
    SHA256.update identifierContext nulByte
#endif
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_MEMBER_ORDER_MUTANT)
  finalContext = foldl' updateDebtMember prefixContext (reverse members)
#else
  finalContext = foldl' updateDebtMember prefixContext members
#endif

updateDebtMember :: SHA256.Ctx -> TrackedEntry -> SHA256.Ctx
updateDebtMember initialContext entry =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_BLOB_SEPARATOR_MUTANT)
  SHA256.update blobSeparatorContext nulByte `seq` blobSeparatorContext
#else
  SHA256.update blobSeparatorContext nulByte
#endif
 where
  indexed = trackedIndex entry
  pathContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_PATH_PROJECTION_MUTANT)
    updateText initialContext (Text.pack (indexPath indexed)) `seq` initialContext
#else
    updateText initialContext (Text.pack (indexPath indexed))
#endif
  pathSeparatorContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_PATH_SEPARATOR_MUTANT)
    SHA256.update pathContext nulByte `seq` pathContext
#else
    SHA256.update pathContext nulByte
#endif
  modeContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_MODE_PROJECTION_MUTANT)
    updateText pathSeparatorContext (renderIndexMode (indexMode indexed)) `seq` pathSeparatorContext
#else
    updateText pathSeparatorContext (renderIndexMode (indexMode indexed))
#endif
  modeSeparatorContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_MODE_SEPARATOR_MUTANT)
    SHA256.update modeContext nulByte `seq` modeContext
#else
    SHA256.update modeContext nulByte
#endif
  objectContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_OBJECT_PROJECTION_MUTANT)
    updateText modeSeparatorContext (indexObjectId indexed) `seq` modeSeparatorContext
#else
    updateText modeSeparatorContext (indexObjectId indexed)
#endif
  objectSeparatorContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_OBJECT_SEPARATOR_MUTANT)
    SHA256.update objectContext nulByte `seq` objectContext
#else
    SHA256.update objectContext nulByte
#endif
  blobSeparatorContext =
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_BLOB_PROJECTION_MUTANT)
    updateText objectSeparatorContext (sourceDebtBlobCommitment entry) `seq` objectSeparatorContext
#else
    updateText objectSeparatorContext (sourceDebtBlobCommitment entry)
#endif

sourceDebtBlobCommitment :: TrackedEntry -> Text
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_BYTE_COMMITMENT_MUTANT)
sourceDebtBlobCommitment entry =
  sha256Incremental (trackedBytes entry)
    `seq` indexObjectId (trackedIndex entry)
#else
sourceDebtBlobCommitment = hex . sha256Incremental . trackedBytes
#endif

sourceDebtPathInventoryDigest :: SourceDebtId -> [TrackedEntry] -> Text
#if defined(VALIDATION_SOURCE_DEBT_PATH_INVENTORY_BYPASS_MUTANT)
sourceDebtPathInventoryDigest identifier members =
  sourceDebtPathInventoryDigestUnmutated identifier members
    `seq` sourceDebtFingerprintIncremental identifier members
#else
sourceDebtPathInventoryDigest = sourceDebtPathInventoryDigestUnmutated
#endif

sourceDebtPathInventoryDigestUnmutated :: SourceDebtId -> [TrackedEntry] -> Text
sourceDebtPathInventoryDigestUnmutated identifier members =
  hex (SHA256.finalize finalContext)
 where
#if defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_DOMAIN_PROJECTION_MUTANT)
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-path-inventory-v0\0"
#else
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-path-inventory-v1\0"
#endif
  identifierContext =
#if defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_IDENTITY_PROJECTION_MUTANT)
    updateText domainContext (renderSourceDebtId identifier) `seq` domainContext
#else
    updateText domainContext (renderSourceDebtId identifier)
#endif
  prefixContext =
#if defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_IDENTIFIER_SEPARATOR_MUTANT)
    SHA256.update identifierContext nulByte `seq` identifierContext
#else
    SHA256.update identifierContext nulByte
#endif
#if defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_MEMBER_ORDER_MUTANT)
  finalContext = foldl' updatePathMember prefixContext (reverse members)
#else
  finalContext = foldl' updatePathMember prefixContext members
#endif
  updatePathMember context entry =
#if defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_PATH_PROJECTION_MUTANT)
    updateText context (Text.pack (indexPath (trackedIndex entry))) `seq` SHA256.update context nulByte
#elif defined(VALIDATION_SOURCE_DEBT_PATH_DIGEST_MEMBER_SEPARATOR_MUTANT)
    SHA256.update
      (updateText context (Text.pack (indexPath (trackedIndex entry))))
      nulByte
      `seq` updateText context (Text.pack (indexPath (trackedIndex entry)))
#else
    SHA256.update
      (updateText context (Text.pack (indexPath (trackedIndex entry))))
      nulByte
#endif

sha256Incremental :: ByteString.ByteString -> ByteString.ByteString
sha256Incremental = SHA256.finalize . SHA256.update SHA256.init

updateText :: SHA256.Ctx -> Text -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_DEBT_UPDATE_TEXT_ENCODING_MUTANT)
updateText context value = TextEncoding.encodeUtf8 value `seq` context
#else
updateText context = SHA256.update context . TextEncoding.encodeUtf8
#endif

renderIndexMode :: IndexMode -> Text
#if defined(VALIDATION_SOURCE_DEBT_RENDER_MODE_REGULAR_MUTANT)
renderIndexMode RegularFile = "100755"
#else
renderIndexMode RegularFile = "100644"
#endif
#if defined(VALIDATION_SOURCE_DEBT_RENDER_MODE_EXECUTABLE_MUTANT)
renderIndexMode ExecutableFile = "100644"
#else
renderIndexMode ExecutableFile = "100755"
#endif
#if defined(VALIDATION_SOURCE_DEBT_RENDER_MODE_SYMLINK_MUTANT)
renderIndexMode SymbolicLink = "100644"
#else
renderIndexMode SymbolicLink = "120000"
#endif

nulByte :: ByteString.ByteString
nulByte = ByteString.singleton 0

sourceDebtProblems :: Map SourceDebtId SourceDebtObservation -> [SourceDebtProblem]
sourceDebtProblems observed =
#if defined(VALIDATION_SOURCE_DEBT_PROBLEM_CATEGORY_ORDER_MUTANT)
  comparisonProblems
    <> pbProblems
    <> observedFamilyProblems
    <> baselineFamilyProblems
#else
  baselineFamilyProblems
    <> observedFamilyProblems
    <> pbProblems
    <> comparisonProblems
#endif
 where
  comparisonProblems =
#if defined(VALIDATION_SOURCE_DEBT_COMPARISON_FAMILY_ORDER_MUTANT)
    concatMap compareOne (reverse (Map.toAscList laterOwnedSourceDebtBaselines))
#else
    concatMap compareOne (Map.toAscList laterOwnedSourceDebtBaselines)
#endif
  declaredFamilies =
#if defined(VALIDATION_SOURCE_DEBT_DECLARED_FAMILY_PROJECTION_MUTANT)
    Map.keysSet laterOwnedSourceDebtBaselines `seq` Set.empty
#else
    Map.keysSet laterOwnedSourceDebtBaselines
#endif
  baselineFamilyProblems =
    [ SourceDebtBaselineFamilySetMismatch laterOwnedSourceDebtIds declaredFamilies
    | not (sourceDebtBaselineFamilySetMatches laterOwnedSourceDebtIds declaredFamilies)
    ]
  actualLaterOwned =
#if defined(VALIDATION_SOURCE_DEBT_ACTUAL_FAMILY_PROJECTION_MUTANT)
    Set.delete SourcePb (Map.keysSet observed) `seq` Set.empty
#else
    Set.delete SourcePb (Map.keysSet observed)
#endif
  observedFamilyProblems =
#if defined(VALIDATION_SOURCE_DEBT_OBSERVED_FAMILY_PROBLEM_COMPOSITION_MUTANT)
    sourceDebtObservedFamilySetMatches laterOwnedSourceDebtIds actualLaterOwned `seq` []
#else
    [ SourceDebtFamilySetMismatch laterOwnedSourceDebtIds actualLaterOwned
    | not (sourceDebtObservedFamilySetMatches laterOwnedSourceDebtIds actualLaterOwned)
    ]
#endif
  pbProblems =
#if defined(VALIDATION_SOURCE_DEBT_PB_PROBLEM_COMPOSITION_MUTANT)
    Map.lookup SourcePb observed `seq` []
#else
    [ SourcePbObservationPresent value
    | not (sourceDebtPbIsZero observed)
#if defined(VALIDATION_SOURCE_DEBT_PB_OBSERVATION_PROJECTION_MUTANT)
    , Just value <- [Map.lookup SourcePb observed >>= const Nothing]
#else
    , Just value <- [Map.lookup SourcePb observed]
#endif
    ]
#endif
  compareOne (identifier, expected) = case Map.lookup identifier observed of
    Nothing -> []
    Just actual ->
      (
#if defined(VALIDATION_SOURCE_DEBT_COUNT_PROBLEM_COMPOSITION_MUTANT)
        sourceDebtCountMatches expected actual `seq` []
#else
        [ SourceDebtPathCountMismatch
          identifier
#if defined(VALIDATION_SOURCE_DEBT_COUNT_EXPECTED_PROJECTION_MUTANT)
          (baselineCount expected `seq` 0)
#else
          (baselineCount expected)
#endif
#if defined(VALIDATION_SOURCE_DEBT_COUNT_ACTUAL_PROJECTION_MUTANT)
          (observationCount actual `seq` 0)
#else
          (observationCount actual)
#endif
      | not (sourceDebtCountMatches expected actual)
        ]
#endif
      )

sourceDebtBaselineFamilySetMatches :: Set SourceDebtId -> Set SourceDebtId -> Bool
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_SET_INVERSION_MUTANT)
sourceDebtBaselineFamilySetMatches expected actual = expected /= actual
#else
sourceDebtBaselineFamilySetMatches expected actual = expected == actual
#endif

-- | Observed families must be a subset of the declared universe.
--
-- Strict equality required every declared family to still have members, so a
-- family that reached zero — a completed migration — removed its own key and
-- refused. A subset still refuses an observed family outside the closed
-- universe, which is the property that matters.
sourceDebtObservedFamilySetMatches :: Set SourceDebtId -> Set SourceDebtId -> Bool
#if defined(VALIDATION_SOURCE_DEBT_OBSERVED_FAMILY_SET_BYPASS_MUTANT)
sourceDebtObservedFamilySetMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtObservedFamilySetMatches expected actual = actual `Set.isSubsetOf` expected
#endif

sourceDebtPbIsZero :: Map SourceDebtId SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_PB_ZERO_BYPASS_MUTANT)
sourceDebtPbIsZero observed = observed `seq` True
#else
sourceDebtPbIsZero = Map.notMember SourcePb
#endif

-- | The recorded count is a ceiling, not an equality.
--
-- Exact equality reddened Phase 0 whenever a tracked non-Haskell file was
-- added, renamed or deleted — and the companion fingerprint reddened it on a
-- one-byte edit. Both measured the live tree, and the documentation-suite gate
-- is re-derived inside every later phase's gate, so ordinary migration work
-- owned by other phases refused Phase 0. A ratchet keeps the property the
-- baseline exists for: debt may shrink freely and may never grow.
sourceDebtCountMatches :: SourceDebtBaseline -> SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_COUNT_COMPARISON_BYPASS_MUTANT)
sourceDebtCountMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtCountMatches expected actual = observationCount actual <= baselineCount expected
#endif



sourceDebtStates :: Map SourceDebtId SourceDebtObservation -> Map SourceDebtId SourceDebtState
sourceDebtStates observed =
  Map.fromList
    [ (
#if defined(VALIDATION_SOURCE_DEBT_STATE_INVENTORY_ID_PROJECTION_MUTANT)
        identifier `seq` SourcePb
#else
        identifier
#endif
      , sourceDebtState identifier observed
      )
    | identifier <- allSourceDebtIds
    ]

stateIntegrityFindings :: Map SourceDebtId SourceDebtState -> [Finding]
stateIntegrityFindings states =
#if defined(VALIDATION_SOURCE_DEBT_STATE_INTEGRITY_ORDER_MUTANT)
  zeroFindings <> keyFindings
#else
  keyFindings <> zeroFindings
#endif
 where
  expectedKeys = Set.fromList allSourceDebtIds
  actualKeys = Map.keysSet states
  keyFindings =
    [ finding
#if defined(VALIDATION_SOURCE_DEBT_STATE_INVENTORY_CODE_MUTANT)
        "SOURCE-DEBT-STATE-INVENTORY-MISMATCH-MUTANT"
#else
        "SOURCE-DEBT-STATE-INVENTORY-MISMATCH"
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_INVENTORY_SUBJECT_MUTANT)
        "source-debt-baseline-mutant"
#else
        "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_INVENTORY_DETAIL_MUTANT)
        (expectedKeys `seq` actualKeys `seq` "mutant")
#else
        ("expected=" <> renderIds expectedKeys <> ", actual=" <> renderIds actualKeys)
#endif
    | actualKeys /= expectedKeys
    ]
  -- A later-owned family at zero is a completed migration, which is the outcome
  -- the baseline exists to drive toward. Refusing it per family made the check
  -- punish success: retiring a family removed its key and reddened Phase 0 at
  -- the moment the work finished.
  --
  -- What is still refused is total collapse. Every later-owned family reaching
  -- zero at once is not eight completed migrations; it is a classifier that
  -- stopped recognising anything. This check cannot tell an individual
  -- retirement from an individual misclassification — that is owned by the
  -- classification rules and their own mutants — but it can refuse the case
  -- where nothing at all is observed.
  zeroFindings =
    [ finding
#if defined(VALIDATION_SOURCE_DEBT_STATE_ZERO_CODE_MUTANT)
        "SOURCE-DEBT-STATE-COLLAPSE-MUTANT"
#else
        "SOURCE-DEBT-STATE-COLLAPSE"
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_ZERO_SUBJECT_MUTANT)
        "source-debt-zero-mutant"
#else
        "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_ZERO_DETAIL_MUTANT)
        "mutant"
#else
        "every later-owned source-debt family is zero at once, which is a classifier collapse rather than a completed migration"
#endif
    | not (Set.null laterOwnedSourceDebtIds)
    , all
        (\identifier -> Map.lookup identifier states == Just SourceDebtStateZero)
        (Set.toAscList laterOwnedSourceDebtIds)
    ]

sourceDebtState :: SourceDebtId -> Map SourceDebtId SourceDebtObservation -> SourceDebtState
sourceDebtState SourcePb observed
  | sourceDebtPbIsZero observed = SourceDebtStateZero
  | otherwise =
      SourceDebtStateRefused
#if defined(VALIDATION_SOURCE_DEBT_STATE_PB_REFUSED_DETAIL_MUTANT)
        "bounded pb source debt mutant"
#else
        "bounded pb source debt is not zero"
#endif
sourceDebtState identifier observed =
  case
      ( sourceDebtBaseline
#if defined(VALIDATION_SOURCE_DEBT_STATE_BASELINE_ID_PROJECTION_MUTANT)
          (identifier `seq` SourcePb)
#else
          identifier
#endif
      , Map.lookup
#if defined(VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_ID_PROJECTION_MUTANT)
          (identifier `seq` SourcePb)
#else
          identifier
#endif
          observed
      )
    of
    (Nothing, _) ->
      SourceDebtStateRefused
        ("missing closed source-debt baseline for " <> renderSourceDebtId identifier)
    -- A family with a baseline and no observation is fully retired, which is
    -- the outcome the baseline exists to drive toward. It was refused, so the
    -- check required all eight debt families to remain permanently non-empty
    -- and reddened Phase 0 at the moment a migration succeeded. The mutant is
    -- inverted accordingly: refusing a retired family is now the defect.
    (Just _, Nothing) ->
#if defined(VALIDATION_SOURCE_DEBT_MISSING_OBSERVATION_ZERO_MUTANT)
      SourceDebtStateRefused
        ("missing acquired source-debt observation for " <> renderSourceDebtId identifier)
#else
      SourceDebtStateZero
#endif
    (Just expected, Just actual)
      | (
#if defined(VALIDATION_SOURCE_DEBT_STATE_COUNT_MATCH_COMPOSITION_MUTANT)
          sourceDebtCountMatches expected actual `seq` True
#else
          sourceDebtCountMatches expected actual
#endif
        ) ->
          SourceDebtStateOpen
#if defined(VALIDATION_SOURCE_DEBT_STATE_OPEN_COUNT_PROJECTION_MUTANT)
            (observationCount actual `seq` 0)
#else
            (observationCount actual)
#endif
#if defined(VALIDATION_SOURCE_DEBT_STATE_OPEN_FINGERPRINT_PROJECTION_MUTANT)
            (observationFingerprint actual `seq` "")
#else
            (observationFingerprint actual)
#endif
      | otherwise ->
          SourceDebtStateRefused
#if defined(VALIDATION_SOURCE_DEBT_STATE_MISMATCH_DETAIL_MUTANT)
            (identifier `seq` "source-debt baseline mismatch mutant")
#else
            ("source-debt baseline mismatch for " <> renderSourceDebtId identifier)
#endif

baselineCount :: SourceDebtBaseline -> Int
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_COUNT_PROJECTION_MUTANT)
baselineCount baseline@(SourceDebtBaseline value) = baseline `seq` value `seq` 0
#else
baselineCount (SourceDebtBaseline value) = value
#endif



observationCount :: SourceDebtObservation -> Int
#if defined(VALIDATION_SOURCE_DEBT_OBSERVATION_COUNT_PROJECTION_MUTANT)
observationCount observed@(SourceDebtObservation value _ _) = observed `seq` value `seq` 0
#else
observationCount (SourceDebtObservation value _ _) = value
#endif

observationFingerprint :: SourceDebtObservation -> Text
#if defined(VALIDATION_SOURCE_DEBT_OBSERVATION_FINGERPRINT_PROJECTION_MUTANT)
observationFingerprint observed@(SourceDebtObservation _ value _) = observed `seq` value `seq` ""
#else
observationFingerprint (SourceDebtObservation _ value _) = value
#endif

observationPathDigest :: SourceDebtObservation -> Text
#if defined(VALIDATION_SOURCE_DEBT_OBSERVATION_PATH_PROJECTION_MUTANT)
observationPathDigest observed@(SourceDebtObservation _ _ value) = observed `seq` value `seq` ""
#else
observationPathDigest (SourceDebtObservation _ _ value) = value
#endif

renderObserved :: (SourceDebtId, SourceDebtObservation) -> [Observation]
renderObserved (identifier, value) =
#if defined(VALIDATION_SOURCE_DEBT_RENDER_OBSERVATION_ORDER_MUTANT)
  reverse
#else
  id
#endif
    [ observation
#if defined(VALIDATION_SOURCE_DEBT_RENDER_COUNT_KEY_MUTANT)
        ("source-debt.count-mutant." <> renderSourceDebtId identifier)
#else
        ("source-debt.count." <> renderSourceDebtId identifier)
#endif
#if defined(VALIDATION_SOURCE_DEBT_RENDER_COUNT_VALUE_MUTANT)
        (renderInt (observationCount value) `seq` "0")
#else
        (renderInt (observationCount value))
#endif
    , observation
#if defined(VALIDATION_SOURCE_DEBT_RENDER_FINGERPRINT_KEY_MUTANT)
        ("source-debt.fingerprint-mutant." <> renderSourceDebtId identifier)
#else
        ("source-debt.fingerprint." <> renderSourceDebtId identifier)
#endif
#if defined(VALIDATION_SOURCE_DEBT_RENDER_FINGERPRINT_VALUE_MUTANT)
        (observationFingerprint value `seq` "")
#else
        (observationFingerprint value)
#endif
    , observation
#if defined(VALIDATION_SOURCE_DEBT_RENDER_PATH_KEY_MUTANT)
        ("source-debt.path-inventory-mutant." <> renderSourceDebtId identifier)
#else
        ("source-debt.path-inventory." <> renderSourceDebtId identifier)
#endif
#if defined(VALIDATION_SOURCE_DEBT_RENDER_PATH_VALUE_MUTANT)
        (observationPathDigest value `seq` "")
#else
        (observationPathDigest value)
#endif
  ]

problemFinding :: SourceDebtProblem -> Finding
problemFinding problem = case problem of
  SourceDebtBaselineFamilySetMismatch expected actual ->
    finding
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_CODE_MUTANT)
      "SOURCE-DEBT-BASELINE-FAMILY-SET-MISMATCH-MUTANT"
#else
      "SOURCE-DEBT-BASELINE-FAMILY-SET-MISMATCH"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_SUBJECT_MUTANT)
      "source-debt-baseline-mutant"
#else
      "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_DETAIL_MUTANT)
      (expected `seq` actual `seq` "mutant")
#else
      ("expected=" <> renderIds expected <> ", actual=" <> renderIds actual)
#endif
  SourceDebtFamilySetMismatch expected actual ->
    finding
#if defined(VALIDATION_SOURCE_DEBT_FAMILY_FINDING_CODE_MUTANT)
      "SOURCE-DEBT-FAMILY-SET-MISMATCH-MUTANT"
#else
      "SOURCE-DEBT-FAMILY-SET-MISMATCH"
#endif
#if defined(VALIDATION_SOURCE_DEBT_FAMILY_FINDING_SUBJECT_MUTANT)
      "source-debt-baseline-mutant"
#else
      "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_FAMILY_FINDING_DETAIL_MUTANT)
      (expected `seq` actual `seq` "mutant")
#else
      ("expected=" <> renderIds expected <> ", actual=" <> renderIds actual)
#endif
  SourcePbObservationPresent actual ->
    finding
#if defined(VALIDATION_SOURCE_DEBT_PB_FINDING_CODE_MUTANT)
      "SOURCE-DEBT-PB-NOT-ZERO-MUTANT"
#else
      "SOURCE-DEBT-PB-NOT-ZERO"
#endif
#if defined(VALIDATION_SOURCE_DEBT_PB_FINDING_SUBJECT_MUTANT)
      "source-debt-pb-mutant"
#else
      (Text.unpack (renderSourceDebtId SourcePb))
#endif
#if defined(VALIDATION_SOURCE_DEBT_PB_FINDING_DETAIL_MUTANT)
      (actual `seq` "mutant")
#else
      ( "expected absent/zero, actual count="
          <> renderInt (observationCount actual)
          <> ", fingerprint="
          <> observationFingerprint actual
      )
#endif
  SourceDebtPathCountMismatch identifier expected actual ->
    finding
#if defined(VALIDATION_SOURCE_DEBT_COUNT_FINDING_CODE_MUTANT)
      "SOURCE-DEBT-COUNT-MISMATCH-MUTANT"
#else
      "SOURCE-DEBT-COUNT-MISMATCH"
#endif
#if defined(VALIDATION_SOURCE_DEBT_COUNT_FINDING_SUBJECT_MUTANT)
      (identifier `seq` "source-debt-count-mutant")
#else
      (Text.unpack (renderSourceDebtId identifier))
#endif
#if defined(VALIDATION_SOURCE_DEBT_COUNT_FINDING_DETAIL_MUTANT)
      (expected `seq` actual `seq` "mutant")
#else
      ("expected=" <> renderInt expected <> ", actual=" <> renderInt actual)
#endif
resourceLimitAnalysis :: SourceDebtResourceFailure -> SourceDebtAnalysis
resourceLimitAnalysis resourceFailure =
  case resourceFailure of
    SourceDebtPathUtf8LimitExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_PATH_RESOURCE_ROUTING_MUTANT)
      observedAtLeast `seq` resourceBoundedAnalysis "path-utf8-mutant" "SOURCE-DEBT-PATH-UTF8-LIMIT" maximumSourceDebtPathUtf8Bytes observedAtLeast
#else
      resourceBoundedAnalysis
        "path-utf8"
        "SOURCE-DEBT-PATH-UTF8-LIMIT"
        maximumSourceDebtPathUtf8Bytes
        observedAtLeast
#endif
    SourceDebtObjectIdLimitExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_OBJECT_ID_RESOURCE_ROUTING_MUTANT)
      observedAtLeast `seq` resourceBoundedAnalysis "object-id-mutant" "SOURCE-DEBT-OBJECT-ID-LIMIT" maximumSourceDebtObjectIdUtf8Bytes observedAtLeast
#else
      resourceBoundedAnalysis
        "object-id"
        "SOURCE-DEBT-OBJECT-ID-LIMIT"
        maximumSourceDebtObjectIdUtf8Bytes
        observedAtLeast
#endif
    SourceDebtBlobLimitExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_BLOB_RESOURCE_ROUTING_MUTANT)
      observedAtLeast `seq` resourceBoundedAnalysis "blob-mutant" "SOURCE-DEBT-BLOB-LIMIT" maximumSourceDebtBlobBytes observedAtLeast
#else
      resourceBoundedAnalysis
        "blob"
        "SOURCE-DEBT-BLOB-LIMIT"
        maximumSourceDebtBlobBytes
        observedAtLeast
#endif
    SourceDebtAggregateBlobLimitExceeded observedAtLeast ->
#if defined(VALIDATION_SOURCE_DEBT_AGGREGATE_RESOURCE_ROUTING_MUTANT)
      observedAtLeast `seq` resourceBoundedAnalysis "aggregate-blob-mutant" "SOURCE-DEBT-AGGREGATE-BLOB-LIMIT" maximumSourceDebtAggregateBlobBytes observedAtLeast
#else
      resourceBoundedAnalysis
        "aggregate-blob"
        "SOURCE-DEBT-AGGREGATE-BLOB-LIMIT"
        maximumSourceDebtAggregateBlobBytes
        observedAtLeast
#endif

resourceBoundedAnalysis :: Text -> Text -> Integer -> Integer -> SourceDebtAnalysis
resourceBoundedAnalysis dimension code maximumBytes observedAtLeast =
  SourceDebtAnalysis
    CheckResult
      { checkName =
#if defined(VALIDATION_SOURCE_DEBT_RESOURCE_RESULT_NAME_MUTANT)
          "source-debt-baseline-mutant"
#else
          "source-debt-baseline"
#endif
      , checkObservations =
#if defined(VALIDATION_SOURCE_DEBT_RESOURCE_RESULT_OBSERVATIONS_MUTANT)
          limitObservations dimension maximumBytes observedAtLeast `seq` []
#else
          limitObservations dimension maximumBytes observedAtLeast
#endif
      , checkFindings =
#if defined(VALIDATION_SOURCE_DEBT_RESOURCE_RESULT_FINDINGS_MUTANT)
          limitFinding code maximumBytes observedAtLeast `seq` []
#else
          [limitFinding code maximumBytes observedAtLeast]
#endif
      }
    ( refusedStates
        ( dimension
            <> " limit exceeded: maximum="
            <> renderInteger maximumBytes
            <> ", observed-at-least="
            <> renderInteger observedAtLeast
        )
    )

limitAnalysis :: Text -> Text -> Int -> Int -> SourceDebtAnalysis
limitAnalysis dimension code maximumValue observedAtLeast =
  SourceDebtAnalysis
    CheckResult
      { checkName =
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_RESULT_NAME_MUTANT)
          "source-debt-baseline-mutant"
#else
          "source-debt-baseline"
#endif
      , checkObservations =
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_RESULT_OBSERVATIONS_MUTANT)
          limitObservations dimension maximumValue observedAtLeast `seq` []
#else
          limitObservations dimension maximumValue observedAtLeast
#endif
      , checkFindings =
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_RESULT_FINDINGS_MUTANT)
          limitFinding code maximumValue observedAtLeast `seq` []
#else
          [limitFinding code maximumValue observedAtLeast]
#endif
      }
    ( refusedStates
        ( dimension
            <> " limit exceeded: maximum="
            <> renderInt maximumValue
            <> ", observed-at-least="
            <> renderInt observedAtLeast
        )
    )

limitObservations :: Show number => Text -> number -> number -> [Observation]
limitObservations dimension maximumValue observedAtLeast =
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_OBSERVATION_ORDER_MUTANT)
  reverse
#else
  id
#endif
    [ observation
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_MAXIMUM_KEY_MUTANT)
        ("source-debt." <> dimension <> "-limit.maximum-mutant")
#else
        ("source-debt." <> dimension <> "-limit.maximum")
#endif
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_MAXIMUM_VALUE_MUTANT)
        (renderNumber maximumValue `seq` "0")
#else
        (renderNumber maximumValue)
#endif
    , observation
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_OBSERVED_KEY_MUTANT)
        ("source-debt." <> dimension <> "-limit.observed-at-least-mutant")
#else
        ("source-debt." <> dimension <> "-limit.observed-at-least")
#endif
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_OBSERVED_VALUE_MUTANT)
        (renderNumber observedAtLeast `seq` "0")
#else
        (renderNumber observedAtLeast)
#endif
  ]

limitFinding :: Show number => Text -> number -> number -> Finding
limitFinding code maximumValue observedAtLeast =
  finding
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_FINDING_CODE_MUTANT)
    (code <> "-MUTANT")
#else
    code
#endif
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_FINDING_SUBJECT_MUTANT)
    "source-debt-baseline-mutant"
#else
    "source-debt-baseline"
#endif
#if defined(VALIDATION_SOURCE_DEBT_LIMIT_FINDING_DETAIL_MUTANT)
    (renderNumber maximumValue `seq` renderNumber observedAtLeast `seq` "mutant")
#else
    ( "maximum="
        <> renderNumber maximumValue
        <> ", observed-at-least="
        <> renderNumber observedAtLeast
    )
#endif

refusedStates :: Text -> Map SourceDebtId SourceDebtState
refusedStates detail =
  Map.fromList
    [ (
#if defined(VALIDATION_SOURCE_DEBT_REFUSED_STATE_ID_PROJECTION_MUTANT)
        identifier `seq` SourcePb
#else
        identifier
#endif
      , SourceDebtStateRefused
#if defined(VALIDATION_SOURCE_DEBT_REFUSED_STATE_DETAIL_PROJECTION_MUTANT)
          (detail `seq` "mutant")
#else
          detail
#endif
      )
    | identifier <- allSourceDebtIds
    ]

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix maximumValue values =
  let prefix =
#if defined(VALIDATION_SOURCE_DEBT_BOUNDED_PREFIX_LENGTH_MUTANT)
        take maximumValue values
#else
        take (maximumValue + 1) values
#endif
   in if
#if defined(VALIDATION_SOURCE_DEBT_BOUNDED_PREFIX_PREDICATE_MUTANT)
          length prefix >= maximumValue
#else
          length prefix > maximumValue
#endif
        then
          PrefixExceeded (maximumValue + 1)
        else
          PrefixWithin prefix

renderIds :: Set SourceDebtId -> Text
renderIds = Text.intercalate "," . map renderSourceDebtId . Set.toAscList

renderInt :: Int -> Text
renderInt = Text.pack . show

renderInteger :: Integer -> Text
renderInteger = Text.pack . show

renderNumber :: Show number => number -> Text
renderNumber = Text.pack . show

#if defined(VALIDATION_SOURCE_DEBT_INTERNAL_TEST_HOOKS)
-- These direct-source hooks exist only in the focused package-hidden oracle
-- build. They exercise private eliminators and serializers without exporting
-- a constructor or proof value from the packaged library.
sourceDebtInternalTestProblemFindings :: [Finding]
sourceDebtInternalTestProblemFindings =
  map
    problemFinding
    [ SourceDebtBaselineFamilySetMismatch (Set.singleton SourceTools) (Set.singleton SourceDhall)
    , SourceDebtFamilySetMismatch (Set.singleton SourceProto) (Set.singleton SourceUi)
    , SourcePbObservationPresent (SourceDebtObservation 1 "pb-fingerprint" "pb-path")
    , SourceDebtPathCountMismatch SourcePulumi 2 3
    ]

sourceDebtInternalTestIntegrityFindings :: [Finding]
sourceDebtInternalTestIntegrityFindings =
  stateIntegrityFindings
    ( Map.delete SourceVendor
        ( Map.fromList
            [ (identifier, if identifier == SourceTools then SourceDebtStateZero else SourceDebtStateRefused "closed")
            | identifier <- allSourceDebtIds
            ]
        )
    )

sourceDebtInternalTestStateResults :: [Text]
sourceDebtInternalTestStateResults =
  [ renderFoldState (SourceDebtStateOpen 3 "open-fingerprint")
  , renderFoldState SourceDebtStateZero
  , renderFoldState (SourceDebtStateRefused "refused-detail")
  , renderStateForTest (sourceDebtState SourcePb Map.empty)
  , renderStateForTest
      ( sourceDebtState
          SourcePb
          (Map.singleton SourcePb (SourceDebtObservation 1 "pb-fingerprint" "pb-path"))
      )
  , renderStateForTest (sourceDebtState SourceTools Map.empty)
  , renderStateForTest (sourceDebtState SourceTools atCeilingToolsObservation)
  , renderStateForTest (sourceDebtState SourceTools beneathCeilingToolsObservation)
  , renderStateForTest (sourceDebtState SourceTools aboveCeilingToolsObservation)
  , renderBoundedStateForTest
      SourcePb
      (boundedSourceDebtStates (PrefixExceeded 27) (PrefixWithin []) Map.empty)
  , renderBoundedStateForTest
      SourcePb
      (boundedSourceDebtStates (PrefixWithin []) (PrefixExceeded 25) Map.empty)
  ]
 where
  -- The three ratchet outcomes: at the ceiling is admitted, beneath it is
  -- admitted because retiring debt must not refuse, and above it refuses.
  toolsObservationOf adjust = case sourceDebtBaseline SourceTools of
    Nothing -> Map.empty
    Just baseline ->
      Map.singleton
        SourceTools
        ( SourceDebtObservation
            (adjust (baselineCount baseline))
            "observed-fingerprint"
            "observed-path"
        )
  atCeilingToolsObservation = toolsObservationOf id
  beneathCeilingToolsObservation = toolsObservationOf (subtract 1)
  aboveCeilingToolsObservation = toolsObservationOf (+ 1)

renderFoldState :: SourceDebtState -> Text
renderFoldState state =
  foldSourceDebtState
    state
    ("refused:" <>)
    "zero"
    (\count fingerprint -> "open:" <> renderInt count <> ":" <> fingerprint)

renderStateForTest :: SourceDebtState -> Text
renderStateForTest state = case state of
  SourceDebtStateOpen count fingerprint -> "open:" <> renderInt count <> ":" <> fingerprint
  SourceDebtStateZero -> "zero"
  SourceDebtStateRefused detail -> "refused:" <> detail

renderBoundedStateForTest :: SourceDebtId -> Map SourceDebtId SourceDebtState -> Text
renderBoundedStateForTest identifier states =
  case Map.lookup identifier states of
    Nothing -> "missing:" <> renderSourceDebtId identifier
    Just state -> renderStateForTest state
#endif

_zeroDigest :: Text
_zeroDigest = Text.replicate 64 "0"

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex byte =
    [ intToDigit
#if defined(VALIDATION_SOURCE_DEBT_HEX_HIGH_NIBBLE_MUTANT)
        (((fromIntegral byte :: Int) `div` 16) `seq` 0)
#else
        (fromIntegral byte `div` 16)
#endif
    , intToDigit
#if defined(VALIDATION_SOURCE_DEBT_HEX_LOW_NIBBLE_MUTANT)
        (((fromIntegral byte :: Int) `mod` 16) `seq` 0)
#else
        (fromIntegral byte `mod` 16)
#endif
    ]
