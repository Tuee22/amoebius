{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , ClassifiedPath (..)
  , GitExecutable
  , GitObjectFormat (..)
  , IndexEntry (..)
  , IndexFlagObservation (..)
  , IndexMode (..)
  , SnapshotProblem (..)
  , SourceClass (..)
  , SourceClosure
  , SourceDebtId (..)
  , SourceFacet (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , WorktreeEntryKind (..)
  , acquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_CLOSURE_INTERNAL_TEST_ACQUIRE)
  , sourceClosureInternalTestAcquire
#endif
  , classifyEntry
  , classifySnapshot
  , checkGitReportedWorkspaceDiagnostic
  , combineRawExecutableBitsDiagnostic
  , computeBlobObjectId
  , computeSourceSnapshotIdentity
  , closurePaths
  , closurePbBootstrapDiagnostic
  , closureProblems
  , closureRegisteredDebt
  , closureSnapshotIdentity
  , finalIndexBoundaryProblemsDiagnostic
  , inventoryAuthoredPaths
  , loadGitSnapshot
  , loadGitSnapshotDiagnostic
  , mkGitExecutable
  , objectFormatBoundaryProblems
  , parseLsFilesStage
  , parseLsFilesTaggedStage
  , parseLsFilesTaggedPaths
  , pbTrackedFilesFromSnapshot
  , registeredSourceIds
  , repositoryHeadBoundaryProblemsDiagnostic
  , renderSnapshotProblem
  , renderSourceDebtId
  , sourceDebtFingerprint
  , sourceDebtPathCount
  , sourceClosureCheck
  , sourceClosureCheckAcquired
  , verifyBlobObjectId
  , rawSourceClosureDiagnostic
  ) where

import Amoebius.Validation.PbBootstrapGrammar qualified as Pb
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceSnapshot.Internal
  ( GitObjectFormat (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation
  , finding
  , observation
  )
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception (IOException, displayException, finally, try)
#if !defined(mingw32_HOST_OS)
import Control.Exception (bracket, onException)
#endif
import Control.Monad (forM)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as ByteString8
import qualified Crypto.Hash.SHA256 as SHA256
import Data.Char (intToDigit, ord)
import Data.List (group, sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Encoding.Error as TextError
import Data.Word (Word8)
import System.Exit (ExitCode (..))
import System.FilePath
  ( dropTrailingPathSeparator
  , isAbsolute
  , normalise
  , (</>)
  )
import System.IO (Handle, hClose)
#if !defined(mingw32_HOST_OS)
import System.IO.Error (isDoesNotExistError, tryIOError)
import System.Posix.Directory qualified as PosixDirectory
import System.Posix.Directory.Fd qualified as PosixDirectoryFd
import System.Posix.Directory.Internals qualified as PosixDirectoryInternals
import System.Posix.Files qualified as Posix
import System.Posix.IO qualified as PosixIO
import System.Posix.IO.ByteString qualified as PosixIOBytes
import System.Posix.Types (Fd)
#endif
import System.Process
  ( CreateProcess (..)
  , StdStream (CreatePipe)
  , createProcess
  , proc
  , waitForProcess
  )

-- Public raw-diagnostic bounds.  These literals are deliberately restated in
-- the independent oracle.  No semantic classification, hashing, sorting,
-- splitting, map construction, or blob decoding may precede its applicable
-- preflight.
maximumRawSnapshotIdentityBytes, maximumRawEntries, maximumRawPathBytes :: Int
maximumRawSnapshotIdentityBytes = 64
maximumRawEntries = 16384
maximumRawPathBytes = 1024

maximumRawPathDepth, maximumRawPathSegmentBytes, maximumRawModeBytes :: Int
maximumRawPathDepth = 64
maximumRawPathSegmentBytes = 255
maximumRawModeBytes = 6

maximumRawObjectIdentityBytes, maximumRawBlobBytes, maximumRawAggregateBlobBytes :: Int
maximumRawObjectIdentityBytes = 64
maximumRawBlobBytes = 16777216
maximumRawAggregateBlobBytes = 33554432

maximumRawSemanticLineBytes, maximumRawProblems, maximumRawResultFindings :: Int
maximumRawSemanticLineBytes = 4096
maximumRawProblems = 128
maximumRawResultFindings = 196

-- Fixed bounds for local Git output and authored-tree traversal.
maximumInternalGitStdoutBytes, maximumInternalGitStderrBytes :: Int
maximumInternalGitStdoutBytes = 67108864
maximumInternalGitStderrBytes = 1048576

maximumInternalAuthoredEntries, maximumInternalAuthoredDepth, maximumInternalAuthoredPathBytes :: Int
maximumInternalAuthoredEntries = 16384
maximumInternalAuthoredDepth = 64
maximumInternalAuthoredPathBytes = 1024

internalGitCaptureEnvelopeProblem :: SnapshotProblem
internalGitCaptureEnvelopeProblem =
  InternalGitCaptureEnvelopeUnavailable
    maximumInternalGitStdoutBytes
    maximumInternalGitStderrBytes

internalAuthoredTraversalEnvelopeProblem :: SnapshotProblem
internalAuthoredTraversalEnvelopeProblem =
  InternalAuthoredTraversalEnvelopeUnavailable
    maximumInternalAuthoredEntries
    maximumInternalAuthoredDepth
    maximumInternalAuthoredPathBytes

data BoundedPrefix value
  = PrefixWithin [value]
  | PrefixExceeded Int

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> PrefixWithin (reverse reversed)
    value : rest
      | count == limit -> PrefixExceeded (limit + 1)
      | otherwise -> go (count + 1) (value : reversed) rest

data RawSourceEntry = RawSourceEntry FilePath Text Text ByteString

rawEntryPath :: RawSourceEntry -> FilePath
rawEntryPath (RawSourceEntry path _ _ _) = path

rawEntryMode :: RawSourceEntry -> Text
rawEntryMode (RawSourceEntry _ mode _ _) = mode

rawEntryObjectIdentity :: RawSourceEntry -> Text
rawEntryObjectIdentity (RawSourceEntry _ _ objectIdentity _) = objectIdentity

rawEntryBytes :: RawSourceEntry -> ByteString
rawEntryBytes (RawSourceEntry _ _ _ bytes) = bytes

data RawSourceProblem
  = RawSnapshotIdentityByteLimitExceeded Int Int
  | RawEntryLimitExceeded Int Int
  | RawPathByteLimitExceeded Int Int Int
  | RawPathDepthLimitExceeded Int Int Int
  | RawPathSegmentByteLimitExceeded Int Int Int
  | RawModeByteLimitExceeded Int Int Int
  | RawObjectIdentityByteLimitExceeded Int Int Int
  | RawBlobByteLimitExceeded Int Int Int
  | RawAggregateBlobByteLimitExceeded Int Int
  | RawSemanticLineByteLimitExceeded Int Int Int
  | RawSnapshotIdentityMalformed Text
  | RawSnapshotIdentityMismatch Text Text
  | RawEmptyInventory
  | RawPathMalformed Int FilePath Text
  | RawModeMalformed Int Text
  | RawObjectIdentityMalformed Int Text
  | RawObjectIdentityMismatch Int Text Text
  | RawMixedObjectIdentityFormats [Int]
  | RawDuplicatePath FilePath
  | RawEntryOrderInvalid [FilePath]
  | RawPortableCaseCollision FilePath FilePath
  | RawPortablePrefixConflict FilePath FilePath
  | RawProblemLimitExceeded Int Int
  deriving (Eq, Show)

data RawSourceAnalysis = RawSourceAnalysis
  { rawAnalysisInputCommitment :: RawInputCommitment
  , rawAnalysisEntryCount :: Text
  , rawAnalysisAggregateBytes :: Text
  , rawAnalysisComputedSnapshot :: Text
  , rawAnalysisClassificationDigest :: Text
  , rawAnalysisClassCounts :: [Text]
  , rawAnalysisClosure :: Maybe SourceClosure
  , rawAnalysisProblems :: [RawSourceProblem]
  , rawAnalysisProblemCount :: Text
  }

-- | The complete-input commitment is defined only after every allocation and
-- traversal preflight has succeeded.  A rejected value instead receives a
-- separately domain-separated commitment to the bounded preflight state.  The
-- latter deliberately does not claim to identify bytes which the diagnostic
-- refused to traverse.
data RawInputCommitment = RawInputCommitment
  { rawInputCommitmentKind :: Text
  , rawInputCommitmentSha256 :: Text
  }

-- | Package-hidden implementation of the facade's sole raw diagnostic.
-- Caller input can never construct 'AcquiredSourceSnapshot' and every result
-- retains three independently selected authority/discovery refusals.
rawSourceClosureDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
rawSourceClosureDiagnostic claimedIdentity tuples =
  CheckResult
    { checkName = rawSourceClosureCheckName
    , checkObservations =
        rawSourceObservationOrder
          [ item
          | Just item <-
              [ rawSourceObservation 1 "source-closure.input-commitment.kind" inputCommitmentKind
              , rawSourceObservation 2 "source-closure.input-commitment.sha256" inputCommitmentDigest
              , rawSourceObservation 3 "source-closure.input.claimed-snapshot" (rawSafeClaimedIdentity claimedIdentity)
              , rawSourceObservation 4 "source-closure.input.entry-count" (rawAnalysisEntryCount analysis)
              , rawSourceObservation 5 "source-closure.input.aggregate-blob-bytes" (rawAnalysisAggregateBytes analysis)
              , rawSourceObservation 6 "source-closure.derived.snapshot" (rawAnalysisComputedSnapshot analysis)
              , rawSourceObservation 7 "source-closure.derived.classification-sha256" (rawAnalysisClassificationDigest analysis)
              , rawSourceObservation 8 "source-closure.derived.haskell-count" (classCount 0)
              , rawSourceObservation 9 "source-closure.derived.documentation-count" (classCount 1)
              , rawSourceObservation 10 "source-closure.derived.project-count" (classCount 2)
              , rawSourceObservation 11 "source-closure.derived.pb-debt-count" (classCount 3)
              , rawSourceObservation 12 "source-closure.derived.legacy-count" (classCount 4)
              , rawSourceObservation 13 "source-closure.derived.unregistered-count" (classCount 5)
              , rawSourceObservation 14 "source-closure.preflight.problem-count" (rawAnalysisProblemCount analysis)
              , rawSourceObservation 15 "source-closure.diagnostic-status" "refused"
              ]
          ]
    , checkFindings = rawSourceFindingOrder boundedFindings
    }
 where
  rawEntries =
    [ RawSourceEntry
        (rawTuplePath path)
        (rawTupleMode mode)
        (rawTupleObject objectIdentity)
        (rawTupleBytes bytes)
    | (path, mode, objectIdentity, bytes) <- tuples
    ]
  analysis = analyzeRawSourceInventory claimedIdentity rawEntries
  inputCommitment = rawAnalysisInputCommitment analysis
  inputCommitmentKind = rawInputCommitmentKind inputCommitment
  inputCommitmentDigest = rawInputCommitmentSha256 inputCommitment
  classCount index = case drop index (rawAnalysisClassCounts analysis) of
    value : _ -> value
    [] -> "unavailable"
  localFindings = map (rawSourceProblemFinding inputCommitment) (rawAnalysisProblems analysis)
  closureFindings = case rawAnalysisClosure analysis of
    Nothing -> []
    Just closure -> rawClosureFindings inputCommitment closure
  dynamicFindings = localFindings <> closureFindings
  candidateFindings = mandatoryRawSourceFindings inputCommitment <> dynamicFindings
  boundedFindings = case boundedPrefix maximumRawResultFindings candidateFindings of
    PrefixWithin values -> values
    PrefixExceeded observed
      | rawResultFindingLimitExceeded observed ->
          mandatoryRawSourceFindings inputCommitment
            <> [ rawMappedFinding
                  27
                  "SOURCE-CLOSURE-RESULT-FINDING-LIMIT"
                  "<raw-source-closure>"
                  (rawLimitDetail maximumRawResultFindings observed <> rawCommitmentDetail inputCommitment)
               ]
    PrefixExceeded _ -> take maximumRawResultFindings candidateFindings

rawSourceObservation :: Int -> Text -> Text -> Maybe Observation
rawSourceObservation ordinal key value
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_KIND_OBSERVATION_DROP_MUTANT)
  | ordinal == 1 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_KIND_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 1 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_KIND_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 1 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_SHA256_OBSERVATION_DROP_MUTANT)
  | ordinal == 2 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_SHA256_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 2 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_COMMITMENT_SHA256_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 2 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_CLAIMED_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  | ordinal == 3 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_CLAIMED_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 3 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_CLAIMED_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 3 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_ENTRY_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 4 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_ENTRY_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 4 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_ENTRY_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 4 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_AGGREGATE_BLOB_BYTES_OBSERVATION_DROP_MUTANT)
  | ordinal == 5 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_AGGREGATE_BLOB_BYTES_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 5 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_INPUT_AGGREGATE_BLOB_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 5 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  | ordinal == 6 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 6 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 6 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_CLASSIFICATION_SHA256_OBSERVATION_DROP_MUTANT)
  | ordinal == 7 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_CLASSIFICATION_SHA256_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 7 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_CLASSIFICATION_SHA256_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 7 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_HASKELL_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 8 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_HASKELL_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 8 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_HASKELL_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 8 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_DOCUMENTATION_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 9 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_DOCUMENTATION_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 9 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_DOCUMENTATION_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 9 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PROJECT_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 10 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PROJECT_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 10 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PROJECT_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 10 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PB_DEBT_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 11 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PB_DEBT_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 11 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_PB_DEBT_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 11 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_LEGACY_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 12 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_LEGACY_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 12 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_LEGACY_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 12 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_UNREGISTERED_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 13 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_UNREGISTERED_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 13 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DERIVED_UNREGISTERED_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 13 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_PREFLIGHT_PROBLEM_COUNT_OBSERVATION_DROP_MUTANT)
  | ordinal == 14 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_PREFLIGHT_PROBLEM_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 14 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_PREFLIGHT_PROBLEM_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 14 = Just (observation key (value <> "-mutant"))
#elif defined(VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_STATUS_OBSERVATION_DROP_MUTANT)
  | ordinal == 15 = Nothing
#elif defined(VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_STATUS_OBSERVATION_KEY_MAPPING_MUTANT)
  | ordinal == 15 = Just (observation (key <> ".mutant") value)
#elif defined(VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT)
  | ordinal == 15 = Just (observation key (value <> "-mutant"))
#endif
  | otherwise = ordinal `seq` Just (observation key value)


rawMappedFinding :: Int -> Text -> FilePath -> Text -> Finding
rawMappedFinding locus code subject detail =
  finding
    (rawMappedFindingCode locus code)
    (rawMappedFindingSubject locus subject)
    (rawMappedFindingDetail locus detail)

rawMappedFindingCode :: Int -> Text -> Text
rawMappedFindingCode locus value
#if defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 1 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 2 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 3 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_DEPTH_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 4 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_SEGMENT_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 5 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 6 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 7 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_BLOB_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 8 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_AGGREGATE_BLOB_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 9 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_SEMANTIC_LINE_BYTE_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 10 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_GRAMMAR_CODE_MAPPING_MUTANT)
  | locus == 11 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
  | locus == 12 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_INVENTORY_EMPTY_CODE_MAPPING_MUTANT)
  | locus == 13 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_GRAMMAR_CODE_MAPPING_MUTANT)
  | locus == 14 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_GRAMMAR_CODE_MAPPING_MUTANT)
  | locus == 15 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_GRAMMAR_CODE_MAPPING_MUTANT)
  | locus == 16 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_MISMATCH_CODE_MAPPING_MUTANT)
  | locus == 17 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_FORMAT_MIXED_CODE_MAPPING_MUTANT)
  | locus == 18 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_DUPLICATE_PATH_CODE_MAPPING_MUTANT)
  | locus == 19 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_ORDER_CODE_MAPPING_MUTANT)
  | locus == 20 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_CASE_COLLISION_CODE_MAPPING_MUTANT)
  | locus == 21 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_PREFIX_CONFLICT_CODE_MAPPING_MUTANT)
  | locus == 22 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PROBLEM_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 23 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DIAGNOSTIC_CODE_MAPPING_MUTANT)
  | locus == 24 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_LOCAL_CAPTURE_CODE_MAPPING_MUTANT)
  | locus == 25 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DISCOVERY_CODE_MAPPING_MUTANT)
  | locus == 26 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_RESULT_FINDING_LIMIT_CODE_MAPPING_MUTANT)
  | locus == 27 = value <> "-MUTANT"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_UNREGISTERED_CODE_MAPPING_MUTANT)
  | locus == 28 = value <> "-MUTANT"
#endif
  | otherwise = locus `seq` value

rawMappedFindingSubject :: Int -> FilePath -> FilePath
rawMappedFindingSubject locus value
#if defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_DEPTH_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 4 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_SEGMENT_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 5 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 6 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 7 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_BLOB_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 8 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_AGGREGATE_BLOB_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 9 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_SEMANTIC_LINE_BYTE_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 10 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_GRAMMAR_SUBJECT_MAPPING_MUTANT)
  | locus == 11 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
  | locus == 12 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_INVENTORY_EMPTY_SUBJECT_MAPPING_MUTANT)
  | locus == 13 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_GRAMMAR_SUBJECT_MAPPING_MUTANT)
  | locus == 14 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_GRAMMAR_SUBJECT_MAPPING_MUTANT)
  | locus == 15 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_GRAMMAR_SUBJECT_MAPPING_MUTANT)
  | locus == 16 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_MISMATCH_SUBJECT_MAPPING_MUTANT)
  | locus == 17 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_FORMAT_MIXED_SUBJECT_MAPPING_MUTANT)
  | locus == 18 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_DUPLICATE_PATH_SUBJECT_MAPPING_MUTANT)
  | locus == 19 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_ORDER_SUBJECT_MAPPING_MUTANT)
  | locus == 20 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_CASE_COLLISION_SUBJECT_MAPPING_MUTANT)
  | locus == 21 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_PREFIX_CONFLICT_SUBJECT_MAPPING_MUTANT)
  | locus == 22 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PROBLEM_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 23 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DIAGNOSTIC_SUBJECT_MAPPING_MUTANT)
  | locus == 24 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_LOCAL_CAPTURE_SUBJECT_MAPPING_MUTANT)
  | locus == 25 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DISCOVERY_SUBJECT_MAPPING_MUTANT)
  | locus == 26 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_RESULT_FINDING_LIMIT_SUBJECT_MAPPING_MUTANT)
  | locus == 27 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_UNREGISTERED_SUBJECT_MAPPING_MUTANT)
  | locus == 28 = value <> "-mutant"
#endif
  | otherwise = locus `seq` value

rawMappedFindingDetail :: Int -> Text -> Text
rawMappedFindingDetail locus value
#if defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 1 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 2 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 3 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_DEPTH_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 4 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_SEGMENT_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 5 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 6 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 7 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_BLOB_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 8 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_AGGREGATE_BLOB_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 9 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_SEMANTIC_LINE_BYTE_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 10 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_GRAMMAR_DETAIL_MAPPING_MUTANT)
  | locus == 11 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
  | locus == 12 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_INVENTORY_EMPTY_DETAIL_MAPPING_MUTANT)
  | locus == 13 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PATH_GRAMMAR_DETAIL_MAPPING_MUTANT)
  | locus == 14 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MODE_GRAMMAR_DETAIL_MAPPING_MUTANT)
  | locus == 15 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_GRAMMAR_DETAIL_MAPPING_MUTANT)
  | locus == 16 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_ID_MISMATCH_DETAIL_MAPPING_MUTANT)
  | locus == 17 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_OBJECT_FORMAT_MIXED_DETAIL_MAPPING_MUTANT)
  | locus == 18 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_DUPLICATE_PATH_DETAIL_MAPPING_MUTANT)
  | locus == 19 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_ENTRY_ORDER_DETAIL_MAPPING_MUTANT)
  | locus == 20 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_CASE_COLLISION_DETAIL_MAPPING_MUTANT)
  | locus == 21 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PORTABLE_PREFIX_CONFLICT_DETAIL_MAPPING_MUTANT)
  | locus == 22 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_PROBLEM_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 23 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DIAGNOSTIC_DETAIL_MAPPING_MUTANT)
  | locus == 24 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_LOCAL_CAPTURE_DETAIL_MAPPING_MUTANT)
  | locus == 25 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_MANDATORY_DISCOVERY_DETAIL_MAPPING_MUTANT)
  | locus == 26 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_RESULT_FINDING_LIMIT_DETAIL_MAPPING_MUTANT)
  | locus == 27 = value <> "; mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_FINDING_UNREGISTERED_DETAIL_MAPPING_MUTANT)
  | locus == 28 = value <> "; mutant"
#endif
  | otherwise = locus `seq` value

rawSourceClosureCheckName :: Text
#if defined(VALIDATION_SOURCE_CLOSURE_RESULT_CHECK_NAME_MUTANT)
rawSourceClosureCheckName = "source-closure-diagnostic-mutant"
#else
rawSourceClosureCheckName = "source-closure-diagnostic"
#endif

rawSourceObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CLOSURE_RESULT_OBSERVATION_ORDER_MUTANT)
rawSourceObservationOrder = reverse
#else
rawSourceObservationOrder = id
#endif

rawSourceFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CLOSURE_RESULT_FINDING_ORDER_MUTANT)
rawSourceFindingOrder = reverse
#else
rawSourceFindingOrder = id
#endif

rawTuplePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CLOSURE_TUPLE_PATH_ROUTE_MUTANT)
rawTuplePath _ = "src/Mutant.hs"
#else
rawTuplePath = id
#endif

rawTupleMode, rawTupleObject :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_TUPLE_MODE_ROUTE_MUTANT)
rawTupleMode _ = "100755"
#else
rawTupleMode = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_TUPLE_OBJECT_ROUTE_MUTANT)
rawTupleObject = Text.map (const '0')
#else
rawTupleObject = id
#endif

rawTupleBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_CLOSURE_TUPLE_BYTES_ROUTE_MUTANT)
rawTupleBytes = ByteString.drop 1
#else
rawTupleBytes = id
#endif

mandatoryRawSourceFindings :: RawInputCommitment -> [Finding]
mandatoryRawSourceFindings inputCommitment =
  diagnosticOnly <> localCaptureUnavailable <> completeDiscoveryUnavailable
 where
  diagnosticOnly =
#if defined(VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_BYPASS_MUTANT)
    []
#else
    [ rawMappedFinding
        24
        "SOURCE-CLOSURE-DIAGNOSTIC-ONLY"
        "<raw-source-closure>"
        ("caller-supplied source inventory is diagnostic input and cannot mint source-closure evidence" <> rawCommitmentDetail inputCommitment)
    ]
#endif
  localCaptureUnavailable =
#if defined(VALIDATION_SOURCE_CLOSURE_LOCAL_CAPTURE_BYPASS_MUTANT)
    []
#else
    [ rawMappedFinding
        25
        "SOURCE-CLOSURE-LOCAL-CAPTURE-UNAVAILABLE"
        "<raw-source-closure>"
        ("no package-hidden local source capture is attached" <> rawCommitmentDetail inputCommitment)
    ]
#endif
  completeDiscoveryUnavailable =
#if defined(VALIDATION_SOURCE_CLOSURE_DISCOVERY_BYPASS_MUTANT)
    []
#else
    [ rawMappedFinding
        26
        "SOURCE-CLOSURE-ATOMIC-COMPLETE-DISCOVERY-UNAVAILABLE"
        "<raw-source-closure>"
        ("caller tuples cannot prove atomic tracked, ignored, untracked, special-file, and replacement-race discovery" <> rawCommitmentDetail inputCommitment)
    ]
#endif

analyzeRawSourceInventory :: Text -> [RawSourceEntry] -> RawSourceAnalysis
analyzeRawSourceInventory claimedIdentity entries =
  case boundedUtf8TextBytes maximumRawSnapshotIdentityBytes claimedIdentity of
    PrefixExceeded observed
      | rawSnapshotIdentityByteLimitExceeded observed ->
          rawSourceFailure
            (rawBoundedRefusalCommitment claimedIdentity entries [RawSnapshotIdentityByteLimitExceeded maximumRawSnapshotIdentityBytes observed])
            "unavailable"
            "unavailable"
            [RawSnapshotIdentityByteLimitExceeded maximumRawSnapshotIdentityBytes observed]
    PrefixExceeded _ -> analyzeRawSourceEntries claimedIdentity entries
    PrefixWithin _ -> analyzeRawSourceEntries claimedIdentity entries

analyzeRawSourceEntries :: Text -> [RawSourceEntry] -> RawSourceAnalysis
analyzeRawSourceEntries claimedIdentity entries =
  case boundedPrefix maximumRawEntries entries of
    PrefixExceeded observed
      | rawEntryLimitExceeded observed ->
          rawSourceFailure
            (rawBoundedRefusalCommitment claimedIdentity entries [RawEntryLimitExceeded maximumRawEntries observed])
            (Text.pack (show observed) <> "+")
            "unavailable"
            [RawEntryLimitExceeded maximumRawEntries observed]
    PrefixExceeded _ -> analyzeRawSourceEntries claimedIdentity (take maximumRawEntries entries)
    PrefixWithin boundedEntries -> analyzeBoundedRawSourceEntries claimedIdentity boundedEntries

rawResourceStage :: [RawSourceProblem] -> [RawSourceProblem]
#if defined(VALIDATION_SOURCE_CLOSURE_RESOURCE_STAGE_DROP_MUTANT)
rawResourceStage _ = []
#elif defined(VALIDATION_SOURCE_CLOSURE_RESOURCE_PROBLEM_ORDER_MUTANT)
rawResourceStage = reverse
#else
rawResourceStage = id
#endif

rawAggregateStage, rawInventoryStage, rawFormatStage, rawIdentityStage :: [RawSourceProblem] -> [RawSourceProblem]
#if defined(VALIDATION_SOURCE_CLOSURE_AGGREGATE_STAGE_DROP_MUTANT)
rawAggregateStage _ = []
#else
rawAggregateStage = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_INVENTORY_STAGE_DROP_MUTANT)
rawInventoryStage _ = []
#else
rawInventoryStage = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_FORMAT_STAGE_DROP_MUTANT)
rawFormatStage _ = []
#else
rawFormatStage = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_IDENTITY_STAGE_DROP_MUTANT)
rawIdentityStage _ = []
#else
rawIdentityStage = id
#endif

rawGrammarProblemOrder, rawEntryGrammarProblemOrder, rawAllProblemOrder :: [RawSourceProblem] -> [RawSourceProblem]
#if defined(VALIDATION_SOURCE_CLOSURE_GRAMMAR_STAGE_DROP_MUTANT)
rawGrammarProblemOrder _ = []
#elif defined(VALIDATION_SOURCE_CLOSURE_GRAMMAR_PROBLEM_ORDER_MUTANT)
rawGrammarProblemOrder = reverse
#else
rawGrammarProblemOrder = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_GRAMMAR_PROBLEM_ORDER_MUTANT)
rawEntryGrammarProblemOrder = reverse
#else
rawEntryGrammarProblemOrder = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_ALL_PROBLEM_ORDER_MUTANT)
rawAllProblemOrder = reverse
#else
rawAllProblemOrder = id
#endif

rawTrackedStage :: Maybe [TrackedEntry] -> Maybe [TrackedEntry]
#if defined(VALIDATION_SOURCE_CLOSURE_TRACKED_STAGE_DROP_MUTANT)
rawTrackedStage _ = Nothing
#else
rawTrackedStage = id
#endif

analyzeBoundedRawSourceEntries :: Text -> [RawSourceEntry] -> RawSourceAnalysis
analyzeBoundedRawSourceEntries claimedIdentity entries =
  let entryCountText = Text.pack (show (length entries))
      resourceProblems = rawResourceStage (concat (zipWith rawEntryResourceProblems [1 ..] entries))
      aggregateResult = boundedRawAggregateBytes entries
      aggregateProblems =
        rawAggregateStage
          (case aggregateResult of
            Left observed -> [RawAggregateBlobByteLimitExceeded maximumRawAggregateBlobBytes observed]
            Right _ -> []
          )
      grammarProblems =
        if null resourceProblems && null aggregateProblems
          then
            rawGrammarProblemOrder
              (rawIdentityGrammarProblems claimedIdentity <> concat (zipWith rawEntryGrammarProblems [1 ..] entries))
          else []
      inventoryProblems =
        if null resourceProblems && null aggregateProblems && null grammarProblems
          then rawInventoryStage (rawInventoryProblems entries)
          else []
      inputCommitment =
        if null resourceProblems
            && null aggregateProblems
            && Text.all (not . surrogateCodePoint) claimedIdentity
            && all (all (not . surrogateCodePoint) . rawEntryPath) entries
            && all (Text.all (not . surrogateCodePoint) . rawEntryMode) entries
            && all (Text.all (not . surrogateCodePoint) . rawEntryObjectIdentity) entries
          then RawInputCommitment "complete-input" (rawSourceInputDigest claimedIdentity entries)
          else
            rawBoundedRefusalCommitment
              claimedIdentity
              entries
              (take (maximumRawProblems + 1) (resourceProblems <> aggregateProblems <> grammarProblems))
      objectFormatResult =
        if null resourceProblems && null aggregateProblems && null grammarProblems && null inventoryProblems
          then rawObjectFormat entries
          else Left []
      formatProblems = case objectFormatResult of
        Left problems -> rawFormatStage problems
        Right _ -> []
      trackedResult =
        if null formatProblems
          then rawTrackedStage (traverse rawTrackedEntry entries)
          else Nothing
      computedSnapshot = case (objectFormatResult, trackedResult) of
        (Right objectFormat, Just trackedEntries) -> computeSourceSnapshotIdentity objectFormat trackedEntries
        _ -> "unavailable"
      identityProblems =
        rawIdentityStage
          [ RawSnapshotIdentityMismatch computedSnapshot claimedIdentity
          | computedSnapshot /= "unavailable"
          , rawSnapshotIdentityMismatch claimedIdentity computedSnapshot
          ]
      allProblems =
        rawAllProblemOrder
          ( resourceProblems
              <> aggregateProblems
              <> grammarProblems
              <> inventoryProblems
              <> formatProblems
              <> identityProblems
          )
      (retainedProblems, problemCountText) = boundedRawProblems allProblems
      aggregateText = either (const "unavailable") (Text.pack . show) aggregateResult
   in case (retainedProblems, objectFormatResult, trackedResult) of
        ([], Right _objectFormat, Just trackedEntries) ->
          let snapshot =
                SourceSnapshot
                  { snapshotRoot = "."
                  , snapshotIdentity = computedSnapshot
                  , snapshotEntries = trackedEntries
                  }
              closure = classifySnapshot snapshot
           in RawSourceAnalysis
                { rawAnalysisInputCommitment = inputCommitment
                , rawAnalysisEntryCount = entryCountText
                , rawAnalysisAggregateBytes = aggregateText
                , rawAnalysisComputedSnapshot = computedSnapshot
                , rawAnalysisClassificationDigest = rawClassificationDigest closure
                , rawAnalysisClassCounts = rawClassCounts closure
                , rawAnalysisClosure = Just closure
                , rawAnalysisProblems = []
                , rawAnalysisProblemCount = "0"
                }
        _ ->
          (rawSourceFailure inputCommitment entryCountText aggregateText retainedProblems)
            { rawAnalysisComputedSnapshot = computedSnapshot
            , rawAnalysisProblemCount = problemCountText
            }

rawSourceFailure :: RawInputCommitment -> Text -> Text -> [RawSourceProblem] -> RawSourceAnalysis
rawSourceFailure inputCommitment entryCount aggregateBytes problems =
  RawSourceAnalysis
    { rawAnalysisInputCommitment = inputCommitment
    , rawAnalysisEntryCount = entryCount
    , rawAnalysisAggregateBytes = aggregateBytes
    , rawAnalysisComputedSnapshot = "unavailable"
    , rawAnalysisClassificationDigest = "unavailable"
    , rawAnalysisClassCounts = replicate 6 "unavailable"
    , rawAnalysisClosure = Nothing
    , rawAnalysisProblems = problems
    , rawAnalysisProblemCount = Text.pack (show (length problems))
    }

boundedRawProblems :: [RawSourceProblem] -> ([RawSourceProblem], Text)
boundedRawProblems problems = case boundedPrefix maximumRawProblems problems of
  PrefixWithin values -> (values, Text.pack (show (length values)))
  PrefixExceeded observed
    | rawProblemLimitExceeded observed ->
        ( [RawProblemLimitExceeded maximumRawProblems observed]
        , Text.pack (show observed) <> "+"
        )
  PrefixExceeded _ -> (take maximumRawProblems problems, Text.pack (show maximumRawProblems))

rawEntryResourceProblems :: Int -> RawSourceEntry -> [RawSourceProblem]
rawEntryResourceProblems ordinal entry =
  pathByteProblems
    <> pathDepthProblems
    <> pathSegmentProblems
    <> modeProblems
    <> objectProblems
    <> blobProblems
    <> semanticLineProblems
 where
  path = rawEntryPath entry
  pathBytesResult = boundedUtf8FilePathBytes maximumRawPathBytes path
  pathByteProblems = case pathBytesResult of
    PrefixExceeded observed
      | rawPathByteLimitExceeded observed -> [RawPathByteLimitExceeded ordinal maximumRawPathBytes observed]
    _ -> []
  pathParts = case pathByteProblems of
    [] -> Text.splitOn "/" (Text.pack path)
    _ -> []
  pathDepth = length pathParts
  pathDepthProblems =
    [ RawPathDepthLimitExceeded ordinal maximumRawPathDepth pathDepth
    | null pathByteProblems
    , rawPathDepthLimitExceeded pathDepth
    ]
  segmentLengths = map (utf8TextBytesUpTo (maximumRawPathSegmentBytes + 1)) pathParts
  pathSegmentProblems =
    [ RawPathSegmentByteLimitExceeded ordinal maximumRawPathSegmentBytes observed
    | null pathByteProblems
    , observed <- take 1 (filter rawPathSegmentByteLimitExceeded segmentLengths)
    ]
  modeProblems = case boundedUtf8TextBytes maximumRawModeBytes (rawEntryMode entry) of
    PrefixExceeded observed
      | rawModeByteLimitExceeded observed -> [RawModeByteLimitExceeded ordinal maximumRawModeBytes observed]
    _ -> []
  objectProblems = case boundedUtf8TextBytes maximumRawObjectIdentityBytes (rawEntryObjectIdentity entry) of
    PrefixExceeded observed
      | rawObjectIdentityByteLimitExceeded observed ->
          [RawObjectIdentityByteLimitExceeded ordinal maximumRawObjectIdentityBytes observed]
    _ -> []
  blobLength = ByteString.length (rawEntryBytes entry)
  blobProblems =
    [RawBlobByteLimitExceeded ordinal maximumRawBlobBytes blobLength | rawBlobByteLimitExceeded blobLength]
  semanticLineResult = boundedSignificantLineInspection maximumRawSemanticLineBytes (rawEntryBytes entry)
  semanticLineProblems = case semanticLineResult of
    Left observed
      | null blobProblems && rawSemanticLineByteLimitExceeded observed ->
          [RawSemanticLineByteLimitExceeded ordinal maximumRawSemanticLineBytes observed]
    _ -> []

boundedRawAggregateBytes :: [RawSourceEntry] -> Either Int Int
boundedRawAggregateBytes = go 0
 where
  go total remaining = case remaining of
    [] -> Right total
    entry : rest ->
      let next = total + ByteString.length (rawEntryBytes entry)
       in if rawAggregateBlobByteLimitExceeded next then Left next else go next rest

rawIdentityGrammarProblems :: Text -> [RawSourceProblem]
rawIdentityGrammarProblems value =
  [RawSnapshotIdentityMalformed value | not (rawSnapshotIdentityValid value)]

rawEntryGrammarProblems :: Int -> RawSourceEntry -> [RawSourceProblem]
rawEntryGrammarProblems ordinal entry =
  rawEntryGrammarProblemOrder
    ( rawPortablePathProblems ordinal path
        <> [RawModeMalformed ordinal mode | not (rawModeValid mode)]
        <> objectShapeProblems
        <> objectContentProblems
    )
 where
  path = rawEntryPath entry
  mode = rawEntryMode entry
  objectIdentity = rawEntryObjectIdentity entry
  objectShapeProblems =
    [RawObjectIdentityMalformed ordinal objectIdentity | not (rawObjectIdentityValid objectIdentity)]
  objectContentProblems = case objectShapeProblems of
    [] ->
      let actual = case Text.length objectIdentity of
            40 -> computeBlobObjectId GitObjectSha1 (rawEntryBytes entry)
            64 -> computeBlobObjectId GitObjectSha256 (rawEntryBytes entry)
            _ -> "unavailable"
       in [ RawObjectIdentityMismatch ordinal objectIdentity actual
          | not (rawBlobObjectIdentityMatches objectIdentity actual)
          ]
    _ -> []

rawInventoryProblems :: [RawSourceEntry] -> [RawSourceProblem]
rawInventoryProblems entries =
  emptyProblems <> duplicateProblems <> orderProblems <> caseProblems <> prefixProblems
 where
  paths = map rawEntryPath entries
  sortedPaths = sort paths
  emptyProblems = [RawEmptyInventory | null paths && rawEmptyInventoryRejected]
  duplicateProblems =
    [ RawDuplicatePath path
    | repeated <- group sortedPaths
    , path : _ : _ <- [repeated]
    , rawDuplicatePathRejected
    ]
  orderProblems =
    [RawEntryOrderInvalid paths | rawEntryOrderInvalid paths sortedPaths]
  caseProblems = case rawPortableCaseCollision paths of
    Nothing -> []
    Just (left, right) ->
      [RawPortableCaseCollision left right | rawPortableCaseCollisionRejected]
  prefixProblems = case rawPortablePrefixConflict sortedPaths of
    Nothing -> []
    Just (left, right) ->
      [RawPortablePrefixConflict left right | rawPortablePrefixConflictRejected]

rawObjectFormat :: [RawSourceEntry] -> Either [RawSourceProblem] GitObjectFormat
rawObjectFormat entries =
  case Set.toAscList (Set.fromList (map (Text.length . rawEntryObjectIdentity) entries)) of
#if defined(VALIDATION_SOURCE_CLOSURE_OBJECT_FORMAT_SHA1_ROUTE_MUTANT)
    [40] -> Right GitObjectSha256
#else
    [40] -> Right GitObjectSha1
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_OBJECT_FORMAT_SHA256_ROUTE_MUTANT)
    [64] -> Right GitObjectSha1
#else
    [64] -> Right GitObjectSha256
#endif
    widths
      | rawMixedObjectIdentityFormatsRejected -> Left [RawMixedObjectIdentityFormats widths]
      | otherwise -> Right GitObjectSha1

rawTrackedEntry :: RawSourceEntry -> Maybe TrackedEntry
rawTrackedEntry entry = do
  mode <- rawIndexMode (rawEntryMode entry)
  pure
    TrackedEntry
      { trackedIndex =
          IndexEntry
            { indexPath = rawTrackedPath (rawEntryPath entry)
            , indexMode = mode
            , indexObjectId = rawTrackedObject (rawEntryObjectIdentity entry)
            }
      , trackedBytes = rawTrackedBytes (rawEntryBytes entry)
      }

rawIndexMode :: Text -> Maybe IndexMode
#if defined(VALIDATION_SOURCE_CLOSURE_INDEX_MODE_REGULAR_ROUTE_MUTANT)
rawIndexMode "100644" = Just ExecutableFile
#else
rawIndexMode "100644" = Just RegularFile
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_INDEX_MODE_EXECUTABLE_ROUTE_MUTANT)
rawIndexMode "100755" = Just RegularFile
#else
rawIndexMode "100755" = Just ExecutableFile
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_INDEX_MODE_SYMLINK_ROUTE_MUTANT)
rawIndexMode "120000" = Just RegularFile
#else
rawIndexMode "120000" = Just SymbolicLink
#endif
rawIndexMode _ = Nothing

rawTrackedPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CLOSURE_TRACKED_PATH_ROUTE_MUTANT)
rawTrackedPath _ = "src/Mutant.hs"
#else
rawTrackedPath = id
#endif

rawTrackedObject :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_TRACKED_OBJECT_ROUTE_MUTANT)
rawTrackedObject = Text.map (const '0')
#else
rawTrackedObject = id
#endif

rawTrackedBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_CLOSURE_TRACKED_BYTES_ROUTE_MUTANT)
rawTrackedBytes = ByteString.drop 1
#else
rawTrackedBytes = id
#endif

rawClosureFindings :: RawInputCommitment -> SourceClosure -> [Finding]
rawClosureFindings inputCommitment closure =
  localPathFindings <> boundPbFindings
 where
  localPathFindings =
    [ rawMappedFinding
        28
        "SRC-UNREGISTERED"
        (indexPath (trackedIndex (classifiedEntry item)))
        (Text.intercalate "; " (classificationReasons item) <> rawCommitmentDetail inputCommitment)
    | item <- closurePaths closure
    , classifiedAs item == UnregisteredBehavioralSource
    ]
  boundPbFindings =
    [ problem
        { findingDetail =
            findingDetail problem
              <> rawPbFindingCommitment (rawCommitmentDetail inputCommitment)
        }
    | (ordinal, problem) <- zip [1 ..] (rawPbFindingOrder (checkFindings (closurePbBootstrapDiagnostic closure)))
    , rawPbDiagnosticFindingRetained problem
    , rawPbRuntimeFindingRetained ordinal problem
    ]

rawPbDiagnosticFindingRetained :: Finding -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PB_DIAGNOSTIC_RETENTION_DROP_MUTANT)
rawPbDiagnosticFindingRetained problem = findingCode problem /= "PB-GRAMMAR-DIAGNOSTIC-ONLY"
#else
rawPbDiagnosticFindingRetained _ = True
#endif

rawPbRuntimeFindingRetained :: Int -> Finding -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PB_FIRST_RUNTIME_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 2 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_02_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 3 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_03_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 4 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_04_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 5 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_05_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 6 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_06_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 7 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_07_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 8 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_08_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 9 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_09_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 10 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_10_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 11 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_11_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 12 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_12_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 13 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_13_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 14 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_14_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 15 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_15_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 16 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_16_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 17 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_17_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 18 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_18_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 19 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_19_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 20 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_20_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 21 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#elif defined(VALIDATION_SOURCE_CLOSURE_PB_RUNTIME_21_RETENTION_DROP_MUTANT)
rawPbRuntimeFindingRetained ordinal problem =
  ordinal /= 22 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#else
rawPbRuntimeFindingRetained _ _ = True
#endif

rawPbFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CLOSURE_PB_FINDING_ORDER_MUTANT)
rawPbFindingOrder = reverse
#else
rawPbFindingOrder = id
#endif

rawPbFindingCommitment :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_PB_FINDING_COMMITMENT_DROP_MUTANT)
rawPbFindingCommitment _ = ""
#else
rawPbFindingCommitment = id
#endif

rawClassCounts :: SourceClosure -> [Text]
rawClassCounts closure =
  rawClassCountOrder (map (Text.pack . show) [haskellCount, documentCount, projectCount, pbCount, legacyCount, unregisteredCount])
 where
  classes = map classifiedAs (closurePaths closure)
  count predicate = length (filter predicate classes)
  haskellCount = count rawHaskellClass
  documentCount = count rawDocumentationClass
  projectCount = count rawProjectClass
  pbCount = count rawPbClass
  legacyCount = count rawLegacyClass
  unregisteredCount = count rawUnregisteredClass

rawHaskellClass, rawDocumentationClass, rawProjectClass, rawPbClass, rawLegacyClass, rawUnregisteredClass :: SourceClass -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_HASKELL_PREDICATE_MUTANT)
rawHaskellClass _ = False
#else
rawHaskellClass = (== HaskellSource)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_DOCUMENTATION_PREDICATE_MUTANT)
rawDocumentationClass _ = False
#else
rawDocumentationClass = (== DocumentationInput)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_PROJECT_PREDICATE_MUTANT)
rawProjectClass _ = False
#else
rawProjectClass = (== ProjectDeclaration)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_PB_PREDICATE_MUTANT)
rawPbClass _ = False
#else
rawPbClass = (== RegisteredLegacy SourcePb)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_LEGACY_PREDICATE_MUTANT)
rawLegacyClass _ = False
#else
rawLegacyClass = isRegistered
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_UNREGISTERED_PREDICATE_MUTANT)
rawUnregisteredClass _ = False
#else
rawUnregisteredClass = (== UnregisteredBehavioralSource)
#endif

rawClassCountOrder :: [Text] -> [Text]
#if defined(VALIDATION_SOURCE_CLOSURE_CLASS_COUNT_ORDER_MUTANT)
rawClassCountOrder = reverse
#else
rawClassCountOrder = id
#endif

rawClassificationDigest :: SourceClosure -> Text
rawClassificationDigest closure = hex (SHA256.finalize finalContext)
 where
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_DOMAIN_DROP_MUTANT)
  initialContext = SHA256.init
#else
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-classification-v1\0"
#endif
  finalContext = foldl' updateClassifiedPath initialContext (rawClassificationItems (closurePaths closure))
  updateClassifiedPath context item =
    foldl'
      updateLengthPrefixedText
      context
      [ rawClassificationPath (Text.pack (indexPath indexed))
      , rawClassificationMode (renderIndexMode (indexMode indexed))
      , rawClassificationObject (indexObjectId indexed)
      , rawClassificationClass (renderSourceClass (classifiedAs item))
      , rawClassificationFacets (Text.intercalate "," (map renderSourceFacet (classificationFacets item)))
      , rawClassificationReasons (Text.intercalate "; " (classificationReasons item))
      ]
   where
    indexed = trackedIndex (classifiedEntry item)

rawClassificationItems :: [ClassifiedPath] -> [ClassifiedPath]
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_ITEM_ORDER_MUTANT)
rawClassificationItems = reverse
#else
rawClassificationItems = id
#endif

rawClassificationPath, rawClassificationMode, rawClassificationObject :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_PATH_DROP_MUTANT)
rawClassificationPath _ = ""
#else
rawClassificationPath = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_MODE_DROP_MUTANT)
rawClassificationMode _ = ""
#else
rawClassificationMode = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_OBJECT_DROP_MUTANT)
rawClassificationObject _ = ""
#else
rawClassificationObject = id
#endif

rawClassificationClass, rawClassificationFacets, rawClassificationReasons :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_CLASS_DROP_MUTANT)
rawClassificationClass _ = ""
#else
rawClassificationClass = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_FACETS_DROP_MUTANT)
rawClassificationFacets _ = ""
#else
rawClassificationFacets = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_CLASSIFICATION_DIGEST_REASONS_DROP_MUTANT)
rawClassificationReasons _ = ""
#else
rawClassificationReasons = id
#endif

rawInputEntryOrder :: [RawSourceEntry] -> [RawSourceEntry]
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_ENTRY_ORDER_MUTANT)
rawInputEntryOrder = reverse
#else
rawInputEntryOrder = id
#endif

rawInputClaimedContribution :: SHA256.Ctx -> Text -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_CLAIMED_DROP_MUTANT)
rawInputClaimedContribution context _ = context
#else
rawInputClaimedContribution = updateLengthPrefixedText
#endif

rawInputPathContribution, rawInputModeContribution, rawInputObjectContribution :: SHA256.Ctx -> Text -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_PATH_DROP_MUTANT)
rawInputPathContribution context _ = context
#else
rawInputPathContribution = updateLengthPrefixedText
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_MODE_DROP_MUTANT)
rawInputModeContribution context _ = context
#else
rawInputModeContribution = updateLengthPrefixedText
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_OBJECT_DROP_MUTANT)
rawInputObjectContribution context _ = context
#else
rawInputObjectContribution = updateLengthPrefixedText
#endif

rawInputBytesContribution :: SHA256.Ctx -> ByteString -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_BYTES_DROP_MUTANT)
rawInputBytesContribution context _ = context
#else
rawInputBytesContribution = updateLengthPrefixedBytes
#endif

rawBoundedClaimedContribution, rawBoundedEntryStateContribution :: SHA256.Ctx -> Text -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_DIGEST_CLAIMED_DROP_MUTANT)
rawBoundedClaimedContribution context _ = context
#else
rawBoundedClaimedContribution = updateLengthPrefixedText
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_DIGEST_ENTRY_STATE_DROP_MUTANT)
rawBoundedEntryStateContribution context _ = context
#else
rawBoundedEntryStateContribution = updateLengthPrefixedText
#endif

rawLengthPrefixContribution :: SHA256.Ctx -> ByteString -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_LENGTH_PREFIX_LENGTH_DROP_MUTANT)
rawLengthPrefixContribution context _ = context
#else
rawLengthPrefixContribution = SHA256.update
#endif

rawLengthSeparatorContribution :: SHA256.Ctx -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_LENGTH_PREFIX_SEPARATOR_DROP_MUTANT)
rawLengthSeparatorContribution = id
#else
rawLengthSeparatorContribution context = SHA256.update context ":"
#endif

rawLengthPrefixedValue :: SHA256.Ctx -> ByteString -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_LENGTH_PREFIX_VALUE_DROP_MUTANT)
rawLengthPrefixedValue context _ = context
#else
rawLengthPrefixedValue = SHA256.update
#endif

rawSourceInputDigest :: Text -> [RawSourceEntry] -> Text
rawSourceInputDigest claimedIdentity entries = hex (SHA256.finalize finalContext)
 where
#if defined(VALIDATION_SOURCE_CLOSURE_INPUT_DIGEST_DOMAIN_DROP_MUTANT)
  initialContext = SHA256.init
#else
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-input-v1\0"
#endif
  claimedContext = rawInputClaimedContribution initialContext claimedIdentity
  finalContext = foldl' updateRawEntry claimedContext (rawInputEntryOrder entries)
  updateRawEntry context entry =
    rawInputBytesContribution blobContext (rawEntryBytes entry)
   where
    pathContext = rawInputPathContribution context (Text.pack (rawEntryPath entry))
    modeContext = rawInputModeContribution pathContext (rawEntryMode entry)
    blobContext = rawInputObjectContribution modeContext (rawEntryObjectIdentity entry)

-- | Commit only the bounded state which was safe to observe before a resource
-- refusal.  This is intentionally not the complete-input domain: an
-- over-limit tail is neither traversed nor represented as though it had been.
rawBoundedRefusalCommitment
  :: Text
  -> [RawSourceEntry]
  -> [RawSourceProblem]
  -> RawInputCommitment
rawBoundedRefusalCommitment claimedIdentity entries problems =
  RawInputCommitment
    "bounded-preflight-refusal"
    (hex (SHA256.finalize problemContext))
 where
#if defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_DIGEST_DOMAIN_DROP_MUTANT)
  initialContext = SHA256.init
#else
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-bounded-refusal-v1\0"
#endif
  claimedPrefix = Text.take (maximumRawSnapshotIdentityBytes + 1) claimedIdentity
  claimedContext = rawBoundedClaimedContribution initialContext claimedPrefix
  entryState = case boundedPrefix maximumRawEntries entries of
    PrefixWithin values -> "within:" <> Text.pack (show (length values))
    PrefixExceeded observed -> "exceeded-at-least:" <> Text.pack (show observed)
  entryContext = rawBoundedEntryStateContribution claimedContext entryState
  problemContext =
    foldl'
      updateLengthPrefixedText
      entryContext
      (map rawProblemCommitmentTag (rawBoundedProblemOrder problems))

rawBoundedProblemOrder :: [RawSourceProblem] -> [RawSourceProblem]
#if defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_ORDER_MUTANT)
rawBoundedProblemOrder = reverse
#else
rawBoundedProblemOrder = id
#endif

rawBoundedProblemTag :: Int -> Text -> Text
rawBoundedProblemTag ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_05_MAPPING_MUTANT)
  | ordinal == 5 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_06_MAPPING_MUTANT)
  | ordinal == 6 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_07_MAPPING_MUTANT)
  | ordinal == 7 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_08_MAPPING_MUTANT)
  | ordinal == 8 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_09_MAPPING_MUTANT)
  | ordinal == 9 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_BOUNDED_PROBLEM_TAG_10_MAPPING_MUTANT)
  | ordinal == 10 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawCommitmentDetailKind, rawCommitmentDetailDigest :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_COMMITMENT_DETAIL_KIND_DROP_MUTANT)
rawCommitmentDetailKind _ = ""
#else
rawCommitmentDetailKind = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_COMMITMENT_DETAIL_DIGEST_DROP_MUTANT)
rawCommitmentDetailDigest _ = ""
#else
rawCommitmentDetailDigest = id
#endif

rawProblemCommitmentTag :: RawSourceProblem -> Text
rawProblemCommitmentTag problem = case problem of
  RawSnapshotIdentityByteLimitExceeded maximumValue observed -> rawBoundedProblemTag 1 (numeric "identity-bytes" [maximumValue, observed])
  RawEntryLimitExceeded maximumValue observed -> rawBoundedProblemTag 2 (numeric "entries" [maximumValue, observed])
  RawPathByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 3 (numeric "path-bytes" [ordinal, maximumValue, observed])
  RawPathDepthLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 4 (numeric "path-depth" [ordinal, maximumValue, observed])
  RawPathSegmentByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 5 (numeric "path-segment-bytes" [ordinal, maximumValue, observed])
  RawModeByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 6 (numeric "mode-bytes" [ordinal, maximumValue, observed])
  RawObjectIdentityByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 7 (numeric "object-id-bytes" [ordinal, maximumValue, observed])
  RawBlobByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 8 (numeric "blob-bytes" [ordinal, maximumValue, observed])
  RawAggregateBlobByteLimitExceeded maximumValue observed -> rawBoundedProblemTag 9 (numeric "aggregate-blob-bytes" [maximumValue, observed])
  RawSemanticLineByteLimitExceeded ordinal maximumValue observed -> rawBoundedProblemTag 10 (numeric "semantic-line-bytes" [ordinal, maximumValue, observed])
  RawSnapshotIdentityMalformed _ -> "snapshot-identity-unrepresentable"
  RawPathMalformed ordinal _ detail -> "path-unrepresentable:" <> Text.pack (show ordinal) <> ":" <> detail
  _ -> "bounded-non-resource-preflight"
 where
  numeric label values = label <> ":" <> Text.intercalate ":" (map (Text.pack . show) values)

updateLengthPrefixedText :: SHA256.Ctx -> Text -> SHA256.Ctx
updateLengthPrefixedText context = updateLengthPrefixedBytes context . TextEncoding.encodeUtf8

updateLengthPrefixedBytes :: SHA256.Ctx -> ByteString -> SHA256.Ctx
updateLengthPrefixedBytes context bytes = rawLengthPrefixedValue separatorContext bytes
 where
  lengthBytes = ByteString8.pack (show (ByteString.length bytes))
  lengthContext = rawLengthPrefixContribution context lengthBytes
  separatorContext = rawLengthSeparatorContribution lengthContext

rawPortablePathProblems :: Int -> FilePath -> [RawSourceProblem]
rawPortablePathProblems ordinal path
  | not (rawPathNonempty path) = malformed "path is empty"
  | not (rawPathRelative path) = malformed "path is absolute"
  | not (rawPathAlphabetValid path) = malformed "path contains a non-portable character"
  | not (rawPathSegmentsNonempty parts) = malformed "path contains an empty segment"
  | not (rawPathDotSegmentsAbsent parts) = malformed "path contains a dot segment"
  | not (rawPathParentSegmentsAbsent parts) = malformed "path contains a parent segment"
  | not (rawPathGitSegmentsAbsent parts) = malformed "path contains a repository-control segment"
  | not (rawPathTrailingDotsAbsent parts) = malformed "path contains a trailing-dot segment"
  | Just reserved <- rawPathReservedSegment parts = malformed ("path contains reserved segment " <> reserved)
  | otherwise = []
 where
  parts = Text.splitOn "/" (Text.pack path)
  malformed detail = [RawPathMalformed ordinal path detail]

rawPortablePathCharacter :: Char -> Bool
rawPortablePathCharacter character =
  rawPathLowerCharacter character
    || rawPathUpperCharacter character
    || rawPathDigitCharacter character
    || rawPathPunctuationCharacter character

rawPathNonempty :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_NONEMPTY_BYPASS_MUTANT)
rawPathNonempty _ = True
#else
rawPathNonempty = not . null
#endif

rawPathRelative :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RELATIVE_BYPASS_MUTANT)
rawPathRelative _ = True
#else
rawPathRelative path = case path of
  '/' : _ -> False
  _ -> True
#endif

rawPathAlphabetValid :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_ALPHABET_BYPASS_MUTANT)
rawPathAlphabetValid path = all rawPortablePathCharacter path `seq` True
#else
rawPathAlphabetValid = all rawPortablePathCharacter
#endif

rawPathSegmentsNonempty :: [Text] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_EMPTY_SEGMENT_BYPASS_MUTANT)
rawPathSegmentsNonempty _ = True
#else
rawPathSegmentsNonempty = all (not . Text.null)
#endif

rawPathDotSegmentsAbsent :: [Text] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_DOT_SEGMENT_BYPASS_MUTANT)
rawPathDotSegmentsAbsent _ = True
#else
rawPathDotSegmentsAbsent = all (/= ".")
#endif

rawPathParentSegmentsAbsent :: [Text] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_PARENT_SEGMENT_BYPASS_MUTANT)
rawPathParentSegmentsAbsent _ = True
#else
rawPathParentSegmentsAbsent = all (/= "..")
#endif

rawPathGitSegmentsAbsent :: [Text] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_GIT_SEGMENT_BYPASS_MUTANT)
rawPathGitSegmentsAbsent _ = True
#else
rawPathGitSegmentsAbsent = all ((/= ".git") . Text.toLower)
#endif

rawPathTrailingDotsAbsent :: [Text] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_TRAILING_DOT_BYPASS_MUTANT)
rawPathTrailingDotsAbsent _ = True
#else
rawPathTrailingDotsAbsent = all (not . Text.isSuffixOf ".")
#endif

rawPathReservedSegment :: [Text] -> Maybe Text
rawPathReservedSegment = firstReservedPortableSegment

rawPathLowerCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_LOWER_RANGE_REMOVAL_MUTANT)
rawPathLowerCharacter _ = False
#else
rawPathLowerCharacter character = character >= 'a' && character <= 'z'
#endif

rawPathUpperCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_UPPER_RANGE_REMOVAL_MUTANT)
rawPathUpperCharacter _ = False
#else
rawPathUpperCharacter character = character >= 'A' && character <= 'Z'
#endif

rawPathDigitCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_DIGIT_RANGE_REMOVAL_MUTANT)
rawPathDigitCharacter _ = False
#else
rawPathDigitCharacter character = character >= '0' && character <= '9'
#endif

rawPathPunctuationCharacter :: Char -> Bool
rawPathPunctuationCharacter character =
  rawPathSlashCharacter character
    || rawPathDotCharacter character
    || rawPathUnderscoreCharacter character
    || rawPathAtCharacter character
    || rawPathPlusCharacter character
    || rawPathCommaCharacter character
    || rawPathHyphenCharacter character

rawPathSlashCharacter, rawPathDotCharacter, rawPathUnderscoreCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_SLASH_REMOVAL_MUTANT)
rawPathSlashCharacter _ = False
#else
rawPathSlashCharacter = (== '/')
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_DOT_REMOVAL_MUTANT)
rawPathDotCharacter _ = False
#else
rawPathDotCharacter = (== '.')
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_UNDERSCORE_REMOVAL_MUTANT)
rawPathUnderscoreCharacter _ = False
#else
rawPathUnderscoreCharacter = (== '_')
#endif

rawPathAtCharacter, rawPathPlusCharacter, rawPathCommaCharacter, rawPathHyphenCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_AT_REMOVAL_MUTANT)
rawPathAtCharacter _ = False
#else
rawPathAtCharacter = (== '@')
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_PLUS_REMOVAL_MUTANT)
rawPathPlusCharacter _ = False
#else
rawPathPlusCharacter = (== '+')
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_COMMA_REMOVAL_MUTANT)
rawPathCommaCharacter _ = False
#else
rawPathCommaCharacter = (== ',')
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_HYPHEN_REMOVAL_MUTANT)
rawPathHyphenCharacter _ = False
#else
rawPathHyphenCharacter = (== '-')
#endif

firstReservedPortableSegment :: [Text] -> Maybe Text
firstReservedPortableSegment = firstMatchBy rawWindowsReservedSegment

firstMatchBy :: (value -> Bool) -> [value] -> Maybe value
firstMatchBy predicate values = case values of
  [] -> Nothing
  value : rest
    | predicate value -> Just value
    | otherwise -> firstMatchBy predicate rest

rawWindowsReservedSegment :: Text -> Bool
rawWindowsReservedSegment segment =
  rawReservedCon base
    || rawReservedPrn base
    || rawReservedAux base
    || rawReservedNul base
    || rawReservedCom1 base
    || rawReservedCom2 base
    || rawReservedCom3 base
    || rawReservedCom4 base
    || rawReservedCom5 base
    || rawReservedCom6 base
    || rawReservedCom7 base
    || rawReservedCom8 base
    || rawReservedCom9 base
    || rawReservedLpt1 base
    || rawReservedLpt2 base
    || rawReservedLpt3 base
    || rawReservedLpt4 base
    || rawReservedLpt5 base
    || rawReservedLpt6 base
    || rawReservedLpt7 base
    || rawReservedLpt8 base
    || rawReservedLpt9 base
 where
  base = rawReservedCasefold (rawReservedBase segment)

rawReservedBase :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_EXTENSION_BYPASS_MUTANT)
rawReservedBase = id
#else
rawReservedBase = Text.takeWhile (/= '.')
#endif

rawReservedCasefold :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_CASEFOLD_BYPASS_MUTANT)
rawReservedCasefold = id
#else
rawReservedCasefold = Text.toUpper
#endif

rawReservedCon, rawReservedPrn, rawReservedAux, rawReservedNul :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_CON_BYPASS_MUTANT)
rawReservedCon _ = False
#else
rawReservedCon = (== "CON")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_PRN_BYPASS_MUTANT)
rawReservedPrn _ = False
#else
rawReservedPrn = (== "PRN")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_AUX_BYPASS_MUTANT)
rawReservedAux _ = False
#else
rawReservedAux = (== "AUX")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_NUL_BYPASS_MUTANT)
rawReservedNul _ = False
#else
rawReservedNul = (== "NUL")
#endif

rawReservedCom1, rawReservedCom2, rawReservedCom3, rawReservedCom4 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM1_BYPASS_MUTANT)
rawReservedCom1 _ = False
#else
rawReservedCom1 = (== "COM1")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM2_BYPASS_MUTANT)
rawReservedCom2 _ = False
#else
rawReservedCom2 = (== "COM2")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM3_BYPASS_MUTANT)
rawReservedCom3 _ = False
#else
rawReservedCom3 = (== "COM3")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM4_BYPASS_MUTANT)
rawReservedCom4 _ = False
#else
rawReservedCom4 = (== "COM4")
#endif

rawReservedCom5, rawReservedCom6, rawReservedCom7, rawReservedCom8 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM5_BYPASS_MUTANT)
rawReservedCom5 _ = False
#else
rawReservedCom5 = (== "COM5")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM6_BYPASS_MUTANT)
rawReservedCom6 _ = False
#else
rawReservedCom6 = (== "COM6")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM7_BYPASS_MUTANT)
rawReservedCom7 _ = False
#else
rawReservedCom7 = (== "COM7")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM8_BYPASS_MUTANT)
rawReservedCom8 _ = False
#else
rawReservedCom8 = (== "COM8")
#endif

rawReservedCom9 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM9_BYPASS_MUTANT)
rawReservedCom9 _ = False
#else
rawReservedCom9 = (== "COM9")
#endif

rawReservedLpt1, rawReservedLpt2, rawReservedLpt3, rawReservedLpt4 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT1_BYPASS_MUTANT)
rawReservedLpt1 _ = False
#else
rawReservedLpt1 = (== "LPT1")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT2_BYPASS_MUTANT)
rawReservedLpt2 _ = False
#else
rawReservedLpt2 = (== "LPT2")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT3_BYPASS_MUTANT)
rawReservedLpt3 _ = False
#else
rawReservedLpt3 = (== "LPT3")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT4_BYPASS_MUTANT)
rawReservedLpt4 _ = False
#else
rawReservedLpt4 = (== "LPT4")
#endif

rawReservedLpt5, rawReservedLpt6, rawReservedLpt7, rawReservedLpt8 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT5_BYPASS_MUTANT)
rawReservedLpt5 _ = False
#else
rawReservedLpt5 = (== "LPT5")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT6_BYPASS_MUTANT)
rawReservedLpt6 _ = False
#else
rawReservedLpt6 = (== "LPT6")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT7_BYPASS_MUTANT)
rawReservedLpt7 _ = False
#else
rawReservedLpt7 = (== "LPT7")
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT8_BYPASS_MUTANT)
rawReservedLpt8 _ = False
#else
rawReservedLpt8 = (== "LPT8")
#endif

rawReservedLpt9 :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT9_BYPASS_MUTANT)
rawReservedLpt9 _ = False
#else
rawReservedLpt9 = (== "LPT9")
#endif

rawPortableCaseCollision :: [FilePath] -> Maybe (FilePath, FilePath)
rawPortableCaseCollision paths = findCollision Map.empty paths
 where
  findCollision _ [] = Nothing
  findCollision seen (path : rest) =
    let key = Text.toLower (Text.pack path)
     in case Map.lookup key seen of
          Just previous | previous /= path -> Just (previous, path)
          _ -> findCollision (Map.insert key path seen) rest

rawPortablePrefixConflict :: [FilePath] -> Maybe (FilePath, FilePath)
rawPortablePrefixConflict = go Set.empty
 where
  go _ [] = Nothing
  go seen (current : remaining) =
    case firstMatchBy (`Set.member` seen) (rawPortableAncestors current) of
      Just ancestor -> Just (ancestor, current)
      Nothing -> go (Set.insert current seen) remaining

rawPortableAncestors :: FilePath -> [FilePath]
rawPortableAncestors path = go [] (Text.splitOn "/" (Text.pack path))
 where
  go _ [] = []
  go _ [_] = []
  go prefix (part : remaining) =
    let next = prefix <> [part]
     in Text.unpack (Text.intercalate "/" next) : go next remaining

rawSnapshotIdentityValid :: Text -> Bool
rawSnapshotIdentityValid value =
  rawSnapshotIdentityWidthValid value && rawSnapshotIdentityAlphabetValid value

rawSnapshotIdentityWidthValid :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_IDENTITY_WIDTH_BYPASS_MUTANT)
rawSnapshotIdentityWidthValid _ = True
#else
rawSnapshotIdentityWidthValid value = Text.length value == 64
#endif

rawSnapshotIdentityAlphabetValid :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_IDENTITY_ALPHABET_BYPASS_MUTANT)
rawSnapshotIdentityAlphabetValid _ = True
#else
rawSnapshotIdentityAlphabetValid = Text.all asciiLowerHex
#endif

rawObjectIdentityValid :: Text -> Bool
rawObjectIdentityValid value =
  rawObjectIdentityWidthValid value && rawObjectIdentityAlphabetValid value

rawObjectIdentityWidthValid :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_OBJECT_ID_WIDTH_BYPASS_MUTANT)
rawObjectIdentityWidthValid _ = True
#else
rawObjectIdentityWidthValid value = Text.length value `elem` [40, 64]
#endif

rawObjectIdentityAlphabetValid :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_OBJECT_ID_ALPHABET_BYPASS_MUTANT)
rawObjectIdentityAlphabetValid _ = True
#else
rawObjectIdentityAlphabetValid = Text.all asciiLowerHex
#endif

rawModeValid :: Text -> Bool
rawModeValid value =
  rawRegularModeRetained value
    || rawExecutableModeRetained value
    || rawSymbolicLinkModeRetained value

rawRegularModeRetained :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_MODE_REGULAR_REMOVAL_MUTANT)
rawRegularModeRetained _ = False
#else
rawRegularModeRetained = (== "100644")
#endif

rawExecutableModeRetained :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_MODE_EXECUTABLE_REMOVAL_MUTANT)
rawExecutableModeRetained _ = False
#else
rawExecutableModeRetained = (== "100755")
#endif

rawSymbolicLinkModeRetained :: Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_MODE_SYMLINK_REMOVAL_MUTANT)
rawSymbolicLinkModeRetained _ = False
#else
rawSymbolicLinkModeRetained = (== "120000")
#endif

rawBlobObjectIdentityMatches :: Text -> Text -> Bool
rawBlobObjectIdentityMatches expected actual = case Text.length expected of
  40 -> rawSha1BlobIdentityMatches expected actual
  64 -> rawSha256BlobIdentityMatches expected actual
  _ -> False

rawSha1BlobIdentityMatches :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_BLOB_SHA1_MATCH_BYPASS_MUTANT)
rawSha1BlobIdentityMatches _ _ = True
#else
rawSha1BlobIdentityMatches = (==)
#endif

rawSha256BlobIdentityMatches :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_BLOB_SHA256_MATCH_BYPASS_MUTANT)
rawSha256BlobIdentityMatches _ _ = True
#else
rawSha256BlobIdentityMatches = (==)
#endif

rawMixedObjectIdentityFormatsRejected :: Bool
#if defined(VALIDATION_SOURCE_CLOSURE_MIXED_OBJECT_FORMAT_BYPASS_MUTANT)
rawMixedObjectIdentityFormatsRejected = False
#else
rawMixedObjectIdentityFormatsRejected = True
#endif

rawPortableCaseCollisionRejected :: Bool
#if defined(VALIDATION_SOURCE_CLOSURE_CASE_COLLISION_BYPASS_MUTANT)
rawPortableCaseCollisionRejected = False
#else
rawPortableCaseCollisionRejected = True
#endif

rawPortablePrefixConflictRejected :: Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PREFIX_CONFLICT_BYPASS_MUTANT)
rawPortablePrefixConflictRejected = False
#else
rawPortablePrefixConflictRejected = True
#endif

boundedUtf8TextBytes :: Int -> Text -> BoundedPrefix Char
boundedUtf8TextBytes limit = boundedUtf8Characters limit . Text.unpack

boundedUtf8FilePathBytes :: Int -> FilePath -> BoundedPrefix Char
boundedUtf8FilePathBytes = boundedUtf8Characters

boundedUtf8Characters :: Int -> [Char] -> BoundedPrefix Char
boundedUtf8Characters limit = go 0 []
 where
  go count reversed characters = case characters of
    [] -> PrefixWithin (reverse reversed)
    character : rest ->
      let next = count + utf8CharacterBytes character
       in if next > limit
            then PrefixExceeded next
            else go next (character : reversed) rest

utf8TextBytesUpTo :: Int -> Text -> Int
utf8TextBytesUpTo limit = Text.foldl' step 0
 where
  step count character
    | count >= limit = count
    | otherwise = min limit (count + utf8CharacterBytes character)

utf8CharacterBytes :: Char -> Int
utf8CharacterBytes character
  | code <= 0x7f = rawUtf8Width 1 1
  | code <= 0x7ff = rawUtf8Width 2 2
  | code <= 0xffff = rawUtf8Width 3 3
  | otherwise = rawUtf8Width 4 4
 where
  code = ord character

-- | Bound the complete scan needed to identify the first significant source
-- line.  A longer blob is admitted only when a non-blank physical line has
-- ended inside the prefix; classification never searches past this envelope.
boundedSignificantLineInspection :: Int -> ByteString -> Either Int Int
boundedSignificantLineInspection limit bytes = go 0 False (ByteString.take (limit + 1) bytes)
 where
  blobWithinLimit = rawSemanticBlobWithinLimit (ByteString.length bytes <= limit)
  go consumed significant remaining = case ByteString.uncons remaining of
    Nothing
      | blobWithinLimit -> Right consumed
      | otherwise -> Left (limit + 1)
    Just (byte, rest)
      | consumed == limit -> rawSemanticLimitResult limit
      | rawSemanticLf byte || rawSemanticCr byte ->
          if significant
            then Right (consumed + 1)
            else go (consumed + 1) False rest
      | rawSemanticTab byte || rawSemanticSpace byte -> go (consumed + 1) significant rest
      | otherwise -> go (consumed + 1) (rawSemanticSignificant significant) rest

rawUtf8Width :: Int -> Int -> Int
rawUtf8Width ordinal width
#if defined(VALIDATION_SOURCE_CLOSURE_UTF8_ASCII_WIDTH_MUTANT)
  | ordinal == 1 = 2
#elif defined(VALIDATION_SOURCE_CLOSURE_UTF8_TWO_BYTE_WIDTH_MUTANT)
  | ordinal == 2 = 1
#elif defined(VALIDATION_SOURCE_CLOSURE_UTF8_THREE_BYTE_WIDTH_MUTANT)
  | ordinal == 3 = 1
#elif defined(VALIDATION_SOURCE_CLOSURE_UTF8_FOUR_BYTE_WIDTH_MUTANT)
  | ordinal == 4 = 1
#endif
  | otherwise = ordinal `seq` width

rawSemanticBlobWithinLimit :: Bool -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_BLOB_WITHIN_LIMIT_MUTANT)
rawSemanticBlobWithinLimit _ = False
#else
rawSemanticBlobWithinLimit = id
#endif

rawSemanticLimitResult :: Int -> Either Int Int
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_LIMIT_RESULT_MUTANT)
rawSemanticLimitResult = Right
#else
rawSemanticLimitResult limit = Left (limit + 1)
#endif

rawSemanticLf, rawSemanticCr, rawSemanticTab, rawSemanticSpace :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_LF_BYPASS_MUTANT)
rawSemanticLf _ = False
#else
rawSemanticLf = (== 10)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_CR_BYPASS_MUTANT)
rawSemanticCr _ = False
#else
rawSemanticCr = (== 13)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_TAB_BYPASS_MUTANT)
rawSemanticTab _ = False
#else
rawSemanticTab = (== 9)
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_SPACE_BYPASS_MUTANT)
rawSemanticSpace _ = False
#else
rawSemanticSpace = (== 32)
#endif

rawSemanticSignificant :: Bool -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_SIGNIFICANT_BYPASS_MUTANT)
rawSemanticSignificant = id
#else
rawSemanticSignificant _ = True
#endif

rawSourceProblemFinding :: RawInputCommitment -> RawSourceProblem -> Finding
rawSourceProblemFinding inputCommitment problem = case problem of
  RawSnapshotIdentityByteLimitExceeded maximumBytes observed ->
    resource 1 "SOURCE-CLOSURE-IDENTITY-BYTE-LIMIT" "<claimed-snapshot>" maximumBytes observed
  RawEntryLimitExceeded maximumEntries observed ->
    resource 2 "SOURCE-CLOSURE-ENTRY-LIMIT" "<raw-source-closure>" maximumEntries observed
  RawPathByteLimitExceeded ordinal maximumBytes observed ->
    resource 3 "SOURCE-CLOSURE-PATH-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawPathDepthLimitExceeded ordinal maximumDepth observed ->
    resource 4 "SOURCE-CLOSURE-PATH-DEPTH-LIMIT" (rawOrdinalSubject ordinal) maximumDepth observed
  RawPathSegmentByteLimitExceeded ordinal maximumBytes observed ->
    resource 5 "SOURCE-CLOSURE-PATH-SEGMENT-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawModeByteLimitExceeded ordinal maximumBytes observed ->
    resource 6 "SOURCE-CLOSURE-MODE-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawObjectIdentityByteLimitExceeded ordinal maximumBytes observed ->
    resource 7 "SOURCE-CLOSURE-OBJECT-ID-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawBlobByteLimitExceeded ordinal maximumBytes observed ->
    resource 8 "SOURCE-CLOSURE-BLOB-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawAggregateBlobByteLimitExceeded maximumBytes observed ->
    resource 9 "SOURCE-CLOSURE-AGGREGATE-BLOB-BYTE-LIMIT" "<raw-source-closure>" maximumBytes observed
  RawSemanticLineByteLimitExceeded ordinal maximumBytes observed ->
    resource 10 "SOURCE-CLOSURE-SEMANTIC-LINE-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawSnapshotIdentityMalformed observed ->
    malformed 11 "SOURCE-CLOSURE-IDENTITY-GRAMMAR" "<claimed-snapshot>" ("expected exactly 64 lowercase ASCII hexadecimal characters; observed=" <> observed)
  RawSnapshotIdentityMismatch expected observed ->
    malformed 12 "SOURCE-CLOSURE-IDENTITY-MISMATCH" "<claimed-snapshot>" ("expected=" <> expected <> "; observed=" <> observed)
  RawEmptyInventory ->
    malformed 13 "SOURCE-CLOSURE-INVENTORY-EMPTY" "<raw-source-closure>" "raw inventory must contain at least one tracked entry"
  RawPathMalformed ordinal path detail ->
    malformed 14 "SOURCE-CLOSURE-PATH-GRAMMAR" (rawSafePathSubject ordinal path) detail
  RawModeMalformed ordinal observed ->
    malformed 15 "SOURCE-CLOSURE-MODE-GRAMMAR" (rawOrdinalSubject ordinal) ("observed=" <> observed)
  RawObjectIdentityMalformed ordinal observed ->
    malformed 16 "SOURCE-CLOSURE-OBJECT-ID-GRAMMAR" (rawOrdinalSubject ordinal) ("observed=" <> observed)
  RawObjectIdentityMismatch ordinal expected actual ->
    malformed 17 "SOURCE-CLOSURE-OBJECT-ID-MISMATCH" (rawOrdinalSubject ordinal) ("expected=" <> expected <> "; recomputed=" <> actual)
  RawMixedObjectIdentityFormats widths ->
    malformed 18 "SOURCE-CLOSURE-OBJECT-FORMAT-MIXED" "<raw-source-closure>" (Text.pack (show widths))
  RawDuplicatePath path ->
    malformed 19 "SOURCE-CLOSURE-DUPLICATE-PATH" path "path occurs more than once"
  RawEntryOrderInvalid paths ->
    malformed
      20
      "SOURCE-CLOSURE-ENTRY-ORDER"
      "<raw-source-closure>"
      ( "observed-count="
          <> Text.pack (show (length paths))
          <> "; first-two="
          <> Text.pack (show (take 2 paths))
      )
  RawPortableCaseCollision left right ->
    malformed 21 "SOURCE-CLOSURE-PORTABLE-CASE-COLLISION" left ("collides with " <> Text.pack right)
  RawPortablePrefixConflict left right ->
    malformed 22 "SOURCE-CLOSURE-PORTABLE-PREFIX-CONFLICT" left ("conflicts with " <> Text.pack right)
  RawProblemLimitExceeded maximumProblems observed ->
    resource 23 "SOURCE-CLOSURE-PROBLEM-LIMIT" "<raw-source-closure>" maximumProblems observed
 where
  resource locus code subject maximumValue observed =
    rawMappedFinding locus code subject (rawLimitDetail maximumValue observed <> rawCommitmentDetail inputCommitment)
  malformed locus code subject detail = rawMappedFinding locus code subject (detail <> rawCommitmentDetail inputCommitment)

rawLimitDetail :: Int -> Int -> Text
rawLimitDetail maximumValue observed =
  "maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show observed)

rawCommitmentDetail :: RawInputCommitment -> Text
rawCommitmentDetail inputCommitment =
  "; source-closure.input-commitment-kind="
    <> rawCommitmentDetailKind (rawInputCommitmentKind inputCommitment)
    <> "; source-closure.input-commitment-sha256="
    <> rawCommitmentDetailDigest (rawInputCommitmentSha256 inputCommitment)

rawOrdinalSubject :: Int -> FilePath
rawOrdinalSubject ordinal = "<entry-" <> show ordinal <> ">"

rawSafePathSubject :: Int -> FilePath -> FilePath
rawSafePathSubject ordinal path
  | null path = rawOrdinalSubject ordinal
  | PrefixWithin _ <- boundedUtf8FilePathBytes maximumRawPathBytes path = path
  | otherwise = rawOrdinalSubject ordinal

rawSafeClaimedIdentity :: Text -> Text
rawSafeClaimedIdentity value =
  case boundedUtf8TextBytes maximumRawSnapshotIdentityBytes value of
    PrefixWithin _ -> value
    PrefixExceeded _ -> "<over-limit>"

rawSnapshotIdentityByteLimitExceeded, rawEntryLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
rawSnapshotIdentityByteLimitExceeded _ = False
#else
rawSnapshotIdentityByteLimitExceeded observed = observed > maximumRawSnapshotIdentityBytes
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_LIMIT_BYPASS_MUTANT)
rawEntryLimitExceeded _ = False
#else
rawEntryLimitExceeded observed = observed > maximumRawEntries
#endif

rawPathByteLimitExceeded, rawPathDepthLimitExceeded, rawPathSegmentByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_BYTE_LIMIT_BYPASS_MUTANT)
rawPathByteLimitExceeded _ = False
#else
rawPathByteLimitExceeded observed = observed > maximumRawPathBytes
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_DEPTH_LIMIT_BYPASS_MUTANT)
rawPathDepthLimitExceeded _ = False
#else
rawPathDepthLimitExceeded observed = observed > maximumRawPathDepth
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT)
rawPathSegmentByteLimitExceeded _ = False
#else
rawPathSegmentByteLimitExceeded observed = observed > maximumRawPathSegmentBytes
#endif

rawModeByteLimitExceeded, rawObjectIdentityByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_MODE_BYTE_LIMIT_BYPASS_MUTANT)
rawModeByteLimitExceeded _ = False
#else
rawModeByteLimitExceeded observed = observed > maximumRawModeBytes
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_OBJECT_ID_BYTE_LIMIT_BYPASS_MUTANT)
rawObjectIdentityByteLimitExceeded _ = False
#else
rawObjectIdentityByteLimitExceeded observed = observed > maximumRawObjectIdentityBytes
#endif

rawBlobByteLimitExceeded, rawAggregateBlobByteLimitExceeded, rawSemanticLineByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_BLOB_BYTE_LIMIT_BYPASS_MUTANT)
rawBlobByteLimitExceeded _ = False
#else
rawBlobByteLimitExceeded observed = observed > maximumRawBlobBytes
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_AGGREGATE_BLOB_BYTE_LIMIT_BYPASS_MUTANT)
rawAggregateBlobByteLimitExceeded _ = False
#else
rawAggregateBlobByteLimitExceeded observed = observed > maximumRawAggregateBlobBytes
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SEMANTIC_LINE_BYTE_LIMIT_BYPASS_MUTANT)
rawSemanticLineByteLimitExceeded _ = False
#else
rawSemanticLineByteLimitExceeded observed = observed > maximumRawSemanticLineBytes
#endif

rawProblemLimitExceeded, rawResultFindingLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROBLEM_LIMIT_BYPASS_MUTANT)
rawProblemLimitExceeded _ = False
#else
rawProblemLimitExceeded observed = observed > maximumRawProblems
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_RESULT_FINDING_LIMIT_BYPASS_MUTANT)
rawResultFindingLimitExceeded _ = False
#else
rawResultFindingLimitExceeded observed = observed > maximumRawResultFindings
#endif

rawSnapshotIdentityMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_IDENTITY_MATCH_BYPASS_MUTANT)
rawSnapshotIdentityMismatch _ _ = False
#else
rawSnapshotIdentityMismatch observed expected = observed /= expected
#endif

rawDuplicatePathRejected :: Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DUPLICATE_PATH_BYPASS_MUTANT)
rawDuplicatePathRejected = False
#else
rawDuplicatePathRejected = True
#endif

rawEmptyInventoryRejected :: Bool
#if defined(VALIDATION_SOURCE_CLOSURE_EMPTY_INVENTORY_BYPASS_MUTANT)
rawEmptyInventoryRejected = False
#else
rawEmptyInventoryRejected = True
#endif

rawEntryOrderInvalid :: [FilePath] -> [FilePath] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_ORDER_BYPASS_MUTANT)
rawEntryOrderInvalid _ _ = False
#else
rawEntryOrderInvalid observed expected = observed /= expected
#endif

-- | A caller-selected Git executable accepted only through 'mkGitExecutable'.
-- Hiding the constructor prevents a diagnostic path from silently falling back
-- to PATH, but this value is deliberately not candidate evidence: absolute
-- path selection authenticates neither the executable nor its observations.
newtype GitExecutable = GitExecutable FilePath
  deriving (Eq, Ord, Show)

-- | The two independent, NUL-delimited index-visibility observations used
-- during capture.  They are distinct because @git ls-files -v@ exposes
-- assume-unchanged through a lower-case tag, while @git ls-files -t@ exposes
-- skip-worktree through the @S@ tag.
data IndexFlagObservation
  = AssumeUnchangedObservation
  | SkipWorktreeObservation
  deriving (Eq, Ord, Show)

data WorktreeEntryKind
  = WorktreeRegularFile
  | WorktreeSymbolicLink
  | WorktreeDirectory
  | WorktreeOther
  deriving (Eq, Ord, Show)

-- | Marker for a snapshot acquired through this module's exact local Git and
-- worktree capture. The constructor is module-private; no sibling home module
-- can upgrade a caller-authored diagnostic snapshot into candidate evidence.
newtype AcquiredSourceSnapshot = AcquiredSourceSnapshot SourceSnapshot
  deriving (Eq, Show)

acquiredSourceSnapshot :: AcquiredSourceSnapshot -> SourceSnapshot
acquiredSourceSnapshot (AcquiredSourceSnapshot snapshot) = snapshot

#if defined(VALIDATION_SOURCE_CLOSURE_INTERNAL_TEST_ACQUIRE)
-- This constructor exists only when the Cabal-owned direct-source internal
-- Graph oracle compiles the exact home-module tree.  It is absent from the
-- packaged validation-kernel library and cannot cross either public facade.
sourceClosureInternalTestAcquire :: SourceSnapshot -> AcquiredSourceSnapshot
sourceClosureInternalTestAcquire = AcquiredSourceSnapshot
#endif

data WorktreeEntryObservation = WorktreeEntryObservation
  { worktreeObservedKind :: WorktreeEntryKind
  , worktreeObservedExecutable :: Bool
  , worktreeObservedBytes :: ByteString
  , worktreeObservedStatus :: WorktreeStatusFingerprint
  }
  deriving (Eq, Ord, Show)

#if defined(mingw32_HOST_OS)
data WorktreeStatusFingerprint = WorktreeStatusFingerprintUnavailable
  deriving (Eq, Ord, Show)
#else
data WorktreeStatusFingerprint = WorktreeStatusFingerprint
  { statusDevice :: Text
  , statusFileIdentity :: Text
  , statusMode :: Text
  , statusSize :: Text
  , statusModified :: Text
  , statusChanged :: Text
  }
  deriving (Eq, Ord, Show)
#endif

data SnapshotProblem
  = GitExecutableNotAbsolute FilePath
  | CallerSelectedGitDiagnosticOnly FilePath
  | SourceSnapshotAtomicityRequiresExternalObserver
  | RepositoryRootNotAbsolute FilePath
  | RepositoryRootMismatch FilePath FilePath
  | RepositoryHeadUnavailable Int Text
  | InvalidRepositoryHead Text
  | RepositoryHeadChangedDuringCapture Text Text
  | GitProcessFailure [String] Int Text
  | GitProcessIoFailure [String] Text
  | InternalGitCaptureEnvelopeUnavailable Int Int
  | InternalTrackedReadEnvelopeUnavailable Int Int
  | InternalAuthoredTraversalEnvelopeUnavailable Int Int Int
  | EmptyIndex
  | MissingNulTerminator
  | MalformedIndexRecord Int Text
  | UnsupportedIndexMode Int Text
  | NonStageZeroEntry Int Text
  | InvalidObjectId Int Text
  | InvalidTrackedPath Int Text
  | DuplicateTrackedPath FilePath
  | MixedObjectIdFormats [Int]
  | UnsupportedRepositoryObjectFormat Text
  | IndexObjectFormatMismatch GitObjectFormat [(FilePath, Text)]
  | RepositoryObjectFormatChanged GitObjectFormat GitObjectFormat
  | UnsupportedBlobObjectIdFormat Text
  | LoadedBlobObjectIdMismatch Text Text
  | MissingLoadedBlob Text
  | MissingIndexFlagNulTerminator IndexFlagObservation
  | MalformedIndexFlagRecord IndexFlagObservation Int Text
  | DuplicateIndexFlagPath IndexFlagObservation FilePath
  | IndexFlagInventoryMismatch IndexFlagObservation [FilePath] [FilePath]
  | AssumeUnchangedTrackedPaths [FilePath]
  | SkipWorktreeTrackedPaths [FilePath]
  | TrackedWorktreePathMissing FilePath
  | TrackedWorktreeExecutableModeUnavailable FilePath
  | TrackedWorktreeKindMismatch FilePath IndexMode WorktreeEntryKind
  | TrackedWorktreeExecutableMismatch FilePath Bool Bool
  | TrackedWorktreeBytesMismatch FilePath
  | TrackedWorktreeEntryRace FilePath
  | TrackedWorktreeIoFailure FilePath Text
  | InvalidWorktreeSymlinkTarget FilePath
  | TrackedWorktreeChangedDuringCapture [FilePath]
  | AuthoredRootInventoryIoFailure FilePath Text
  | AuthoredRootDescriptorWalkUnavailable FilePath
  | AuthoredRootDirectoryChangedDuringWalk FilePath
  | AuthoredRootEntryKindChanged FilePath WorktreeEntryKind WorktreeEntryKind
  | AuthoredRootUnknownEntryType FilePath
  | InvalidAuthoredRootPath FilePath
  | ContainedStateRootKindMismatch FilePath WorktreeEntryKind
  | ContainedStateRootRequiresExternalObserver FilePath
  | AuthoredRootAncestorKindMismatch FilePath WorktreeEntryKind
  | UnexpectedAuthoredRootMaterial [FilePath]
  | AuthoredRootChangedDuringCapture [FilePath] [FilePath] [FilePath]
  | TrackedWorktreeDivergence [FilePath]
  | StagedIndexDivergence [FilePath]
  | UntrackedNonIgnoredPaths [FilePath]
  | IndexChangedDuringCapture
  | InvalidWorkspacePath Text
  deriving (Eq, Ord, Show)

data SourceDebtId
  = SourceTools
  | SourceDhall
  | SourceProto
  | SourceUi
  | SourcePulumi
  | SourceTest
  | SourceProbe
  | SourcePb
  | SourceVendor
  deriving (Eq, Ord, Enum, Bounded, Show)

-- | Every path has exactly one primary class.  Evidence which may overlap --
-- for example, executable mode plus a shebang -- is represented by 'SourceFacet'
-- rather than by assigning a second class.
data SourceClass
  = HaskellSource
  | DocumentationInput
  | ProjectDeclaration
  | RegisteredLegacy SourceDebtId
  | UnregisteredBehavioralSource
  deriving (Eq, Ord, Show)

data SourceFacet
  = ExecutableModeFacet
  | ShebangFacet Text
  | SymbolicLinkFacet Text
  | BinaryContentFacet
  | ForeignSourceSignatureFacet Text
  deriving (Eq, Ord, Show)

data ClassifiedPath = ClassifiedPath
  { classifiedEntry :: TrackedEntry
  , classifiedAs :: SourceClass
  , classificationFacets :: [SourceFacet]
  , classificationReasons :: [Text]
  }
  deriving (Eq, Ord, Show)

-- | Opaque classified snapshot.  This is positional so the exported ordinary
-- projection functions below cannot be used to record-update an admission,
-- path partition, problem set, or snapshot identity around the capture
-- boundary.
data SourceClosure
  = SourceClosure
      Text
      [ClassifiedPath]
      (Map SourceDebtId [FilePath])
      [SnapshotProblem]
      CheckResult
  deriving (Eq, Show)

closureSnapshotIdentity :: SourceClosure -> Text
closureSnapshotIdentity (SourceClosure value _ _ _ _) = value

closurePaths :: SourceClosure -> [ClassifiedPath]
closurePaths (SourceClosure _ value _ _ _) = value

closureRegisteredDebt :: SourceClosure -> Map SourceDebtId [FilePath]
closureRegisteredDebt (SourceClosure _ _ value _ _) = value

closureProblems :: SourceClosure -> [SnapshotProblem]
closureProblems (SourceClosure _ _ _ value _) = value

closurePbBootstrapDiagnostic :: SourceClosure -> CheckResult
closurePbBootstrapDiagnostic (SourceClosure _ _ _ _ value) = value

mkGitExecutable :: FilePath -> Either SnapshotProblem GitExecutable
mkGitExecutable executable
  | isAbsolute executable = Right (GitExecutable executable)
  | otherwise = Left (GitExecutableNotAbsolute executable)

-- | Capture the exact local authored-source snapshot used by the gate. The
-- worktree may be dirty: tracked modifications and non-ignored untracked files
-- are part of the candidate. Every file is read through the race-detecting
-- local reader, and the complete snapshot is captured again after the gate by
-- the dispatcher.
loadGitSnapshot :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] AcquiredSourceSnapshot)
loadGitSnapshot git root = fmap (fmap AcquiredSourceSnapshot) (loadGitSnapshotDiagnostic git root)

-- | Capture the same local snapshot without the package-hidden candidate
-- wrapper. This seam exists for component diagnostics and independently
-- authored oracle cases.
loadGitSnapshotDiagnostic :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadGitSnapshotDiagnostic _ root | not (isAbsolute root) = pure (Left [RepositoryRootNotAbsolute root])
loadGitSnapshotDiagnostic git root = loadLocalSourceSnapshot git root

loadLocalSourceSnapshot :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadLocalSourceSnapshot git root = do
  topResult <- runGit git root ["rev-parse", "--show-toplevel"] ByteString.empty
  case topResult of
    Left problem -> pure (Left [problem])
    Right topBytes ->
      case decodeOneLine topBytes of
        Left detail -> pure (Left [GitProcessIoFailure ["rev-parse", "--show-toplevel"] detail])
        Right top
          | canonicalPath top /= canonicalPath root -> pure (Left [RepositoryRootMismatch root top])
          | otherwise -> do
              pathsResult <-
                runGit
                  git
                  root
                  ["ls-files", "--cached", "--others", "--exclude-standard", "-z"]
                  ByteString.empty
              case pathsResult >>= decodeNulPathList of
                Left problem -> pure (Left [problem])
                Right paths -> do
                  captured <- traverse (captureLocalEntry root) (sort paths)
                  let problems = [problem | Left problem <- captured]
                      entries = [entry | Right entry <- captured]
                  pure $
                    if null problems
                      then
                        Right
                          SourceSnapshot
                            { snapshotRoot = root
                            , snapshotIdentity = computeSourceSnapshotIdentity GitObjectSha256 entries
                            , snapshotEntries = entries
                            }
                      else Left problems

captureLocalEntry :: FilePath -> FilePath -> IO (Either SnapshotProblem TrackedEntry)
captureLocalEntry root path = do
  observed <- readWorktreeEntry root path (root </> path)
  pure $ do
    value <- observed
    mode <- case worktreeObservedKind value of
      WorktreeRegularFile ->
        Right (if worktreeObservedExecutable value then ExecutableFile else RegularFile)
      WorktreeSymbolicLink -> Right SymbolicLink
      kind -> Left (AuthoredRootUnknownEntryType (path <> ":" <> show kind))
    let bytes = worktreeObservedBytes value
    Right
      TrackedEntry
        { trackedIndex =
            IndexEntry
              { indexPath = path
              , indexMode = mode
              , indexObjectId = computeBlobObjectId GitObjectSha256 bytes
              }
        , trackedBytes = bytes
        }

-- | Compare storage-format values for diagnostic negative controls.
objectFormatBoundaryProblems :: GitObjectFormat -> GitObjectFormat -> [SnapshotProblem]
objectFormatBoundaryProblems before after =
  [RepositoryObjectFormatChanged before after | before /= after]

-- | Compare the exact commit identities observed at the capture boundary.
-- This is a diagnostic race detector, not proof that HEAD could not change and
-- change back between sequential observations.
repositoryHeadBoundaryProblemsDiagnostic :: Text -> Text -> [SnapshotProblem]
repositoryHeadBoundaryProblemsDiagnostic before after =
  [RepositoryHeadChangedDuringCapture before after | before /= after]

-- | Compare complete canonical stage-zero entries.  In particular, retaining
-- the same path while changing only its object id or mode is a boundary change.
finalIndexBoundaryProblemsDiagnostic :: [IndexEntry] -> [IndexEntry] -> [SnapshotProblem]
finalIndexBoundaryProblemsDiagnostic expected actual =
  [ IndexChangedDuringCapture
  | finalIndexCountChanged expected actual
      || finalIndexPathInventoryChanged expected actual
      || finalIndexOrderChanged expected actual
      || finalIndexModeChanged expected actual
      || finalIndexObjectChanged expected actual
  ]

finalIndexCountChanged :: [IndexEntry] -> [IndexEntry] -> Bool
finalIndexCountChanged expected actual = length expected /= length actual

finalIndexPathInventoryChanged :: [IndexEntry] -> [IndexEntry] -> Bool
finalIndexPathInventoryChanged expected actual =
  sort (map indexPath expected) /= sort (map indexPath actual)

finalIndexOrderChanged :: [IndexEntry] -> [IndexEntry] -> Bool
finalIndexOrderChanged expected actual =
  let expectedPaths = map indexPath expected
      actualPaths = map indexPath actual
   in sort expectedPaths == sort actualPaths && expectedPaths /= actualPaths

finalIndexModeChanged :: [IndexEntry] -> [IndexEntry] -> Bool
finalIndexModeChanged expected actual =
  map indexPath expected == map indexPath actual
    && map indexMode expected /= map indexMode actual

finalIndexObjectChanged :: [IndexEntry] -> [IndexEntry] -> Bool
finalIndexObjectChanged expected actual =
  map indexPath expected == map indexPath actual
    && map indexObjectId expected /= map indexObjectId actual

readWorktreeEntry :: FilePath -> FilePath -> FilePath -> IO (Either SnapshotProblem WorktreeEntryObservation)
#if defined(mingw32_HOST_OS)
readWorktreeEntry _root path _absolute = pure (Left (TrackedWorktreeExecutableModeUnavailable path))
#else
readWorktreeEntry root path absolute = do
  initialResult <- try (Posix.getSymbolicLinkStatus absolute) :: IO (Either IOException Posix.FileStatus)
  case initialResult of
    Left problem
      | isDoesNotExistError problem -> pure (Left (TrackedWorktreePathMissing path))
      | otherwise -> pure (Left (TrackedWorktreeIoFailure path (Text.pack (displayException problem))))
    Right before -> do
      observedResult <-
        try (readPresentWorktreeEntry root path absolute before)
          :: IO (Either IOException (Either SnapshotProblem WorktreeEntryObservation))
      pure $ case observedResult of
        Left problem
          | isDoesNotExistError problem -> Left (TrackedWorktreeEntryRace path)
          | otherwise -> Left (TrackedWorktreeIoFailure path (Text.pack (displayException problem)))
        Right result -> result

readPresentWorktreeEntry
  :: FilePath
  -> FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readPresentWorktreeEntry root path absolute before
  | Posix.isSymbolicLink before = readWorktreeSymbolicLink path absolute before
  | Posix.isRegularFile before = readWorktreeRegularFile root path absolute before
  | otherwise = readWorktreeNonFile path absolute before

readWorktreeSymbolicLink
  :: FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeSymbolicLink path absolute before = do
  target <- Posix.readSymbolicLink absolute
  after <- Posix.getSymbolicLinkStatus absolute
  pure $
    if not (Posix.isSymbolicLink after) || statusFingerprint before /= statusFingerprint after
      then Left (TrackedWorktreeEntryRace path)
      else case encodeFilesystemPath target of
        Nothing -> Left (InvalidWorktreeSymlinkTarget path)
        Just bytes ->
          Right
            WorktreeEntryObservation
              { worktreeObservedKind = WorktreeSymbolicLink
              , worktreeObservedExecutable = False
              , worktreeObservedBytes = bytes
              , worktreeObservedStatus = statusFingerprint after
              }

readWorktreeRegularFile
  :: FilePath
  -> FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeRegularFile root path absolute before =
  withTrackedParentDirectoryFd root path $ \parentFd leaf ->
    bracket
      (PosixIO.openFdAt (Just parentFd) leaf PosixIO.ReadOnly regularReadFlags)
      PosixIO.closeFd
      (\fd -> do
          opened <- Posix.getFdStatus fd
          if not (Posix.isRegularFile opened) || statusFingerprint opened /= statusFingerprint before
            then pure (Left (TrackedWorktreeEntryRace path))
            else do
              bytes <- readStrictFd fd
              afterFd <- Posix.getFdStatus fd
              afterPath <- Posix.getSymbolicLinkStatus absolute
              let expectedStatus = statusFingerprint before
                  stable =
                    Posix.isRegularFile afterFd
                      && Posix.isRegularFile afterPath
                      && statusFingerprint opened == expectedStatus
                      && statusFingerprint afterFd == expectedStatus
                      && statusFingerprint afterPath == expectedStatus
              pure $
                if not stable
                  then Left (TrackedWorktreeEntryRace path)
                  else
                    Right
                      WorktreeEntryObservation
                        { worktreeObservedKind = WorktreeRegularFile
                        , worktreeObservedExecutable = rawExecutable afterFd
                        , worktreeObservedBytes = bytes
                        , worktreeObservedStatus = statusFingerprint afterFd
                        }
      )

withTrackedParentDirectoryFd
  :: FilePath
  -> FilePath
  -> (Fd -> FilePath -> IO value)
  -> IO value
withTrackedParentDirectoryFd root path action =
  case reverse (map Text.unpack (Text.splitOn "/" (Text.pack path))) of
    [] -> ioError (userError "tracked path has no final component")
    leaf : reversedParents ->
      bracket
        (PosixIO.openFd root PosixIO.ReadOnly directoryReadFlags)
        PosixIO.closeFd
        (\rootFd -> descend rootFd (reverse reversedParents) leaf)
 where
  descend parentFd [] leaf = action parentFd leaf
  descend parentFd (component : rest) leaf =
    bracket
      (PosixIO.openFdAt (Just parentFd) component PosixIO.ReadOnly directoryReadFlags)
      PosixIO.closeFd
      (\childFd -> descend childFd rest leaf)

directoryReadFlags :: PosixIO.OpenFileFlags
directoryReadFlags =
  PosixIO.defaultFileFlags
    { PosixIO.cloexec = True
    , PosixIO.directory = True
    , PosixIO.nofollow = True
    , PosixIO.nonBlock = True
    }

regularReadFlags :: PosixIO.OpenFileFlags
regularReadFlags =
  PosixIO.defaultFileFlags
    { PosixIO.cloexec = True
    , PosixIO.nofollow = True
    , PosixIO.nonBlock = True
    }

readStrictFd :: Fd -> IO ByteString
readStrictFd fd =
  bracket (duplicateFdHandle fd) hClose (go [])
 where
  go chunks handle = do
    chunk <- ByteString.hGetSome handle (64 * 1024)
    if ByteString.null chunk
      then pure (ByteString.concat (reverse chunks))
      else go (chunk : chunks) handle

duplicateFdHandle :: Fd -> IO Handle
duplicateFdHandle fd = do
  duplicate <- PosixIO.dup fd
  PosixIO.fdToHandle duplicate `onException` PosixIO.closeFd duplicate

readWorktreeNonFile
  :: FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeNonFile path absolute before = do
  after <- Posix.getSymbolicLinkStatus absolute
  let beforeKind = worktreeKind before
  pure $
    if worktreeKind after /= beforeKind || statusFingerprint before /= statusFingerprint after
      then Left (TrackedWorktreeEntryRace path)
      else
        Right
          WorktreeEntryObservation
            { worktreeObservedKind = beforeKind
            , worktreeObservedExecutable = False
            , worktreeObservedBytes = ByteString.empty
            , worktreeObservedStatus = statusFingerprint after
            }

worktreeKind :: Posix.FileStatus -> WorktreeEntryKind
worktreeKind status
  | Posix.isRegularFile status = WorktreeRegularFile
  | Posix.isSymbolicLink status = WorktreeSymbolicLink
  | Posix.isDirectory status = WorktreeDirectory
  | otherwise = WorktreeOther

rawExecutable :: Posix.FileStatus -> Bool
rawExecutable status =
  combineRawExecutableBitsDiagnostic
    (hasModeBit Posix.ownerExecuteMode)
    (hasModeBit Posix.groupExecuteMode)
    (hasModeBit Posix.otherExecuteMode)
 where
  hasModeBit bit =
    Posix.fileMode status `Posix.intersectFileModes` bit
      /= Posix.nullFileMode
#endif

-- | Partial pure diagnostic for the raw executable-bit fold used by POSIX
-- capture. It carries no path, bytes, or capture authority.
combineRawExecutableBitsDiagnostic :: Bool -> Bool -> Bool -> Bool
combineRawExecutableBitsDiagnostic owner groupBit other =
  owner || groupBit || other

#if !defined(mingw32_HOST_OS)
statusFingerprint :: Posix.FileStatus -> WorktreeStatusFingerprint
statusFingerprint status =
  WorktreeStatusFingerprint
    { statusDevice = renderStatusField (Posix.deviceID status)
    , statusFileIdentity = renderStatusField (Posix.fileID status)
    , statusMode = renderStatusField (Posix.fileMode status)
    , statusSize = renderStatusField (Posix.fileSize status)
    , statusModified = renderStatusField (Posix.modificationTimeHiRes status)
    , statusChanged = renderStatusField (Posix.statusChangeTimeHiRes status)
    }

renderStatusField :: Show value => value -> Text
renderStatusField = Text.pack . show
#endif

inventoryAuthoredPaths :: FilePath -> IO (Either [SnapshotProblem] (Map FilePath WorktreeEntryKind))
inventoryAuthoredPaths root = case internalAuthoredTraversalEnvelopeProblem of
  problem@InternalAuthoredTraversalEnvelopeUnavailable {} -> pure (Left [problem])
  _ -> inventoryAuthoredPathsUnchecked root

inventoryAuthoredPathsUnchecked :: FilePath -> IO (Either [SnapshotProblem] (Map FilePath WorktreeEntryKind))
#if defined(mingw32_HOST_OS)
inventoryAuthoredPathsUnchecked root = pure (Left [AuthoredRootDescriptorWalkUnavailable root])
#else
inventoryAuthoredPathsUnchecked root = do
  walked <-
    catchAuthoredInventoryIo "." $
      withAbsoluteDirectoryFdNoFollow root
        (\rootFd -> do
            opened <- Posix.getFdStatus rootFd
            contents <- walkAuthoredDirectoryFd rootFd ""
            reboundResult <-
              tryIOError $
                withAbsoluteDirectoryFdNoFollow root Posix.getFdStatus
            pure $ case reboundResult of
              Left _ -> Left [AuthoredRootDirectoryChangedDuringWalk "."]
              Right rebound
                | not (sameDirectoryIdentity opened rebound) ->
                    Left [AuthoredRootDirectoryChangedDuringWalk "."]
                | otherwise -> contents
        )
  pure (fmap Map.fromList walked)

withAbsoluteDirectoryFdNoFollow :: FilePath -> (Fd -> IO value) -> IO value
withAbsoluteDirectoryFdNoFollow absolute action =
  case absoluteDirectoryComponents absolute of
    Nothing -> ioError (userError "authored-root absolute path has an unsafe component")
    Just components ->
      bracket
        (PosixIO.openFd "/" PosixIO.ReadOnly directoryReadFlags)
        PosixIO.closeFd
        (\rootFd -> descend rootFd components)
 where
  descend directoryFd [] = action directoryFd
  descend directoryFd (component : rest) =
    bracket
      ( PosixIOBytes.openFdAt
          (Just directoryFd)
          (TextEncoding.encodeUtf8 (Text.pack component))
          PosixIOBytes.ReadOnly
          directoryReadFlags
      )
      PosixIO.closeFd
      (\childFd -> descend childFd rest)

absoluteDirectoryComponents :: FilePath -> Maybe [FilePath]
absoluteDirectoryComponents path =
  case Text.pack (dropTrailingPathSeparator path) of
    "/" -> Just []
    value -> case Text.splitOn "/" value of
      "" : components
        | all validComponent components -> Just (map Text.unpack components)
      _ -> Nothing
 where
  validComponent component =
    not (Text.null component)
      && component /= "."
      && component /= ".."
      && Text.all (not . surrogateCodePoint) component

walkAuthoredDirectoryFd
  :: Fd
  -> FilePath
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
walkAuthoredDirectoryFd directoryFd relativeDirectory = do
  let subject = if null relativeDirectory then "." else relativeDirectory
  catchAuthoredInventoryIo subject $ do
    before <- Posix.getFdStatus directoryFd
    entries <- readAuthoredDirectoryEntries directoryFd
    children <- forM (sortOn fst entries) (walkAuthoredChildFd directoryFd relativeDirectory)
    after <- Posix.getFdStatus directoryFd
    let directoryProblems =
          [ AuthoredRootDirectoryChangedDuringWalk subject
          | not (Posix.isDirectory before)
              || not (Posix.isDirectory after)
              || statusFingerprint before /= statusFingerprint after
          ]
    pure $ case combineInventoryResults children of
      Left problems -> Left (problems <> directoryProblems)
      Right paths
        | null directoryProblems -> Right paths
        | otherwise -> Left directoryProblems

readAuthoredDirectoryEntries
  :: Fd
  -> IO [(ByteString, PosixDirectoryInternals.DirType)]
readAuthoredDirectoryEntries directoryFd =
  bracket
    (PosixIO.dup directoryFd >>= PosixDirectoryFd.unsafeOpenDirStreamFd)
    PosixDirectory.closeDirStream
    (go [])
 where
  go entries stream = do
    next <-
      PosixDirectoryInternals.readDirStreamWith
        (\entry -> do
            namePointer <- PosixDirectoryInternals.dirEntName entry
            name <- ByteString.packCString namePointer
            entryType <- PosixDirectoryInternals.dirEntType entry
            pure (name, entryType)
        )
        stream
    case next of
      Nothing -> pure (reverse entries)
      Just entry@(name, _)
        | name == "." || name == ".." -> go entries stream
        | otherwise -> go (entry : entries) stream

walkAuthoredChildFd
  :: Fd
  -> FilePath
  -> (ByteString, PosixDirectoryInternals.DirType)
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
walkAuthoredChildFd parentFd parent (rawName, entryType) =
  case TextEncoding.decodeUtf8' rawName of
    Left _ -> pure (Left [InvalidAuthoredRootPath (displayAuthoredRawPath parent rawName)])
    Right decodedName -> do
      let name = Text.unpack decodedName
          relative = if null parent then name else parent <> "/" <> name
      if null parent && name `elem` excludedRepositoryControlRoots
        then pure (Right [])
        else
          if null parent && name `elem` containedStateRoots
            then pure (Left (containedStateRootProblems relative entryType))
            else
              if not (validFilesystemPath relative)
                then pure (Left [InvalidAuthoredRootPath relative])
                else classifyAuthoredChildFd parentFd rawName relative entryType

classifyAuthoredChildFd
  :: Fd
  -> ByteString
  -> FilePath
  -> PosixDirectoryInternals.DirType
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
classifyAuthoredChildFd parentFd rawName relative entryType
  | PosixDirectoryInternals.isRegularFileType entryType =
      observeAuthoredRegularFd parentFd rawName relative
  | PosixDirectoryInternals.isDirectoryType entryType =
      observeAuthoredDirectoryFd parentFd rawName relative
  | PosixDirectoryInternals.isSymbolicLinkType entryType =
      pure (Right [(relative, WorktreeSymbolicLink)])
  | authoredSpecialType entryType =
      pure (Right [(relative, WorktreeOther)])
  | otherwise =
      pure (Left [AuthoredRootUnknownEntryType relative])

observeAuthoredRegularFd
  :: Fd
  -> ByteString
  -> FilePath
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
observeAuthoredRegularFd parentFd rawName relative =
  catchAuthoredInventoryIo relative $
    bracket
      (PosixIOBytes.openFdAt (Just parentFd) rawName PosixIOBytes.ReadOnly regularReadFlags)
      PosixIO.closeFd
      (\entryFd -> do
          status <- Posix.getFdStatus entryFd
          let actual = worktreeKind status
          pure $
            if actual == WorktreeRegularFile
              then Right [(relative, WorktreeRegularFile)]
              else Left [AuthoredRootEntryKindChanged relative WorktreeRegularFile actual]
      )

observeAuthoredDirectoryFd
  :: Fd
  -> ByteString
  -> FilePath
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
observeAuthoredDirectoryFd parentFd rawName relative =
  catchAuthoredInventoryIo relative $
    bracket
      (PosixIOBytes.openFdAt (Just parentFd) rawName PosixIOBytes.ReadOnly directoryReadFlags)
      PosixIO.closeFd
      (\directoryFd -> do
          opened <- Posix.getFdStatus directoryFd
          if not (Posix.isDirectory opened)
            then
              pure
                ( Left
                    [ AuthoredRootEntryKindChanged
                        relative
                        WorktreeDirectory
                        (worktreeKind opened)
                    ]
                )
            else do
              contents <- walkAuthoredDirectoryFd directoryFd relative
              reboundResult <-
                tryIOError $
                  bracket
                    (PosixIOBytes.openFdAt (Just parentFd) rawName PosixIOBytes.ReadOnly directoryReadFlags)
                    PosixIO.closeFd
                    Posix.getFdStatus
              pure $ case reboundResult of
                Left _ -> Left [AuthoredRootDirectoryChangedDuringWalk relative]
                Right rebound
                  | not (sameDirectoryIdentity opened rebound) ->
                      Left [AuthoredRootDirectoryChangedDuringWalk relative]
                  | otherwise -> fmap ((relative, WorktreeDirectory) :) contents
      )

authoredSpecialType :: PosixDirectoryInternals.DirType -> Bool
authoredSpecialType entryType =
  or
    [ PosixDirectoryInternals.isBlockDeviceType entryType
    , PosixDirectoryInternals.isCharacterDeviceType entryType
    , PosixDirectoryInternals.isNamedPipeType entryType
    , PosixDirectoryInternals.isSocketType entryType
    , PosixDirectoryInternals.isWhiteoutType entryType
    ]

sameDirectoryIdentity :: Posix.FileStatus -> Posix.FileStatus -> Bool
sameDirectoryIdentity left right =
  Posix.isDirectory left
    && Posix.isDirectory right
    && Posix.deviceID left == Posix.deviceID right
    && Posix.fileID left == Posix.fileID right

catchAuthoredInventoryIo
  :: FilePath
  -> IO (Either [SnapshotProblem] value)
  -> IO (Either [SnapshotProblem] value)
catchAuthoredInventoryIo subject action = do
  result <- tryIOError action
  pure $ case result of
    Left problem -> Left [AuthoredRootInventoryIoFailure subject (Text.pack (displayException problem))]
    Right value -> value

displayAuthoredRawPath :: FilePath -> ByteString -> FilePath
displayAuthoredRawPath parent rawName =
  let rendered = Text.unpack (TextEncoding.decodeUtf8With TextError.lenientDecode rawName)
   in if null parent then rendered else parent <> "/" <> rendered
#endif

#if !defined(mingw32_HOST_OS)
combineInventoryResults
  :: [Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)]]
  -> Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)]
combineInventoryResults results =
  let problems = concat [items | Left items <- results]
      paths = concat [items | Right items <- results]
   in if null problems then Right paths else Left problems

excludedRepositoryControlRoots :: [FilePath]
excludedRepositoryControlRoots = [".git"]

containedStateRoots :: [FilePath]
containedStateRoots = [".build", ".data", ".test_data"]

containedStateRootProblems
  :: FilePath
  -> PosixDirectoryInternals.DirType
  -> [SnapshotProblem]
containedStateRootProblems path entryType
  | PosixDirectoryInternals.isDirectoryType entryType = directoryProblems
  | PosixDirectoryInternals.isRegularFileType entryType = kindProblems WorktreeRegularFile
  | PosixDirectoryInternals.isSymbolicLinkType entryType = kindProblems WorktreeSymbolicLink
 | authoredSpecialType entryType = kindProblems WorktreeOther
  | otherwise = [AuthoredRootUnknownEntryType path]
 where
  directoryProblems = [ContainedStateRootRequiresExternalObserver path]
  kindProblems kind = [ContainedStateRootKindMismatch path kind]
#endif

validFilesystemPath :: FilePath -> Bool
validFilesystemPath path =
  safeTrackedPath path
    && all (not . surrogateCodePoint) path
    && all safeFilesystemCharacter path

safeFilesystemCharacter :: Char -> Bool
safeFilesystemCharacter character =
  character >= ' '
    && character /= '\DEL'
    && character /= '\\'

#if !defined(mingw32_HOST_OS)
encodeFilesystemPath :: FilePath -> Maybe ByteString
encodeFilesystemPath path
  | all (not . surrogateCodePoint) path = Just (TextEncoding.encodeUtf8 (Text.pack path))
  | otherwise = Nothing
#endif

surrogateCodePoint :: Char -> Bool
surrogateCodePoint character = character >= '\xD800' && character <= '\xDFFF'

-- | Partial Git-reported workspace diagnostic. This observes tracked, staged,
-- and non-ignored-untracked summaries only; it is not discovery completeness
-- and cannot be candidate evidence. Full capture additionally performs
-- descriptor-relative no-follow authored-root and contained-state observation.
checkGitReportedWorkspaceDiagnostic :: GitExecutable -> FilePath -> IO [SnapshotProblem]
checkGitReportedWorkspaceDiagnostic _ root | not (isAbsolute root) = pure [RepositoryRootNotAbsolute root]
checkGitReportedWorkspaceDiagnostic git root = case internalGitCaptureEnvelopeProblem of
  problem@InternalGitCaptureEnvelopeUnavailable {} -> pure [problem]
  _ -> checkGitReportedWorkspaceDiagnosticUnchecked git root

checkGitReportedWorkspaceDiagnosticUnchecked :: GitExecutable -> FilePath -> IO [SnapshotProblem]
checkGitReportedWorkspaceDiagnosticUnchecked git root = do
  headResult <- observeRepositoryHead git root
  changedResult <-
    runGit
      git
      root
      ["diff-files", "--name-only", "--ignore-submodules=none", "-z", "--"]
      ByteString.empty
  stagedResult <- case headResult of
    Left problem -> pure (Left problem)
    Right headCommit ->
      runGit
        git
        root
        [ "diff-index"
        , "--cached"
        , "--name-only"
        , "--no-renames"
        , "--no-ext-diff"
        , "--ignore-submodules=none"
        , "-z"
        , Text.unpack headCommit
        , "--"
        ]
        ByteString.empty
  untrackedResult <-
    runGit
      git
      root
      ["ls-files", "--others", "--exclude-standard", "-z"]
      ByteString.empty
  pure
    ( pathResult TrackedWorktreeDivergence changedResult
        <> pathResult StagedIndexDivergence stagedResult
        <> pathResult UntrackedNonIgnoredPaths untrackedResult
    )
  where
    pathResult constructor result = case result of
      Left problem -> [problem]
      Right bytes -> case decodeNulPathList bytes of
        Left problem -> [problem]
        Right [] -> []
        Right paths -> [constructor paths]

observeRepositoryHead :: GitExecutable -> FilePath -> IO (Either SnapshotProblem Text)
observeRepositoryHead git root = do
  result <-
    runGit
      git
      root
      ["rev-parse", "--verify", "--end-of-options", "HEAD^{commit}"]
      ByteString.empty
  pure $ case result of
    Left (GitProcessFailure _ status detail) -> Left (RepositoryHeadUnavailable status detail)
    Left problem -> Left problem
    Right bytes -> case decodeOneLine bytes of
      Left detail -> Left (InvalidRepositoryHead detail)
      Right value
        | validObjectId (Text.pack value) -> Right (Text.pack value)
        | otherwise -> Left (InvalidRepositoryHead (Text.pack value))

-- | Independently bind bytes returned by Git to the object name from the
-- index.  Git object IDs hash the framed object, not the payload alone.  The
-- object-id width selects the repository object format; no Git-reported format
-- declaration is trusted by this check.
verifyBlobObjectId :: Text -> ByteString -> Either SnapshotProblem ()
verifyBlobObjectId expected bytes = do
  objectFormat <- case Text.length expected of
    40
      | Text.all asciiLowerHex expected -> Right GitObjectSha1
    64
      | Text.all asciiLowerHex expected -> Right GitObjectSha256
    _ -> Left (UnsupportedBlobObjectIdFormat expected)
  let actual = computeBlobObjectId objectFormat bytes
  if actual == expected
    then Right ()
    else Left (LoadedBlobObjectIdMismatch expected actual)

computeBlobObjectId :: GitObjectFormat -> ByteString -> Text
computeBlobObjectId objectFormat bytes = case objectFormat of
  GitObjectSha1 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA1))
  GitObjectSha256 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA256))
 where
  framed =
    "blob "
      <> ByteString8.pack (show (ByteString.length bytes))
      <> "\0"
      <> bytes

-- | The candidate-facing identity is always SHA-256, even when the repository
-- stores Git objects with SHA-1. The v2 manifest binds each entry twice: to its
-- verified Git object name and, independently, to SHA-256 of its exact payload.
-- This is the explicit conversion boundary between Git storage identity and
-- the evidence schema; a caller-supplied object name cannot stand in for bytes.
computeSourceSnapshotIdentity :: GitObjectFormat -> [TrackedEntry] -> Text
computeSourceSnapshotIdentity objectFormat entries =
  hex (SHA256.finalize finalContext)
 where
  ordered = rawSnapshotMemberOrder (sortOn (indexPath . trackedIndex) entries)
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_DIGEST_DOMAIN_DROP_MUTANT)
  domainContext = SHA256.init
#else
  domainContext = SHA256.update SHA256.init "amoebius-source-snapshot-v2\0"
#endif
  formatContext = updateSnapshotFormat domainContext objectFormat
  formatSeparatorContext = rawSnapshotFormatSeparator formatContext
  finalContext = foldl' updateSnapshotMember formatSeparatorContext ordered

updateSnapshotFormat :: SHA256.Ctx -> GitObjectFormat -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_FORMAT_COMMITMENT_MUTANT)
updateSnapshotFormat context _ = context
#else
updateSnapshotFormat context = SHA256.update context . TextEncoding.encodeUtf8 . renderGitObjectFormat
#endif

updateSnapshotMember :: SHA256.Ctx -> TrackedEntry -> SHA256.Ctx
updateSnapshotMember initialContext trackedEntry = rawSnapshotPathSeparator pathContext
 where
  indexEntry = trackedIndex trackedEntry
  modeContext = SHA256.update initialContext (TextEncoding.encodeUtf8 (snapshotModeCommitment indexEntry))
  modeSeparatorContext = rawSnapshotModeSeparator modeContext
  objectContext = SHA256.update modeSeparatorContext (TextEncoding.encodeUtf8 (snapshotObjectCommitment indexEntry))
  objectSeparatorContext = rawSnapshotObjectSeparator objectContext
  blobContext = SHA256.update objectSeparatorContext (TextEncoding.encodeUtf8 (snapshotBlobByteCommitment trackedEntry))
  blobSeparatorContext = rawSnapshotBlobSeparator blobContext
  pathContext = SHA256.update blobSeparatorContext (TextEncoding.encodeUtf8 (snapshotPathCommitment indexEntry))

rawSnapshotMemberOrder :: [TrackedEntry] -> [TrackedEntry]
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_MEMBER_ORDER_MUTANT)
rawSnapshotMemberOrder = reverse
#else
rawSnapshotMemberOrder = id
#endif

rawSnapshotFormatSeparator, rawSnapshotModeSeparator, rawSnapshotObjectSeparator, rawSnapshotBlobSeparator, rawSnapshotPathSeparator :: SHA256.Ctx -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_FORMAT_SEPARATOR_DROP_MUTANT)
rawSnapshotFormatSeparator = id
#else
rawSnapshotFormatSeparator context = SHA256.update context "\0"
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_MODE_SEPARATOR_DROP_MUTANT)
rawSnapshotModeSeparator = id
#else
rawSnapshotModeSeparator context = SHA256.update context "\0"
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_OBJECT_SEPARATOR_DROP_MUTANT)
rawSnapshotObjectSeparator = id
#else
rawSnapshotObjectSeparator context = SHA256.update context "\0"
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_BLOB_SEPARATOR_DROP_MUTANT)
rawSnapshotBlobSeparator = id
#else
rawSnapshotBlobSeparator context = SHA256.update context "\0"
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_PATH_SEPARATOR_DROP_MUTANT)
rawSnapshotPathSeparator = id
#else
rawSnapshotPathSeparator context = SHA256.update context "\0"
#endif

snapshotModeCommitment :: IndexEntry -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_MODE_COMMITMENT_MUTANT)
snapshotModeCommitment _ = ""
#else
snapshotModeCommitment = renderIndexMode . indexMode
#endif

snapshotObjectCommitment :: IndexEntry -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_OBJECT_COMMITMENT_MUTANT)
snapshotObjectCommitment _ = ""
#else
snapshotObjectCommitment = indexObjectId
#endif

snapshotPathCommitment :: IndexEntry -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_PATH_COMMITMENT_MUTANT)
snapshotPathCommitment _ = ""
#else
snapshotPathCommitment = Text.pack . indexPath
#endif

snapshotBlobByteCommitment :: TrackedEntry -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_BYTE_COMMITMENT_MUTANT)
snapshotBlobByteCommitment = indexObjectId . trackedIndex
#else
snapshotBlobByteCommitment = hex . SHA256.hash . trackedBytes
#endif

-- | Parse the raw, NUL-delimited output of @git ls-files --stage -z@.  This is
-- deliberately exported so oracle tests can exercise malformed records without
-- invoking Git.
parseLsFilesStage :: ByteString -> Either [SnapshotProblem] [IndexEntry]
parseLsFilesStage raw =
  case ByteString.unsnoc raw of
    Nothing -> Left [EmptyIndex]
    Just (_, terminator)
      | terminator /= 0 -> Left [MissingNulTerminator]
      | otherwise ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith parseIndexRecord [1 ..] records
              recordProblems = [problem | Left problem <- parsed]
              entries = [entry | Right entry <- parsed]
              duplicateProblems = map DuplicateTrackedPath (duplicates (map indexPath entries))
              problems = recordProblems <> duplicateProblems <> mixedObjectIdProblems entries
           in if null problems
                then Right (sortOn indexPath entries)
                else Left problems

-- | Parse @git ls-files -v/-t -z@ without trusting line delimiters or a locale.
-- Each record is exactly one ASCII status tag, one space, one UTF-8 repository
-- path, and one NUL terminator.  The caller independently compares the returned
-- path inventory with the stage-zero listing.
parseLsFilesTaggedPaths
  :: IndexFlagObservation
  -> ByteString
  -> Either [SnapshotProblem] [(Char, FilePath)]
parseLsFilesTaggedPaths observationKind raw =
  case ByteString.unsnoc raw of
    Just (_, terminator)
      | terminator == 0 ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith (parseTaggedPathRecord observationKind) [1 ..] records
              parseProblems = [problem | Left problem <- parsed]
              tagged = [value | Right value <- parsed]
              duplicateProblems =
                [ DuplicateIndexFlagPath observationKind path
                | path <- duplicates (map snd tagged)
                ]
              problems = parseProblems <> duplicateProblems
           in if null problems then Right (sortOn snd tagged) else Left problems
    _ -> Left [MissingIndexFlagNulTerminator observationKind]

-- | Parse the final @git ls-files --stage -v -z@ observation.  Unlike a
-- path-only tagged listing, each record binds its visibility tag to the exact
-- stage-zero index entry which produced it.
parseLsFilesTaggedStage :: ByteString -> Either [SnapshotProblem] [(Char, IndexEntry)]
parseLsFilesTaggedStage raw =
  case ByteString.unsnoc raw of
    Just (_, terminator)
      | terminator == 0 ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith parseTaggedStageRecord [1 ..] records
              recordProblems = [problem | Left problem <- parsed]
              tagged = [value | Right value <- parsed]
              duplicateProblems =
                [ DuplicateIndexFlagPath AssumeUnchangedObservation path
                | path <- duplicates (map (indexPath . snd) tagged)
                ]
              problems = recordProblems <> duplicateProblems <> mixedObjectIdProblems (map snd tagged)
           in if null problems
                then Right (sortOn (indexPath . snd) tagged)
                else Left problems
    _ -> Left [MissingIndexFlagNulTerminator AssumeUnchangedObservation]

parseTaggedStageRecord :: Int -> ByteString -> Either SnapshotProblem (Char, IndexEntry)
parseTaggedStageRecord number record =
  case ByteString8.uncons record of
    Nothing -> malformed "empty tagged stage record"
    Just (tag, withSpace) ->
      case ByteString8.uncons withSpace of
        Just (' ', stageRecord)
          | validIndexTag AssumeUnchangedObservation tag -> do
              entry <- parseIndexRecord number stageRecord
              Right (tag, entry)
          | otherwise -> malformed ("unsupported ls-files tag " <> Text.singleton tag)
        _ -> malformed "tagged stage record lacks its status/index space"
 where
  malformed detail = Left (MalformedIndexFlagRecord AssumeUnchangedObservation number detail)

parseTaggedPathRecord
  :: IndexFlagObservation
  -> Int
  -> ByteString
  -> Either SnapshotProblem (Char, FilePath)
parseTaggedPathRecord observationKind number record =
  case ByteString8.uncons record of
    Nothing -> malformed "empty tagged record"
    Just (tag, withSpace) ->
      case ByteString8.uncons withSpace of
        Just (' ', pathBytes)
          | validIndexTag observationKind tag ->
              case TextEncoding.decodeUtf8' pathBytes of
                Left _ -> malformed "tagged path is not UTF-8"
                Right value ->
                  let path = Text.unpack value
                   in if safeTrackedPath path
                        then Right (tag, path)
                        else malformed ("invalid tagged path " <> Text.pack path)
          | otherwise -> malformed ("unsupported ls-files tag " <> Text.singleton tag)
        _ -> malformed "tagged record lacks its status/path space"
 where
  malformed detail = Left (MalformedIndexFlagRecord observationKind number detail)

validIndexTag :: IndexFlagObservation -> Char -> Bool
validIndexTag observationKind tag = case observationKind of
  AssumeUnchangedObservation ->
    tag `elem` ['H', 'S', 'M', 'R', 'C', 'K']
      || tag `elem` ['h', 's', 'm', 'r', 'c', 'k']
  SkipWorktreeObservation -> tag `elem` ['H', 'S', 'M', 'R', 'C', 'K']

decodeNulPathList :: ByteString -> Either SnapshotProblem [FilePath]
decodeNulPathList bytes = case ByteString.unsnoc bytes of
  Nothing -> Right []
  Just (_, terminator)
    | terminator /= 0 -> Left (InvalidWorkspacePath "Git path list lacks its final NUL")
    | otherwise -> traverse decodePath (dropFinalSegment (ByteString.split 0 bytes))
  where
    decodePath rawPath = case TextEncoding.decodeUtf8' rawPath of
      Left _ -> Left (InvalidWorkspacePath "Git path is not UTF-8")
      Right value
        | safeTrackedPath (Text.unpack value) -> Right (Text.unpack value)
        | otherwise -> Left (InvalidWorkspacePath value)

dropFinalSegment :: [value] -> [value]
dropFinalSegment values = case reverse values of
  [] -> []
  _ : reversedRest -> reverse reversedRest

parseIndexRecord :: Int -> ByteString -> Either SnapshotProblem IndexEntry
parseIndexRecord number record = do
  let (header, withTab) = ByteString.break (== 9) record
  pathBytes <-
    if ByteString.null withTab
      then Left (MalformedIndexRecord number "missing header/path tab")
      else Right (ByteString.drop 1 withTab)
  (modeBytes, objectBytes, stageBytes) <-
    case ByteString8.words header of
      [modeValue, objectValue, stageValue] -> Right (modeValue, objectValue, stageValue)
      _ -> Left (MalformedIndexRecord number "expected mode, object id, and stage")
  mode <- parseIndexMode number modeBytes
  if stageBytes /= "0"
    then Left (NonStageZeroEntry number (decodeLenient stageBytes))
    else pure ()
  objectId <- decodeAsciiField number objectBytes
  if validObjectId objectId
    then pure ()
    else Left (InvalidObjectId number objectId)
  path <-
    case TextEncoding.decodeUtf8' pathBytes of
      Left _ -> Left (InvalidTrackedPath number "path is not UTF-8")
      Right value -> Right (Text.unpack value)
  if safeTrackedPath path
    then Right (IndexEntry path mode objectId)
    else Left (InvalidTrackedPath number (Text.pack path))

parseIndexMode :: Int -> ByteString -> Either SnapshotProblem IndexMode
parseIndexMode _ "100644" = Right RegularFile
parseIndexMode _ "100755" = Right ExecutableFile
parseIndexMode _ "120000" = Right SymbolicLink
parseIndexMode number value = Left (UnsupportedIndexMode number (decodeLenient value))

decodeAsciiField :: Int -> ByteString -> Either SnapshotProblem Text
decodeAsciiField number value =
  case TextEncoding.decodeUtf8' value of
    Left _ -> Left (MalformedIndexRecord number "non-ASCII object id")
    Right decoded
      | Text.all (\character -> fromEnum character < 128) decoded -> Right decoded
      | otherwise -> Left (MalformedIndexRecord number "non-ASCII object id")

validObjectId :: Text -> Bool
validObjectId value =
  Text.length value `elem` [40, 64]
    && Text.all asciiLowerHex value

asciiLowerHex :: Char -> Bool
asciiLowerHex character =
  (character >= '0' && character <= '9')
    || (character >= 'a' && character <= 'f')

mixedObjectIdProblems :: [IndexEntry] -> [SnapshotProblem]
mixedObjectIdProblems entries =
  case Set.toAscList (Set.fromList (map (Text.length . indexObjectId) entries)) of
    [] -> []
    [_] -> []
    lengths -> [MixedObjectIdFormats lengths]

safeTrackedPath :: FilePath -> Bool
safeTrackedPath path =
  not (null path)
    && not (isAbsolute path)
    && all safeFilesystemCharacter path
    && all validPart (Text.splitOn "/" (Text.pack path))
  where
    validPart part = not (Text.null part) && part /= "." && part /= ".."

classifySnapshot :: SourceSnapshot -> SourceClosure
classifySnapshot snapshot =
  SourceClosure
    (snapshotIdentity snapshot)
    paths
    debt
    duplicateProblems
    pbAdmission
  where
    initiallyClassified = map classifyEntry (snapshotEntries snapshot)
    pbEntries = pbTrackedFilesFromSnapshot snapshot
    pbAdmission = Pb.pbBootstrapGrammarDiagnostic pbEntries
    -- A caller-supplied refusal diagnostic is not source-binding authority.
    -- The package-hidden acquired boundary separately consumes the same raw
    -- snapshot bytes through the candidate grammar entry point.
    paths = initiallyClassified
    duplicateProblems = map DuplicateTrackedPath (duplicates (map pathOf (snapshotEntries snapshot)))
    pathOf = indexPath . trackedIndex
    debt =
      foldl'
        (\current item -> case classifiedAs item of
            RegisteredLegacy identifier ->
              Map.insertWith (<>) identifier [pathOf (classifiedEntry item)] current
            _ -> current
        )
        Map.empty
        paths

toPbTrackedFile :: TrackedEntry -> (FilePath, Text, ByteString)
toPbTrackedFile entry =
  ( rawPbPath (indexPath indexed)
  , rawPbMode
      (case indexMode indexed of
        RegularFile -> "100644"
        ExecutableFile -> "100755"
        SymbolicLink -> "120000"
      )
  , rawPbBytes (trackedBytes entry)
  )
 where
  indexed = trackedIndex entry

-- | Exact raw bootstrap inventory projected from a source snapshot. This is
-- package-hidden so the acquired source-debt boundary can run the candidate
-- grammar without exposing an admission constructor publicly.
pbTrackedFilesFromSnapshot :: SourceSnapshot -> [(FilePath, Text, ByteString)]
pbTrackedFilesFromSnapshot snapshot =
  [ toPbTrackedFile entry
  | entry <- snapshotEntries snapshot
  , under canonicalPbRoot (indexPath (trackedIndex entry))
  ]

rawPbPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CLOSURE_PB_INPUT_PATH_ROUTE_MUTANT)
rawPbPath _ = "pb/mutant.py"
#else
rawPbPath = id
#endif

rawPbMode :: Text -> Text
#if defined(VALIDATION_SOURCE_CLOSURE_PB_INPUT_MODE_ROUTE_MUTANT)
rawPbMode _ = "100755"
#else
rawPbMode = id
#endif

rawPbBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_CLOSURE_PB_INPUT_BYTES_ROUTE_MUTANT)
rawPbBytes = ByteString.drop 1
#else
rawPbBytes = id
#endif

-- | Pure, total classification of one supplied tracked entry.  Root migrations
-- and format migrations are intentionally ordered so an entry cannot be charged
-- to two legacy rows.
classifyEntry :: TrackedEntry -> ClassifiedPath
classifyEntry entry =
  ClassifiedPath
    { classifiedEntry = entry
    , classifiedAs = finalClass
    , classificationFacets = facets
    , classificationReasons = reasons
    }
  where
    path = indexPath (trackedIndex entry)
    bytes = trackedBytes entry
    initial = primaryClass path bytes
    facets = entryFacets entry
    structuralReasons = disallowedStructure initial facets
    signatureReasons = disallowedSignature initial path bytes facets
    reasons = rawReasonAssembly (primaryReasons initial path bytes) structuralReasons signatureReasons
    finalClass
      | rawFinalClassRetainsInitial initial = initial
      | null structuralReasons && null signatureReasons = initial
      | otherwise = UnregisteredBehavioralSource

primaryClass :: FilePath -> ByteString -> SourceClass
primaryClass path _bytes
  | under canonicalGeneratedRoot path = generatedBuildRootClass
  | under ".data" path = generatedDataRootClass
  | under ".test_data" path = generatedTestDataRootClass
  | retainedVendorRoot path = RegisteredLegacy SourceVendor
  | retainedDhallSuffix path = RegisteredLegacy SourceDhall
  | retainedDhallRoot path = RegisteredLegacy SourceDhall
  | retainedProtoSuffix path = RegisteredLegacy SourceProto
  | retainedProtoRoot path = RegisteredLegacy SourceProto
  | retainedUiPackage path = RegisteredLegacy SourceUi
  | retainedUiRoot path = RegisteredLegacy SourceUi
  | retainedPulumiRoot path = RegisteredLegacy SourcePulumi
  | retainedProbeDebt path = RegisteredLegacy SourceProbe
  | retainedTestDebt path = RegisteredLegacy SourceTest
  | retainedToolsRoot path = RegisteredLegacy SourceTools
  -- The refusal-only grammar diagnostic cannot authorize the repository
  -- exception.  An acquired opaque boundary is still absent, so pb stays
  -- explicit registered migration debt.
  | retainedPbRoot path = RegisteredLegacy SourcePb
  | admittedHaskellPath path = HaskellSource
  | admittedDocumentationPath path = DocumentationInput
  | isProjectDeclaration path = ProjectDeclaration
  | otherwise = UnregisteredBehavioralSource

generatedBuildRootClass, generatedDataRootClass, generatedTestDataRootClass :: SourceClass
#if defined(VALIDATION_SOURCE_CLOSURE_GENERATED_BUILD_CLASS_REDIRECT_MUTANT)
generatedBuildRootClass = RegisteredLegacy SourceVendor
#else
generatedBuildRootClass = UnregisteredBehavioralSource
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_GENERATED_DATA_CLASS_REDIRECT_MUTANT)
generatedDataRootClass = RegisteredLegacy SourceVendor
#else
generatedDataRootClass = UnregisteredBehavioralSource
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_GENERATED_TEST_DATA_CLASS_REDIRECT_MUTANT)
generatedTestDataRootClass = RegisteredLegacy SourceVendor
#else
generatedTestDataRootClass = UnregisteredBehavioralSource
#endif

retainedVendorRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_VENDOR_ROOT_REMOVAL_MUTANT)
retainedVendorRoot _ = False
#else
retainedVendorRoot = under "vendor"
#endif

retainedDhallSuffix :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DHALL_SUFFIX_REMOVAL_MUTANT)
retainedDhallSuffix _ = False
#else
retainedDhallSuffix = hasSuffix ".dhall"
#endif

retainedDhallRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DHALL_ROOT_REMOVAL_MUTANT)
retainedDhallRoot _ = False
#else
retainedDhallRoot = under "dhall"
#endif

retainedProtoSuffix :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROTO_SUFFIX_REMOVAL_MUTANT)
retainedProtoSuffix _ = False
#else
retainedProtoSuffix = hasSuffix ".proto"
#endif

retainedProtoRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROTO_ROOT_REMOVAL_MUTANT)
retainedProtoRoot _ = False
#else
retainedProtoRoot = under "proto"
#endif

retainedUiPackage :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_UI_PACKAGE_REMOVAL_MUTANT)
retainedUiPackage _ = False
#else
retainedUiPackage = (== "package.json")
#endif

retainedUiRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_UI_ROOT_REMOVAL_MUTANT)
retainedUiRoot _ = False
#else
retainedUiRoot = under "ui"
#endif

retainedPulumiRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PULUMI_ROOT_REMOVAL_MUTANT)
retainedPulumiRoot _ = False
#else
retainedPulumiRoot = under "pulumi"
#endif

retainedProbeDebt :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROBE_DEBT_REMOVAL_MUTANT)
retainedProbeDebt path = probeAdmitted path `seq` False
#else
retainedProbeDebt path = under "probe" path && not (probeAdmitted path)
#endif

retainedTestDebt :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_TEST_DEBT_REMOVAL_MUTANT)
retainedTestDebt path = testAdmitted path `seq` False
#else
retainedTestDebt path = under "test" path && not (testAdmitted path)
#endif

retainedToolsRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_TOOLS_ROOT_REMOVAL_MUTANT)
retainedToolsRoot _ = False
#else
retainedToolsRoot = under "tools"
#endif

retainedPbRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PB_ROOT_REMOVAL_MUTANT)
retainedPbRoot _ = False
#else
retainedPbRoot = under canonicalPbRoot
#endif

canonicalPbRoot :: FilePath
canonicalPbRoot = Policy.pbRoot (Policy.pbContract Policy.canonicalPolicyContract)

canonicalGeneratedRoot :: FilePath
canonicalGeneratedRoot =
  Policy.generationRootPath (Policy.generationRoot (Policy.generationContract Policy.canonicalPolicyContract))

canonicalHaskellSuffix :: FilePath
canonicalHaskellSuffix =
  Policy.behavioralSourceSuffix (Policy.sourceBehavioralLanguage (Policy.sourceContract Policy.canonicalPolicyContract))

probeAdmitted :: FilePath -> Bool
probeAdmitted path =
  hasSuffix canonicalHaskellSuffix path
    || path == "probe/probe.cabal"

testAdmitted :: FilePath -> Bool
testAdmitted = hasSuffix canonicalHaskellSuffix

admittedHaskellPath :: FilePath -> Bool
admittedHaskellPath path =
  retainedHaskellSuffix path
    && or
      [ retainedHaskellSrcRoot path
      , retainedHaskellAppRoot path
      , retainedHaskellTestRoot path
      , retainedHaskellProbeRoot path
      ]

retainedHaskellSuffix :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_SUFFIX_REMOVAL_MUTANT)
retainedHaskellSuffix _ = False
#else
retainedHaskellSuffix = hasSuffix canonicalHaskellSuffix
#endif

retainedHaskellSrcRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_SRC_ROOT_REMOVAL_MUTANT)
retainedHaskellSrcRoot _ = False
#else
retainedHaskellSrcRoot = under "src"
#endif

retainedHaskellAppRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_APP_ROOT_REMOVAL_MUTANT)
retainedHaskellAppRoot _ = False
#else
retainedHaskellAppRoot = under "app"
#endif

retainedHaskellTestRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_TEST_ROOT_REMOVAL_MUTANT)
retainedHaskellTestRoot _ = False
#else
retainedHaskellTestRoot = under "test"
#endif

retainedHaskellProbeRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_PROBE_ROOT_REMOVAL_MUTANT)
retainedHaskellProbeRoot _ = False
#else
retainedHaskellProbeRoot = under "probe"
#endif

-- | Governed Markdown is admitted by rule, not by a checked-in inventory.
--
-- This was a 196-arm enumeration of every governed document. It drifted: it
-- still named a deleted @CRASH_SUMMARY.md@ and did not name the tracked
-- @CARTESIAN_EXPLOSION.md@, so a tracked governed document fell through to
-- 'UnregisteredBehavioralSource' and raised @SRC-UNREGISTERED@ on a clean tree.
-- Because the gate chain re-derives gate 0 inside every later phase's gate,
-- adding or renaming any governed document reopened a closed Phase 0.
--
-- An enumeration is also the artefact @testing_doctrine.md §9@ forecloses: a
-- surface must not be removable from the required set by editing a checked-in
-- list. The rule below reproduces the previous inventory exactly — both
-- governed directories are wholly Markdown — while admitting a document the
-- moment it is tracked. Whether that document is well formed remains owned by
-- the documentation gate; this predicate decides only that prose is prose.
admittedDocumentationPath :: FilePath -> Bool
admittedDocumentationPath path =
  retainedDocumentationSuffix path
    && or
      [ retainedDocumentationRootFile path
      , retainedDocumentationDocumentsRoot path
      , retainedDocumentationPlanRoot path
      ]

retainedDocumentationSuffix :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENTATION_SUFFIX_REMOVAL_MUTANT)
retainedDocumentationSuffix _ = False
#else
retainedDocumentationSuffix = hasSuffix canonicalDocumentationSuffix
#endif

-- | A repository-root document, which is the class the drifted enumeration
-- kept getting wrong.
retainedDocumentationRootFile :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENTATION_ROOT_FILE_REMOVAL_MUTANT)
retainedDocumentationRootFile _ = False
#else
retainedDocumentationRootFile path = '/' `notElem` path
#endif

retainedDocumentationDocumentsRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENTATION_DOCUMENTS_ROOT_REMOVAL_MUTANT)
retainedDocumentationDocumentsRoot _ = False
#else
retainedDocumentationDocumentsRoot = under "documents"
#endif

retainedDocumentationPlanRoot :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENTATION_PLAN_ROOT_REMOVAL_MUTANT)
retainedDocumentationPlanRoot _ = False
#else
retainedDocumentationPlanRoot = under "DEVELOPMENT_PLAN"
#endif

canonicalDocumentationSuffix :: String
canonicalDocumentationSuffix = ".md"

#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENT_INVENTORY_WIDEN_MUTANT)
    `Set.union` Set.singleton "documents/renamed_program.md"
#endif

rawEntryFacetOrder :: [SourceFacet] -> [SourceFacet]
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_ORDER_MUTANT)
rawEntryFacetOrder = reverse
#else
rawEntryFacetOrder = id
#endif

rawRegularModeFacets, rawExecutableModeFacets, rawBinaryFacets :: [SourceFacet]
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_REGULAR_MODE_ROUTE_MUTANT)
rawRegularModeFacets = [ExecutableModeFacet]
#else
rawRegularModeFacets = []
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_EXECUTABLE_DROP_MUTANT)
rawExecutableModeFacets = []
#else
rawExecutableModeFacets = [ExecutableModeFacet]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_BINARY_DROP_MUTANT)
rawBinaryFacets = []
#else
rawBinaryFacets = [BinaryContentFacet]
#endif

rawSymbolicLinkFacets :: Text -> [SourceFacet]
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_SYMLINK_DROP_MUTANT)
rawSymbolicLinkFacets _ = []
#else
rawSymbolicLinkFacets value = [SymbolicLinkFacet value]
#endif

rawShebangFacets :: Text -> [SourceFacet]
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_SHEBANG_DROP_MUTANT)
rawShebangFacets _ = []
#else
rawShebangFacets value = [ShebangFacet value]
#endif

rawForeignSignatureFacets :: Text -> [SourceFacet]
#if defined(VALIDATION_SOURCE_CLOSURE_ENTRY_FACET_FOREIGN_DROP_MUTANT)
rawForeignSignatureFacets _ = []
#else
rawForeignSignatureFacets value = [ForeignSourceSignatureFacet value]
#endif

rawReasonAssembly :: [Text] -> [Text] -> [Text] -> [Text]
rawReasonAssembly primary structural signature =
  rawReasonOrder
    (rawPrimaryReasons primary)
    (rawStructuralReasons structural)
    (rawSignatureReasons signature)

rawReasonOrder :: [Text] -> [Text] -> [Text] -> [Text]
#if defined(VALIDATION_SOURCE_CLOSURE_REASON_ORDER_MUTANT)
rawReasonOrder primary structural signature = signature <> structural <> primary
#else
rawReasonOrder primary structural signature = primary <> structural <> signature
#endif

rawPrimaryReasons, rawStructuralReasons, rawSignatureReasons :: [Text] -> [Text]
#if defined(VALIDATION_SOURCE_CLOSURE_REASON_PRIMARY_DROP_MUTANT)
rawPrimaryReasons _ = []
#else
rawPrimaryReasons = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_REASON_STRUCTURAL_DROP_MUTANT)
rawStructuralReasons _ = []
#else
rawStructuralReasons = id
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_REASON_SIGNATURE_DROP_MUTANT)
rawSignatureReasons _ = []
#else
rawSignatureReasons = id
#endif

rawFinalClassRetainsInitial :: SourceClass -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_FINAL_CLASS_GUARD_WIDEN_MUTANT)
rawFinalClassRetainsInitial _ = True
#else
rawFinalClassRetainsInitial = isRegistered
#endif

rawStructuralReason :: Int -> Text -> Text
rawStructuralReason ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_STRUCTURAL_REASON_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_STRUCTURAL_REASON_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_STRUCTURAL_REASON_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_STRUCTURAL_REASON_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawSignatureReason :: Int -> Text -> Text
rawSignatureReason ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_REASON_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_REASON_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_REASON_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_REASON_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawPrimaryReason :: Int -> Text -> Text
rawPrimaryReason ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_PRIMARY_REASON_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_PRIMARY_REASON_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawTextualNulCheck :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_TEXTUAL_NUL_CHECK_BYPASS_MUTANT)
rawTextualNulCheck _ = True
#else
rawTextualNulCheck = not . ByteString.elem 0
#endif

rawTextualUtf8Check :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_TEXTUAL_UTF8_CHECK_BYPASS_MUTANT)
rawTextualUtf8Check _ = True
#else
rawTextualUtf8Check = either (const False) (const True) . TextEncoding.decodeUtf8'
#endif

entryFacets :: TrackedEntry -> [SourceFacet]
entryFacets entry = rawEntryFacetOrder (modeFacets <> shebangFacets <> contentFacets)
  where
    bytes = trackedBytes entry
    modeFacets = case indexMode (trackedIndex entry) of
      RegularFile -> rawRegularModeFacets
      ExecutableFile -> rawExecutableModeFacets
      SymbolicLink -> rawSymbolicLinkFacets (decodeLenient bytes)
    shebangFacets = maybe [] rawShebangFacets (shebang bytes)
    contentFacets
      | ByteString.elem 0 bytes = rawBinaryFacets
      | otherwise = maybe [] rawForeignSignatureFacets (foreignSourceSignature bytes)

disallowedStructure :: SourceClass -> [SourceFacet] -> [Text]
disallowedStructure sourceClass facets
  | isRegistered sourceClass = []
  | otherwise =
      concat
        [ [rawStructuralReason 1 "tracked executable mode is not an authored-source role" | retainedExecutableFacetRefusal facets]
        , [rawStructuralReason 2 "tracked symbolic links are not admitted source" | retainedSymlinkFacetRefusal facets]
        , [rawStructuralReason 3 "tracked binary bytes are not admitted source" | retainedBinaryFacetRefusal facets]
        , [rawStructuralReason 4 "a shebang may not disguise an authored source role" | retainedShebangFacetRefusal facets]
        ]

retainedExecutableFacetRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_EXECUTABLE_FACET_BYPASS_MUTANT)
retainedExecutableFacetRefusal _ = False
#else
retainedExecutableFacetRefusal = elem ExecutableModeFacet
#endif

retainedSymlinkFacetRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_SYMLINK_FACET_BYPASS_MUTANT)
retainedSymlinkFacetRefusal facets = any isSymlinkFacet facets `seq` False
#else
retainedSymlinkFacetRefusal = any isSymlinkFacet
#endif

retainedBinaryFacetRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_BINARY_FACET_BYPASS_MUTANT)
retainedBinaryFacetRefusal _ = False
#else
retainedBinaryFacetRefusal = elem BinaryContentFacet
#endif

retainedShebangFacetRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_SHEBANG_FACET_BYPASS_MUTANT)
retainedShebangFacetRefusal facets = any isShebangFacet facets `seq` False
#else
retainedShebangFacetRefusal = any isShebangFacet
#endif

disallowedSignature :: SourceClass -> FilePath -> ByteString -> [SourceFacet] -> [Text]
disallowedSignature sourceClass _path bytes facets
  | isRegistered sourceClass = []
  | sourceClass == UnregisteredBehavioralSource = [rawSignatureReason 1 "path has no admitted authored-source class"]
  | retainedInvalidUtf8Refusal bytes = [rawSignatureReason 2 "authored text is not valid UTF-8"]
  | sourceClass == HaskellSource && retainedHaskellForeignSignatureRefusal facets =
      [rawSignatureReason 3 ".hs bytes begin with a foreign-language source signature"]
  | sourceClass `elem` [DocumentationInput, ProjectDeclaration]
      && retainedNoncodeForeignSignatureRefusal facets =
      [rawSignatureReason 4 "an admitted non-code input begins with a behavioral-source signature"]
  | otherwise = []

retainedInvalidUtf8Refusal :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_INVALID_UTF8_BYPASS_MUTANT)
retainedInvalidUtf8Refusal bytes = textual bytes `seq` False
#else
retainedInvalidUtf8Refusal = not . textual
#endif

retainedHaskellForeignSignatureRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_HASKELL_FOREIGN_SIGNATURE_BYPASS_MUTANT)
retainedHaskellForeignSignatureRefusal _ = False
#else
retainedHaskellForeignSignatureRefusal = any isForeignSignatureFacet
#endif

retainedNoncodeForeignSignatureRefusal :: [SourceFacet] -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_NONCODE_FOREIGN_SIGNATURE_BYPASS_MUTANT)
retainedNoncodeForeignSignatureRefusal _ = False
#else
retainedNoncodeForeignSignatureRefusal = any isForeignSignatureFacet
#endif

primaryReasons :: SourceClass -> FilePath -> ByteString -> [Text]
primaryReasons (RegisteredLegacy SourcePb) _path _bytes =
  [rawPrimaryReason 1 "pb admission requires the complete exact snapshot-level grammar"]
primaryReasons UnregisteredBehavioralSource _ _ = [rawPrimaryReason 2 "no closed-grammar class matched"]
primaryReasons _ _ _ = []

sourceClosureCheck :: SourceClosure -> CheckResult
sourceClosureCheck closure =
  let result = sourceClosureCheckCore closure
   in result
        { checkFindings = sourceClosureDiagnosticFindings <> checkFindings result
        }

-- | Candidate-capable closure check.  It accepts only the opaque authority
-- wrapper and derives the closure itself, preventing a caller from pairing an
-- acquired token with a different, caller-authored 'SourceClosure'.
sourceClosureCheckAcquired :: AcquiredSourceSnapshot -> CheckResult
sourceClosureCheckAcquired = sourceClosureCheckCore . classifySnapshot . acquiredSourceSnapshot

sourceClosureDiagnosticFindings :: [Finding]
sourceClosureDiagnosticFindings =
  [ finding
      "SOURCE-CLOSURE-DIAGNOSTIC-ONLY"
      "<caller-supplied-source-closure>"
      "caller-supplied source closure is diagnostic input, not candidate capture authority"
  ]

sourceClosureCheckCore :: SourceClosure -> CheckResult
sourceClosureCheckCore closure =
  CheckResult
    { checkName = "source-closure"
    , checkObservations =
        [ observation "source.snapshot" (closureSnapshotIdentity closure)
        , observation "source.path-count" (Text.pack (show (length (closurePaths closure))))
        ]
          <> concatMap pathObservation (closurePaths closure)
          <> concatMap debtObservations (Map.toAscList (closureRegisteredDebt closure))
    , checkFindings =
        map snapshotFinding (closureProblems closure)
          <> pbAdmissionFindings (closurePbBootstrapDiagnostic closure)
          <> concatMap pathFindings (closurePaths closure)
    }
  where
    pathObservation item =
      let entry = trackedIndex (classifiedEntry item)
          path = Text.pack (indexPath entry)
       in [ observation
          ("source.path." <> path)
          ( renderSourceClass (classifiedAs item)
              <> "\t"
              <> renderIndexMode (indexMode entry)
              <> "\t"
              <> indexObjectId entry
              <> "\t"
              <> Text.intercalate "," (map renderSourceFacet (classificationFacets item))
          )
          ]
    debtObservations (identifier, paths) =
      [ observation
          ("source.debt." <> renderSourceDebtId identifier <> "." <> Text.pack path)
          (Text.pack path)
      | path <- sortOn id paths
      ]
    pathFindings item
      | classifiedAs item /= UnregisteredBehavioralSource = []
      | otherwise =
          [ finding
              "SRC-UNREGISTERED"
              (indexPath (trackedIndex (classifiedEntry item)))
              (Text.intercalate "; " (classificationReasons item))
          ]

pbAdmissionFindings :: CheckResult -> [Finding]
pbAdmissionFindings diagnostic =
  [ finding
      "SRC-PB-ADMISSION"
      "pb/**"
      (findingCode problem <> ": " <> findingDetail problem)
  | problem <- checkFindings diagnostic
  , findingCode problem
      `notElem`
        [ "PB-GRAMMAR-DIAGNOSTIC-ONLY"
        , "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
        ]
  ]

registeredSourceIds :: SourceClosure -> Set SourceDebtId
registeredSourceIds = Map.keysSet . closureRegisteredDebt

-- | Bind one registered migration family to exact paths, modes, verified Git
-- object identities, and independent SHA-256 payload commitments observed in
-- the immutable source snapshot. This is an inventory fingerprint, not
-- correctness evidence. Legacy compares it with a separately authored Haskell
-- baseline so a new or modified file cannot ride an already-open family row.
sourceDebtFingerprint :: SourceDebtId -> SourceClosure -> Text
sourceDebtFingerprint identifier closure =
  hex (SHA256.hash manifest)
 where
  members =
    sortOn
      (indexPath . trackedIndex . classifiedEntry)
      [ item
      | item <- closurePaths closure
      , classifiedAs item == RegisteredLegacy identifier
      ]
  manifest =
    "amoebius-source-debt-v2\0"
      <> TextEncoding.encodeUtf8 (renderSourceDebtId identifier <> "\0")
      <> ByteString.concat (map renderMember members)
  renderMember item =
    let trackedEntry = classifiedEntry item
        entry = trackedIndex trackedEntry
     in TextEncoding.encodeUtf8
          ( Text.pack (indexPath entry)
              <> "\0"
              <> renderIndexMode (indexMode entry)
              <> "\0"
              <> indexObjectId entry
              <> "\0"
              <> debtBlobByteCommitment trackedEntry
              <> "\0"
          )

debtBlobByteCommitment :: TrackedEntry -> Text
debtBlobByteCommitment = hex . SHA256.hash . trackedBytes

sourceDebtPathCount :: SourceDebtId -> SourceClosure -> Int
sourceDebtPathCount identifier closure =
  length
    [ ()
    | item <- closurePaths closure
    , classifiedAs item == RegisteredLegacy identifier
    ]

rawRenderedDebt :: Int -> Text -> Text
rawRenderedDebt ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_05_MAPPING_MUTANT)
  | ordinal == 5 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_06_MAPPING_MUTANT)
  | ordinal == 6 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_07_MAPPING_MUTANT)
  | ordinal == 7 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_08_MAPPING_MUTANT)
  | ordinal == 8 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_DEBT_09_MAPPING_MUTANT)
  | ordinal == 9 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawRenderedClass :: Int -> Text -> Text
rawRenderedClass ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_RENDER_CLASS_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_CLASS_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_CLASS_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_CLASS_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_CLASS_05_MAPPING_MUTANT)
  | ordinal == 5 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawRenderedMode :: Int -> Text -> Text
rawRenderedMode ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_RENDER_MODE_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_MODE_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_MODE_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

rawRenderedFacet :: Int -> Text -> Text
rawRenderedFacet ordinal value
#if defined(VALIDATION_SOURCE_CLOSURE_RENDER_FACET_01_MAPPING_MUTANT)
  | ordinal == 1 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_FACET_02_MAPPING_MUTANT)
  | ordinal == 2 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_FACET_03_MAPPING_MUTANT)
  | ordinal == 3 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_FACET_04_MAPPING_MUTANT)
  | ordinal == 4 = value <> "-mutant"
#elif defined(VALIDATION_SOURCE_CLOSURE_RENDER_FACET_05_MAPPING_MUTANT)
  | ordinal == 5 = value <> "-mutant"
#endif
  | otherwise = ordinal `seq` value

renderSourceDebtId :: SourceDebtId -> Text
renderSourceDebtId identifier = case identifier of
  SourceTools -> rawRenderedDebt 1 "LTD-SRC-001"
  SourceDhall -> rawRenderedDebt 2 "LTD-SRC-002"
  SourceProto -> rawRenderedDebt 3 "LTD-SRC-003"
  SourceUi -> rawRenderedDebt 4 "LTD-SRC-004"
  SourcePulumi -> rawRenderedDebt 5 "LTD-SRC-005"
  SourceTest -> rawRenderedDebt 6 "LTD-SRC-006"
  SourceProbe -> rawRenderedDebt 7 "LTD-SRC-007"
  SourcePb -> rawRenderedDebt 8 "LTD-SRC-008"
  SourceVendor -> rawRenderedDebt 9 "LTD-SRC-009"

renderSourceClass :: SourceClass -> Text
renderSourceClass sourceClass = case sourceClass of
  HaskellSource -> rawRenderedClass 1 "haskell"
  DocumentationInput -> rawRenderedClass 2 "documentation"
  ProjectDeclaration -> rawRenderedClass 3 "project-declaration"
  RegisteredLegacy identifier -> rawRenderedClass 4 ("registered:" <> renderSourceDebtId identifier)
  UnregisteredBehavioralSource -> rawRenderedClass 5 "unregistered"

renderIndexMode :: IndexMode -> Text
renderIndexMode mode = case mode of
  RegularFile -> rawRenderedMode 1 "100644"
  ExecutableFile -> rawRenderedMode 2 "100755"
  SymbolicLink -> rawRenderedMode 3 "120000"

renderGitObjectFormat :: GitObjectFormat -> Text
renderGitObjectFormat GitObjectSha1 = "sha1"
renderGitObjectFormat GitObjectSha256 = "sha256"

renderSourceFacet :: SourceFacet -> Text
renderSourceFacet facet = case facet of
  ExecutableModeFacet -> rawRenderedFacet 1 "executable"
  ShebangFacet value -> rawRenderedFacet 2 ("shebang=" <> value)
  SymbolicLinkFacet value -> rawRenderedFacet 3 ("symlink=" <> value)
  BinaryContentFacet -> rawRenderedFacet 4 "binary"
  ForeignSourceSignatureFacet value -> rawRenderedFacet 5 ("foreign-signature=" <> value)

renderSnapshotProblem :: SnapshotProblem -> Text
renderSnapshotProblem problem = case problem of
  GitExecutableNotAbsolute path -> "Git executable is not absolute: " <> Text.pack path
  CallerSelectedGitDiagnosticOnly path ->
    "caller-selected Git is diagnostic-only and cannot mint candidate evidence: " <> Text.pack path
  SourceSnapshotAtomicityRequiresExternalObserver ->
    "sequential source-snapshot observations require an external atomic clean-room observer"
  RepositoryRootNotAbsolute path -> "repository root is not absolute: " <> Text.pack path
  RepositoryRootMismatch expected actual ->
    "repository root mismatch: expected " <> Text.pack expected <> ", Git reported " <> Text.pack actual
  RepositoryHeadUnavailable status detail ->
    "repository HEAD commit is unavailable ("
      <> Text.pack (show status)
      <> "): "
      <> detail
  InvalidRepositoryHead detail -> "repository HEAD commit identity is invalid: " <> detail
  RepositoryHeadChangedDuringCapture before after ->
    "repository HEAD changed during capture: " <> before <> " -> " <> after
  GitProcessFailure arguments status stderrText ->
    "Git failed (" <> Text.pack (show status) <> ") for " <> Text.pack (unwords arguments) <> ": " <> stderrText
  GitProcessIoFailure arguments detail ->
    "Git I/O failed for " <> Text.pack (unwords arguments) <> ": " <> detail
  InternalGitCaptureEnvelopeUnavailable stdoutMaximum stderrMaximum ->
    "source-closure Git capture is disabled until streaming stdout/stderr limits are enforced before allocation: stdout-maximum="
      <> Text.pack (show stdoutMaximum)
      <> "; stderr-maximum="
      <> Text.pack (show stderrMaximum)
  InternalTrackedReadEnvelopeUnavailable blobMaximum aggregateMaximum ->
    "source-closure tracked reads are disabled until descriptor-relative streaming blob limits are enforced: blob-maximum="
      <> Text.pack (show blobMaximum)
      <> "; aggregate-maximum="
      <> Text.pack (show aggregateMaximum)
  InternalAuthoredTraversalEnvelopeUnavailable entryMaximum depthMaximum pathMaximum ->
    "source-closure authored traversal is disabled until entry/depth/path limits are enforced before enumeration: entry-maximum="
      <> Text.pack (show entryMaximum)
      <> "; depth-maximum="
      <> Text.pack (show depthMaximum)
      <> "; path-byte-maximum="
      <> Text.pack (show pathMaximum)
  EmptyIndex -> "Git index is empty"
  MissingNulTerminator -> "Git index listing lacks its final NUL"
  MalformedIndexRecord number detail -> recordDetail number detail
  UnsupportedIndexMode number mode -> recordDetail number ("unsupported mode " <> mode)
  NonStageZeroEntry number stage -> recordDetail number ("non-stage-zero entry " <> stage)
  InvalidObjectId number objectId -> recordDetail number ("invalid object id " <> objectId)
  InvalidTrackedPath number path -> recordDetail number ("invalid path " <> path)
  DuplicateTrackedPath path -> "duplicate tracked path: " <> Text.pack path
  MixedObjectIdFormats lengths ->
    "Git index mixes unsupported object-id widths: " <> Text.pack (show lengths)
  UnsupportedRepositoryObjectFormat value ->
    "Git repository reported an unsupported storage object format: " <> value
  IndexObjectFormatMismatch objectFormat entries ->
    "Git index object IDs do not match repository storage format "
      <> renderGitObjectFormat objectFormat
      <> ": "
      <> Text.pack (show entries)
  RepositoryObjectFormatChanged before after ->
    "Git repository storage object format changed during capture: before="
      <> renderGitObjectFormat before
      <> ", after="
      <> renderGitObjectFormat after
  UnsupportedBlobObjectIdFormat objectId ->
    "loaded blob has an unsupported object-id format: " <> objectId
  LoadedBlobObjectIdMismatch expected actual ->
    "loaded blob object-id mismatch: expected=" <> expected <> ", recomputed=" <> actual
  MissingLoadedBlob objectId -> "loaded blob map omitted index object " <> objectId
  MissingIndexFlagNulTerminator observationKind ->
    "index-flag observation lacks its final NUL: " <> renderIndexFlagObservation observationKind
  MalformedIndexFlagRecord observationKind number detail ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " record "
      <> Text.pack (show number)
      <> ": "
      <> detail
  DuplicateIndexFlagPath observationKind path ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " duplicated path: "
      <> Text.pack path
  IndexFlagInventoryMismatch observationKind expected actual ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " path inventory mismatch: expected="
      <> renderPaths expected
      <> ", actual="
      <> renderPaths actual
  AssumeUnchangedTrackedPaths paths ->
    "tracked paths carry assume-unchanged: " <> renderPaths paths
  SkipWorktreeTrackedPaths paths ->
    "tracked paths carry skip-worktree: " <> renderPaths paths
  TrackedWorktreePathMissing path ->
    "tracked worktree path is missing or sparse: " <> Text.pack path
  TrackedWorktreeExecutableModeUnavailable path ->
    "raw executable-mode observation is unavailable for tracked worktree path: " <> Text.pack path
  TrackedWorktreeKindMismatch path expected actual ->
    "tracked worktree kind mismatch at "
      <> Text.pack path
      <> ": index="
      <> renderIndexMode expected
      <> ", worktree="
      <> renderWorktreeEntryKind actual
  TrackedWorktreeExecutableMismatch path expected actual ->
    "tracked worktree executable-mode mismatch at "
      <> Text.pack path
      <> ": expected="
      <> Text.pack (show expected)
      <> ", actual="
      <> Text.pack (show actual)
  TrackedWorktreeBytesMismatch path ->
    "tracked worktree bytes differ from the acquired index blob: " <> Text.pack path
  TrackedWorktreeEntryRace path ->
    "tracked worktree path changed kind, mode, target, size, or timestamp while it was read: " <> Text.pack path
  TrackedWorktreeIoFailure path detail ->
    "tracked worktree observation failed at " <> Text.pack path <> ": " <> detail
  InvalidWorktreeSymlinkTarget path ->
    "tracked worktree symlink target is not valid UTF-8 at: " <> Text.pack path
  TrackedWorktreeChangedDuringCapture paths ->
    "tracked worktree observation changed during capture: " <> renderPaths paths
  AuthoredRootInventoryIoFailure path detail ->
    "authored-root recursive inventory failed at " <> Text.pack path <> ": " <> detail
  AuthoredRootDescriptorWalkUnavailable path ->
    "authored-root descriptor-relative no-follow inventory is unavailable at: " <> Text.pack path
  AuthoredRootDirectoryChangedDuringWalk path ->
    "authored-root directory changed identity or metadata during descriptor walk at: " <> Text.pack path
  AuthoredRootEntryKindChanged path expected actual ->
    "authored-root entry changed kind during descriptor walk at "
      <> Text.pack path
      <> ": expected="
      <> renderWorktreeEntryKind expected
      <> ", actual="
      <> renderWorktreeEntryKind actual
  AuthoredRootUnknownEntryType path ->
    "authored-root entry type is unavailable during descriptor walk at: " <> Text.pack path
  InvalidAuthoredRootPath path ->
    "authored-root recursive inventory encountered a non-UTF-8 or unsafe path: " <> Text.pack path
  ContainedStateRootKindMismatch path actual ->
    "contained state root is not a real directory at "
      <> Text.pack path
      <> ": observed="
      <> renderWorktreeEntryKind actual
  ContainedStateRootRequiresExternalObserver path ->
    "contained state root requires an external clean-room freshness and ownership observer: "
      <> Text.pack path
  AuthoredRootAncestorKindMismatch path actual ->
    "authored-root tracked ancestor is not a directory at "
      <> Text.pack path
      <> ": worktree="
      <> renderWorktreeEntryKind actual
  UnexpectedAuthoredRootMaterial paths ->
    "untracked or ignored material exists beneath authored roots: " <> renderPaths paths
  AuthoredRootChangedDuringCapture added removed changed ->
    "authored-root inventory changed during capture: added="
      <> renderPaths added
      <> ", removed="
      <> renderPaths removed
      <> ", changed-kind="
      <> renderPaths changed
  TrackedWorktreeDivergence paths ->
    "tracked worktree/index divergence: " <> renderPaths paths
  StagedIndexDivergence paths ->
    "staged index/HEAD divergence: " <> renderPaths paths
  UntrackedNonIgnoredPaths paths ->
    "untracked non-ignored paths: " <> renderPaths paths
  IndexChangedDuringCapture -> "Git index changed during snapshot capture"
  InvalidWorkspacePath detail -> "invalid workspace path observation: " <> detail
  where
    recordDetail number detail = "index record " <> Text.pack (show number) <> ": " <> detail

renderIndexFlagObservation :: IndexFlagObservation -> Text
renderIndexFlagObservation observationKind = case observationKind of
  AssumeUnchangedObservation -> "assume-unchanged"
  SkipWorktreeObservation -> "skip-worktree"

renderWorktreeEntryKind :: WorktreeEntryKind -> Text
renderWorktreeEntryKind kind = case kind of
  WorktreeRegularFile -> "regular-file"
  WorktreeSymbolicLink -> "symbolic-link"
  WorktreeDirectory -> "directory"
  WorktreeOther -> "other"

renderPaths :: [FilePath] -> Text
renderPaths = Text.pack . show

snapshotFinding :: SnapshotProblem -> Finding
snapshotFinding problem = finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)

isRegistered :: SourceClass -> Bool
isRegistered (RegisteredLegacy _) = True
isRegistered _ = False

isSymlinkFacet :: SourceFacet -> Bool
isSymlinkFacet (SymbolicLinkFacet _) = True
isSymlinkFacet _ = False

isShebangFacet :: SourceFacet -> Bool
isShebangFacet (ShebangFacet _) = True
isShebangFacet _ = False

isForeignSignatureFacet :: SourceFacet -> Bool
isForeignSignatureFacet (ForeignSourceSignatureFacet _) = True
isForeignSignatureFacet _ = False

under :: FilePath -> FilePath -> Bool
under root path = Text.pack (root <> "/") `Text.isPrefixOf` Text.pack path

hasSuffix :: String -> FilePath -> Bool
hasSuffix suffix = Text.isSuffixOf (Text.pack suffix) . Text.pack

isProjectDeclaration :: FilePath -> Bool
isProjectDeclaration path =
  or
    [ retainedAmoebiusCabal path
    , retainedCabalProject path
    , retainedProbeCabal path
    , retainedGitignore path
    , retainedDockerignore path
    , retainedGitattributes path
    , retainedEditorconfig path
    ]

retainedAmoebiusCabal :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_AMOEBIUS_CABAL_REMOVAL_MUTANT)
retainedAmoebiusCabal _ = False
#else
retainedAmoebiusCabal = (== "amoebius.cabal")
#endif

retainedCabalProject :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_CABAL_PROJECT_REMOVAL_MUTANT)
retainedCabalProject _ = False
#else
retainedCabalProject = (== "cabal.project")
#endif

retainedProbeCabal :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_PROBE_CABAL_REMOVAL_MUTANT)
retainedProbeCabal _ = False
#else
retainedProbeCabal = (== "probe/probe.cabal")
#endif

retainedGitignore :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_GITIGNORE_REMOVAL_MUTANT)
retainedGitignore _ = False
#else
retainedGitignore = (== ".gitignore")
#endif

retainedDockerignore :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_DOCKERIGNORE_REMOVAL_MUTANT)
retainedDockerignore _ = False
#else
retainedDockerignore = (== ".dockerignore")
#endif

retainedGitattributes :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_GITATTRIBUTES_REMOVAL_MUTANT)
retainedGitattributes _ = False
#else
retainedGitattributes = (== ".gitattributes")
#endif

retainedEditorconfig :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PROJECT_EDITORCONFIG_REMOVAL_MUTANT)
retainedEditorconfig _ = False
#else
retainedEditorconfig = (== ".editorconfig")
#endif

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value =
    [ intToDigit
#if defined(VALIDATION_SOURCE_CLOSURE_HEX_HIGH_NIBBLE_MUTANT)
        0
#else
        (fromIntegral value `div` 16)
#endif
    , intToDigit
#if defined(VALIDATION_SOURCE_CLOSURE_HEX_LOW_NIBBLE_MUTANT)
        0
#else
        (fromIntegral value `mod` 16)
#endif
    ]

shebang :: ByteString -> Maybe Text
shebang bytes
  | "#!" `ByteString.isPrefixOf` bytes =
      Just (decodeLenient (ByteString.takeWhile (\byte -> byte /= 10 && byte /= 13) bytes))
  | otherwise = Nothing

foreignSourceSignature :: ByteString -> Maybe Text
foreignSourceSignature bytes =
  let line = Text.toLower (firstSignificantLine bytes)
      signatures =
        pythonFromSignature
          <> pythonDefSignature
          <> shellSetESignature
          <> shebangSignature
          <> javascriptFunctionSignature
          <> javascriptConstSignature
          <> jsonObjectSignature
          <> xmlDocumentSignature
          <> protoSchemaSignature
   in snd <$> firstMatch line signatures

pythonFromSignature, pythonDefSignature, shellSetESignature, shebangSignature :: [(Text, Text)]
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_PYTHON_FROM_REMOVAL_MUTANT)
pythonFromSignature = []
#else
pythonFromSignature = [("from ", "python-from")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_PYTHON_DEF_REMOVAL_MUTANT)
pythonDefSignature = []
#else
pythonDefSignature = [("def ", "python-def")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_SHELL_SET_E_REMOVAL_MUTANT)
shellSetESignature = []
#else
shellSetESignature = [("set -e", "shell-set-e")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_SHEBANG_REMOVAL_MUTANT)
shebangSignature = []
#else
shebangSignature = [("#!/", "shebang")]
#endif

javascriptFunctionSignature, javascriptConstSignature, jsonObjectSignature :: [(Text, Text)]
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_JAVASCRIPT_FUNCTION_REMOVAL_MUTANT)
javascriptFunctionSignature = []
#else
javascriptFunctionSignature = [("function ", "javascript-function")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_JAVASCRIPT_CONST_REMOVAL_MUTANT)
javascriptConstSignature = []
#else
javascriptConstSignature = [("const ", "javascript-const")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_JSON_OBJECT_REMOVAL_MUTANT)
jsonObjectSignature = []
#else
jsonObjectSignature = [("{\"", "json-object")]
#endif

xmlDocumentSignature, protoSchemaSignature :: [(Text, Text)]
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_XML_DOCUMENT_REMOVAL_MUTANT)
xmlDocumentSignature = []
#else
xmlDocumentSignature = [("<?xml", "xml-document")]
#endif
#if defined(VALIDATION_SOURCE_CLOSURE_SIGNATURE_PROTO_SCHEMA_REMOVAL_MUTANT)
protoSchemaSignature = []
#else
protoSchemaSignature = [("syntax =", "proto-schema")]
#endif

firstSignificantLine :: ByteString -> Text
firstSignificantLine bytes =
  case filter (not . Text.null) (map Text.strip (Text.lines (decodeLenient boundedBytes))) of
    [] -> ""
    line : _ -> line
 where
  boundedBytes = ByteString.take maximumRawSemanticLineBytes bytes

firstMatch :: Text -> [(Text, Text)] -> Maybe (Text, Text)
firstMatch _ [] = Nothing
firstMatch value (candidate : rest)
  | fst candidate `Text.isPrefixOf` value = Just candidate
  | otherwise = firstMatch value rest

textual :: ByteString -> Bool
textual bytes = rawTextualNulCheck bytes && rawTextualUtf8Check bytes

decodeLenient :: ByteString -> Text
decodeLenient = TextEncoding.decodeUtf8With TextError.lenientDecode

decodeOneLine :: ByteString -> Either Text FilePath
decodeOneLine bytes =
  case TextEncoding.decodeUtf8' (dropLineEnd bytes) of
    Left _ -> Left "Git output is not UTF-8"
    Right value
      | Text.null value -> Left "Git returned an empty line"
      | Text.any (== '\n') value || Text.any (== '\r') value -> Left "Git returned more than one line"
      | otherwise -> Right (Text.unpack value)

dropLineEnd :: ByteString -> ByteString
dropLineEnd = ByteString.reverse . ByteString.dropWhile (\byte -> byte == 10 || byte == 13) . ByteString.reverse

canonicalPath :: FilePath -> FilePath
canonicalPath = dropTrailingPathSeparator . normalise

duplicates :: Ord value => [value] -> [value]
duplicates values =
  Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(value, 1 :: Int) | value <- values]))

data ProcessBytes = ProcessBytes ExitCode ByteString ByteString

runGit :: GitExecutable -> FilePath -> [String] -> ByteString -> IO (Either SnapshotProblem ByteString)
runGit (GitExecutable executable) root arguments input = do
  let gitArguments =
        [ "--no-optional-locks"
        , "-c"
        , "core.fsmonitor=false"
        , "-c"
        , "core.untrackedCache=false"
        , "-c"
        , "core.excludesFile="
        , "-C"
        , root
        ]
          <> arguments
      gitEnvironment =
        [ ("GIT_OPTIONAL_LOCKS", "0")
        , ("GIT_TERMINAL_PROMPT", "0")
        , ("GIT_NO_REPLACE_OBJECTS", "1")
        , ("GIT_CONFIG_NOSYSTEM", "1")
        , ("GIT_CONFIG_GLOBAL", nullDevice)
        , ("GIT_ATTR_NOSYSTEM", "1")
        , ("LC_ALL", "C")
        ]
      command =
        (proc executable gitArguments)
          { std_in = CreatePipe
          , std_out = CreatePipe
          , std_err = CreatePipe
          , env = Just gitEnvironment
          }
  result <- try (captureProcess command input) :: IO (Either IOException ProcessBytes)
  pure $ case result of
    Left problem -> Left (GitProcessIoFailure arguments (Text.pack (displayException problem)))
    Right (ProcessBytes ExitSuccess output _) -> Right output
    Right (ProcessBytes (ExitFailure status) _ stderrBytes) ->
      Left (GitProcessFailure arguments status (decodeLenient stderrBytes))

nullDevice :: FilePath
#if defined(mingw32_HOST_OS)
nullDevice = "NUL"
#else
nullDevice = "/dev/null"
#endif

captureProcess :: CreateProcess -> ByteString -> IO ProcessBytes
captureProcess command input = do
  (inputHandle, outputHandle, errorHandle, processHandle) <- createProcess command
  stdin <- requirePipe "stdin" inputHandle
  stdout <- requirePipe "stdout" outputHandle
  stderr <- requirePipe "stderr" errorHandle
  inputResult <- newEmptyMVar
  outputResult <- newEmptyMVar
  errorResult <- newEmptyMVar
  _ <- forkIO (writePipe stdin input >>= putMVar inputResult)
  _ <- forkIO (readPipe stdout >>= putMVar outputResult)
  _ <- forkIO (readPipe stderr >>= putMVar errorResult)
  written <- takeMVar inputResult
  either ioError pure written
  output <- takeMVar outputResult
  errors <- takeMVar errorResult
  outputBytes <- either ioError pure output
  errorBytes <- either ioError pure errors
  -- Reap only after stdin has been closed and both output pipes have reached
  -- EOF.  Waiting first can deadlock a non-threaded runtime: Git's
  -- @hash-object --stdin@ waits for EOF while the Haskell writer has not yet
  -- been scheduled, or a verbose child blocks on an undrained output pipe.
  status <- waitForProcess processHandle
  pure (ProcessBytes status outputBytes errorBytes)

requirePipe :: String -> Maybe Handle -> IO Handle
requirePipe name Nothing = ioError (userError ("Git " <> name <> " pipe was not created"))
requirePipe _ (Just handle) = pure handle

writePipe :: Handle -> ByteString -> IO (Either IOException ())
writePipe handle bytes = try (ByteString.hPut handle bytes `finally` hClose handle)

readPipe :: Handle -> IO (Either IOException ByteString)
readPipe handle = try (ByteString.hGetContents handle `finally` hClose handle)
