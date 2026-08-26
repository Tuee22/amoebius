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
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , finding
  , observation
  )
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception (IOException, displayException, finally, try)
#if !defined(mingw32_HOST_OS)
import Control.Exception (bracket, onException)
#endif
import Control.Monad (foldM, forM)
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
import System.Exit (ExitCode (..))
import System.FilePath
  ( dropTrailingPathSeparator
  , isAbsolute
  , normalise
  , takeDirectory
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

-- The historical Git/descriptor acquisition implementation below is retained
-- only as package-hidden diagnostic work in progress.  Until streaming reads,
-- cumulative accounting, and traversal counters enforce every one of these
-- literals, all exported entry points refuse before spawning Git, opening a
-- descriptor, reading a blob, or enumerating a directory.
maximumInternalGitStdoutBytes, maximumInternalGitStderrBytes :: Int
maximumInternalGitStdoutBytes = 67108864
maximumInternalGitStderrBytes = 1048576

maximumInternalTrackedBlobBytes, maximumInternalAggregateBlobBytes :: Int
maximumInternalTrackedBlobBytes = 16777216
maximumInternalAggregateBlobBytes = 33554432

maximumInternalAuthoredEntries, maximumInternalAuthoredDepth, maximumInternalAuthoredPathBytes :: Int
maximumInternalAuthoredEntries = 16384
maximumInternalAuthoredDepth = 64
maximumInternalAuthoredPathBytes = 1024

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
    { checkName = "source-closure-diagnostic"
    , checkObservations =
        [ observation "source-closure.input-commitment.kind" inputCommitmentKind
        , observation "source-closure.input-commitment.sha256" inputCommitmentDigest
        , observation "source-closure.input.claimed-snapshot" (rawSafeClaimedIdentity claimedIdentity)
        , observation "source-closure.input.entry-count" (rawAnalysisEntryCount analysis)
        , observation "source-closure.input.aggregate-blob-bytes" (rawAnalysisAggregateBytes analysis)
        , observation "source-closure.derived.snapshot" (rawAnalysisComputedSnapshot analysis)
        , observation "source-closure.derived.classification-sha256" (rawAnalysisClassificationDigest analysis)
        , observation "source-closure.derived.haskell-count" (classCount 0)
        , observation "source-closure.derived.documentation-count" (classCount 1)
        , observation "source-closure.derived.project-count" (classCount 2)
        , observation "source-closure.derived.pb-debt-count" (classCount 3)
        , observation "source-closure.derived.legacy-count" (classCount 4)
        , observation "source-closure.derived.unregistered-count" (classCount 5)
        , observation "source-closure.preflight.problem-count" (rawAnalysisProblemCount analysis)
        , observation "source-closure.diagnostic-status" "refused"
        ]
    , checkFindings = boundedFindings
    }
 where
  rawEntries = [RawSourceEntry path mode objectIdentity bytes | (path, mode, objectIdentity, bytes) <- tuples]
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
            <> [ finding
                  "SOURCE-CLOSURE-RESULT-FINDING-LIMIT"
                  "<raw-source-closure>"
                  (rawLimitDetail maximumRawResultFindings observed <> rawCommitmentDetail inputCommitment)
               ]
    PrefixExceeded _ -> take maximumRawResultFindings candidateFindings

mandatoryRawSourceFindings :: RawInputCommitment -> [Finding]
mandatoryRawSourceFindings inputCommitment =
  diagnosticOnly <> custodyUnavailable <> completeDiscoveryUnavailable
 where
  diagnosticOnly =
#if defined(VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_BYPASS_MUTANT)
    []
#else
    [ finding
        "SOURCE-CLOSURE-DIAGNOSTIC-ONLY"
        "<raw-source-closure>"
        ("caller-supplied source inventory is diagnostic input and cannot mint source-closure evidence" <> rawCommitmentDetail inputCommitment)
    ]
#endif
  custodyUnavailable =
#if defined(VALIDATION_SOURCE_CLOSURE_CUSTODY_BYPASS_MUTANT)
    []
#else
    [ finding
        "SOURCE-CLOSURE-AUTHENTICATED-CUSTODY-UNAVAILABLE"
        "<raw-source-closure>"
        ("no authenticated network-independent source-custody authority is attached" <> rawCommitmentDetail inputCommitment)
    ]
#endif
  completeDiscoveryUnavailable =
#if defined(VALIDATION_SOURCE_CLOSURE_DISCOVERY_BYPASS_MUTANT)
    []
#else
    [ finding
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

analyzeBoundedRawSourceEntries :: Text -> [RawSourceEntry] -> RawSourceAnalysis
analyzeBoundedRawSourceEntries claimedIdentity entries =
  let entryCountText = Text.pack (show (length entries))
      resourceProblems = concat (zipWith rawEntryResourceProblems [1 ..] entries)
      aggregateResult = boundedRawAggregateBytes entries
      aggregateProblems = case aggregateResult of
        Left observed -> [RawAggregateBlobByteLimitExceeded maximumRawAggregateBlobBytes observed]
        Right _ -> []
      grammarProblems =
        if null resourceProblems && null aggregateProblems
          then rawIdentityGrammarProblems claimedIdentity <> concat (zipWith rawEntryGrammarProblems [1 ..] entries)
          else []
      inventoryProblems =
        if null resourceProblems && null aggregateProblems && null grammarProblems
          then rawInventoryProblems entries
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
        Left problems -> problems
        Right _ -> []
      trackedResult =
        if null formatProblems
          then traverse rawTrackedEntry entries
          else Nothing
      computedSnapshot = case (objectFormatResult, trackedResult) of
        (Right objectFormat, Just trackedEntries) -> computeSourceSnapshotIdentity objectFormat trackedEntries
        _ -> "unavailable"
      identityProblems =
        [ RawSnapshotIdentityMismatch computedSnapshot claimedIdentity
        | computedSnapshot /= "unavailable"
        , rawSnapshotIdentityMismatch claimedIdentity computedSnapshot
        ]
      allProblems =
        resourceProblems
          <> aggregateProblems
          <> grammarProblems
          <> inventoryProblems
          <> formatProblems
          <> identityProblems
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
  rawPortablePathProblems ordinal path
    <> [RawModeMalformed ordinal mode | not (rawModeValid mode)]
    <> objectShapeProblems
    <> objectContentProblems
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
    [40] -> Right GitObjectSha1
    [64] -> Right GitObjectSha256
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
            { indexPath = rawEntryPath entry
            , indexMode = mode
            , indexObjectId = rawEntryObjectIdentity entry
            }
      , trackedBytes = rawEntryBytes entry
      }

rawIndexMode :: Text -> Maybe IndexMode
rawIndexMode "100644" = Just RegularFile
rawIndexMode "100755" = Just ExecutableFile
rawIndexMode "120000" = Just SymbolicLink
rawIndexMode _ = Nothing

rawClosureFindings :: RawInputCommitment -> SourceClosure -> [Finding]
rawClosureFindings inputCommitment closure =
  localPathFindings <> boundPbFindings
 where
  localPathFindings =
    [ finding
        "SRC-UNREGISTERED"
        (indexPath (trackedIndex (classifiedEntry item)))
        (Text.intercalate "; " (classificationReasons item) <> rawCommitmentDetail inputCommitment)
    | item <- closurePaths closure
    , classifiedAs item == UnregisteredBehavioralSource
    ]
  boundPbFindings =
    [ problem
        { findingDetail = findingDetail problem <> rawCommitmentDetail inputCommitment
        }
    | (ordinal, problem) <- zip [1 ..] (checkFindings (closurePbBootstrapDiagnostic closure))
    , rawPbDiagnosticFindingRetained problem
    , rawPbFirstRuntimeFindingRetained ordinal problem
    ]

rawPbDiagnosticFindingRetained :: Finding -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PB_DIAGNOSTIC_RETENTION_DROP_MUTANT)
rawPbDiagnosticFindingRetained problem = findingCode problem /= "PB-GRAMMAR-DIAGNOSTIC-ONLY"
#else
rawPbDiagnosticFindingRetained _ = True
#endif

rawPbFirstRuntimeFindingRetained :: Int -> Finding -> Bool
#if defined(VALIDATION_SOURCE_CLOSURE_PB_FIRST_RUNTIME_RETENTION_DROP_MUTANT)
rawPbFirstRuntimeFindingRetained ordinal problem =
  ordinal /= 2 || findingCode problem /= "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
#else
rawPbFirstRuntimeFindingRetained _ _ = True
#endif

rawClassCounts :: SourceClosure -> [Text]
rawClassCounts closure = map (Text.pack . show) [haskellCount, documentCount, projectCount, pbCount, legacyCount, unregisteredCount]
 where
  classes = map classifiedAs (closurePaths closure)
  count predicate = length (filter predicate classes)
  haskellCount = count (== HaskellSource)
  documentCount = count (== DocumentationInput)
  projectCount = count (== ProjectDeclaration)
  pbCount = count (== RegisteredLegacy SourcePb)
  legacyCount = count isRegistered
  unregisteredCount = count (== UnregisteredBehavioralSource)

rawClassificationDigest :: SourceClosure -> Text
rawClassificationDigest closure = hex (SHA256.finalize finalContext)
 where
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-classification-v1\0"
  finalContext = foldl' updateClassifiedPath initialContext (closurePaths closure)
  updateClassifiedPath context item =
    foldl'
      updateLengthPrefixedText
      context
      [ Text.pack (indexPath indexed)
      , renderIndexMode (indexMode indexed)
      , indexObjectId indexed
      , renderSourceClass (classifiedAs item)
      , Text.intercalate "," (map renderSourceFacet (classificationFacets item))
      , Text.intercalate "; " (classificationReasons item)
      ]
   where
    indexed = trackedIndex (classifiedEntry item)

rawSourceInputDigest :: Text -> [RawSourceEntry] -> Text
rawSourceInputDigest claimedIdentity entries = hex (SHA256.finalize finalContext)
 where
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-input-v1\0"
  claimedContext = updateLengthPrefixedText initialContext claimedIdentity
  finalContext = foldl' updateRawEntry claimedContext entries
  updateRawEntry context entry =
    updateLengthPrefixedBytes blobContext (rawEntryBytes entry)
   where
    pathContext = updateLengthPrefixedText context (Text.pack (rawEntryPath entry))
    modeContext = updateLengthPrefixedText pathContext (rawEntryMode entry)
    blobContext = updateLengthPrefixedText modeContext (rawEntryObjectIdentity entry)

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
  initialContext = SHA256.update SHA256.init "amoebius-source-closure-bounded-refusal-v1\0"
  claimedPrefix = Text.take (maximumRawSnapshotIdentityBytes + 1) claimedIdentity
  claimedContext = updateLengthPrefixedText initialContext claimedPrefix
  entryState = case boundedPrefix maximumRawEntries entries of
    PrefixWithin values -> "within:" <> Text.pack (show (length values))
    PrefixExceeded observed -> "exceeded-at-least:" <> Text.pack (show observed)
  entryContext = updateLengthPrefixedText claimedContext entryState
  problemContext = foldl' updateLengthPrefixedText entryContext (map rawProblemCommitmentTag problems)

rawProblemCommitmentTag :: RawSourceProblem -> Text
rawProblemCommitmentTag problem = case problem of
  RawSnapshotIdentityByteLimitExceeded maximumValue observed -> numeric "identity-bytes" [maximumValue, observed]
  RawEntryLimitExceeded maximumValue observed -> numeric "entries" [maximumValue, observed]
  RawPathByteLimitExceeded ordinal maximumValue observed -> numeric "path-bytes" [ordinal, maximumValue, observed]
  RawPathDepthLimitExceeded ordinal maximumValue observed -> numeric "path-depth" [ordinal, maximumValue, observed]
  RawPathSegmentByteLimitExceeded ordinal maximumValue observed -> numeric "path-segment-bytes" [ordinal, maximumValue, observed]
  RawModeByteLimitExceeded ordinal maximumValue observed -> numeric "mode-bytes" [ordinal, maximumValue, observed]
  RawObjectIdentityByteLimitExceeded ordinal maximumValue observed -> numeric "object-id-bytes" [ordinal, maximumValue, observed]
  RawBlobByteLimitExceeded ordinal maximumValue observed -> numeric "blob-bytes" [ordinal, maximumValue, observed]
  RawAggregateBlobByteLimitExceeded maximumValue observed -> numeric "aggregate-blob-bytes" [maximumValue, observed]
  RawSemanticLineByteLimitExceeded ordinal maximumValue observed -> numeric "semantic-line-bytes" [ordinal, maximumValue, observed]
  RawSnapshotIdentityMalformed _ -> "snapshot-identity-unrepresentable"
  RawPathMalformed ordinal _ detail -> "path-unrepresentable:" <> Text.pack (show ordinal) <> ":" <> detail
  _ -> "bounded-non-resource-preflight"
 where
  numeric label values = label <> ":" <> Text.intercalate ":" (map (Text.pack . show) values)

updateLengthPrefixedText :: SHA256.Ctx -> Text -> SHA256.Ctx
updateLengthPrefixedText context = updateLengthPrefixedBytes context . TextEncoding.encodeUtf8

updateLengthPrefixedBytes :: SHA256.Ctx -> ByteString -> SHA256.Ctx
updateLengthPrefixedBytes context bytes = SHA256.update separatorContext bytes
 where
  lengthBytes = ByteString8.pack (show (ByteString.length bytes))
  lengthContext = SHA256.update context lengthBytes
  separatorContext = SHA256.update lengthContext ":"

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
  | code <= 0x7f = 1
  | code <= 0x7ff = 2
  | code <= 0xffff = 3
  | otherwise = 4
 where
  code = ord character

-- | Bound the complete scan needed to identify the first significant source
-- line.  A longer blob is admitted only when a non-blank physical line has
-- ended inside the prefix; classification never searches past this envelope.
boundedSignificantLineInspection :: Int -> ByteString -> Either Int Int
boundedSignificantLineInspection limit bytes = go 0 False (ByteString.take (limit + 1) bytes)
 where
  blobWithinLimit = ByteString.length bytes <= limit
  go consumed significant remaining = case ByteString.uncons remaining of
    Nothing
      | blobWithinLimit -> Right consumed
      | otherwise -> Left (limit + 1)
    Just (byte, rest)
      | consumed == limit -> Left (limit + 1)
      | byte == 10 || byte == 13 ->
          if significant
            then Right (consumed + 1)
            else go (consumed + 1) False rest
      | byte == 9 || byte == 32 -> go (consumed + 1) significant rest
      | otherwise -> go (consumed + 1) True rest

rawSourceProblemFinding :: RawInputCommitment -> RawSourceProblem -> Finding
rawSourceProblemFinding inputCommitment problem = case problem of
  RawSnapshotIdentityByteLimitExceeded maximumBytes observed ->
    resource "SOURCE-CLOSURE-IDENTITY-BYTE-LIMIT" "<claimed-snapshot>" maximumBytes observed
  RawEntryLimitExceeded maximumEntries observed ->
    resource "SOURCE-CLOSURE-ENTRY-LIMIT" "<raw-source-closure>" maximumEntries observed
  RawPathByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-PATH-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawPathDepthLimitExceeded ordinal maximumDepth observed ->
    resource "SOURCE-CLOSURE-PATH-DEPTH-LIMIT" (rawOrdinalSubject ordinal) maximumDepth observed
  RawPathSegmentByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-PATH-SEGMENT-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawModeByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-MODE-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawObjectIdentityByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-OBJECT-ID-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawBlobByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-BLOB-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawAggregateBlobByteLimitExceeded maximumBytes observed ->
    resource "SOURCE-CLOSURE-AGGREGATE-BLOB-BYTE-LIMIT" "<raw-source-closure>" maximumBytes observed
  RawSemanticLineByteLimitExceeded ordinal maximumBytes observed ->
    resource "SOURCE-CLOSURE-SEMANTIC-LINE-BYTE-LIMIT" (rawOrdinalSubject ordinal) maximumBytes observed
  RawSnapshotIdentityMalformed observed ->
    malformed "SOURCE-CLOSURE-IDENTITY-GRAMMAR" "<claimed-snapshot>" ("expected exactly 64 lowercase ASCII hexadecimal characters; observed=" <> observed)
  RawSnapshotIdentityMismatch expected observed ->
    malformed "SOURCE-CLOSURE-IDENTITY-MISMATCH" "<claimed-snapshot>" ("expected=" <> expected <> "; observed=" <> observed)
  RawEmptyInventory ->
    malformed "SOURCE-CLOSURE-INVENTORY-EMPTY" "<raw-source-closure>" "raw inventory must contain at least one tracked entry"
  RawPathMalformed ordinal path detail ->
    malformed "SOURCE-CLOSURE-PATH-GRAMMAR" (rawSafePathSubject ordinal path) detail
  RawModeMalformed ordinal observed ->
    malformed "SOURCE-CLOSURE-MODE-GRAMMAR" (rawOrdinalSubject ordinal) ("observed=" <> observed)
  RawObjectIdentityMalformed ordinal observed ->
    malformed "SOURCE-CLOSURE-OBJECT-ID-GRAMMAR" (rawOrdinalSubject ordinal) ("observed=" <> observed)
  RawObjectIdentityMismatch ordinal expected actual ->
    malformed "SOURCE-CLOSURE-OBJECT-ID-MISMATCH" (rawOrdinalSubject ordinal) ("expected=" <> expected <> "; recomputed=" <> actual)
  RawMixedObjectIdentityFormats widths ->
    malformed "SOURCE-CLOSURE-OBJECT-FORMAT-MIXED" "<raw-source-closure>" (Text.pack (show widths))
  RawDuplicatePath path ->
    malformed "SOURCE-CLOSURE-DUPLICATE-PATH" path "path occurs more than once"
  RawEntryOrderInvalid paths ->
    malformed
      "SOURCE-CLOSURE-ENTRY-ORDER"
      "<raw-source-closure>"
      ( "observed-count="
          <> Text.pack (show (length paths))
          <> "; first-two="
          <> Text.pack (show (take 2 paths))
      )
  RawPortableCaseCollision left right ->
    malformed "SOURCE-CLOSURE-PORTABLE-CASE-COLLISION" left ("collides with " <> Text.pack right)
  RawPortablePrefixConflict left right ->
    malformed "SOURCE-CLOSURE-PORTABLE-PREFIX-CONFLICT" left ("conflicts with " <> Text.pack right)
  RawProblemLimitExceeded maximumProblems observed ->
    resource "SOURCE-CLOSURE-PROBLEM-LIMIT" "<raw-source-closure>" maximumProblems observed
 where
  resource code subject maximumValue observed =
    finding code subject (rawLimitDetail maximumValue observed <> rawCommitmentDetail inputCommitment)
  malformed code subject detail = finding code subject (detail <> rawCommitmentDetail inputCommitment)

rawLimitDetail :: Int -> Int -> Text
rawLimitDetail maximumValue observed =
  "maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show observed)

rawCommitmentDetail :: RawInputCommitment -> Text
rawCommitmentDetail inputCommitment =
  "; source-closure.input-commitment-kind="
    <> rawInputCommitmentKind inputCommitment
    <> "; source-closure.input-commitment-sha256="
    <> rawInputCommitmentSha256 inputCommitment

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
-- to PATH, but this value is deliberately not candidate authority: absolute
-- path selection authenticates neither the executable nor its observations.
newtype GitExecutable = GitExecutable FilePath
  deriving (Eq, Ord, Show)

data IndexMode
  = RegularFile
  | ExecutableFile
  | SymbolicLink
  deriving (Eq, Ord, Show)

data GitObjectFormat
  = GitObjectSha1
  | GitObjectSha256
  deriving (Eq, Ord, Show)

-- | The two independent, NUL-delimited index-visibility observations used
-- during acquisition.  They are distinct because @git ls-files -v@ exposes
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

data IndexEntry = IndexEntry
  { indexPath :: FilePath
  , indexMode :: IndexMode
  , indexObjectId :: Text
  }
  deriving (Eq, Ord, Show)

data TrackedEntry = TrackedEntry
  { trackedIndex :: IndexEntry
  , trackedBytes :: ByteString
  }
  deriving (Eq, Ord, Show)

-- | The identity is a domain-separated SHA-256 digest of the independently
-- observed Git storage format and a canonical manifest containing mode, Git
-- object id, an independent SHA-256 commitment to the exact blob bytes, and
-- path for every stage-zero entry. Classification never consults mutable
-- worktree bytes.
data SourceSnapshot = SourceSnapshot
  { snapshotRoot :: FilePath
  , snapshotIdentity :: Text
  , snapshotEntries :: [TrackedEntry]
  }
  deriving (Eq, Show)

-- | Reserved candidate authority.  The constructor is deliberately private:
-- a caller may construct a 'SourceSnapshot' for pure diagnostics, but cannot
-- turn it into candidate evidence.  No caller-selected Git path constructs
-- this wrapper in the ordinary build; authenticated clean-room custody remains
-- explicit residue.
data AcquiredSourceSnapshot = AcquiredSourceSnapshot SourceSnapshot
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

data WorktreeAcquisitionObservation = WorktreeAcquisitionObservation
  { acquisitionObjectFormat :: GitObjectFormat
  , acquisitionTrackedEntries :: Map FilePath WorktreeEntryObservation
  , acquisitionAuthoredPaths :: Map FilePath WorktreeEntryKind
  }
  deriving (Eq, Show)

data SnapshotProblem
  = GitExecutableNotAbsolute FilePath
  | CallerSelectedGitDiagnosticOnly FilePath
  | SourceSnapshotAtomicityRequiresExternalObserver
  | RepositoryRootNotAbsolute FilePath
  | RepositoryRootMismatch FilePath FilePath
  | RepositoryHeadUnavailable Int Text
  | InvalidRepositoryHead Text
  | RepositoryHeadChangedDuringAcquisition Text Text
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
  | TrackedWorktreeChangedDuringAcquisition [FilePath]
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
  | AuthoredRootChangedDuringAcquisition [FilePath] [FilePath] [FilePath]
  | TrackedWorktreeDivergence [FilePath]
  | StagedIndexDivergence [FilePath]
  | UntrackedNonIgnoredPaths [FilePath]
  | IndexChangedDuringAcquisition
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
-- path partition, problem set, or snapshot identity around the acquisition
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

-- | Candidate acquisition entry point retained for the closed dispatcher.
-- A caller-selected absolute Git executable is sufficient for diagnostics but
-- cannot authenticate its own observations, and sequential HEAD/index reads do
-- not establish atomic clean-room custody.  Consequently the ordinary branch
-- can never construct 'AcquiredSourceSnapshot'.
loadGitSnapshot :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] AcquiredSourceSnapshot)
loadGitSnapshot git@(GitExecutable diagnosticExecutable) root =
  case internalAcquisitionEnvelopeProblems of
    problems@(_ : _) ->
      pure
        ( Left
            ( [ CallerSelectedGitDiagnosticOnly diagnosticExecutable
              , SourceSnapshotAtomicityRequiresExternalObserver
              ]
                <> problems
            )
        )
    [] -> do
      -- This branch is deliberately unreachable until every literal envelope
      -- above has a streaming implementation.  Keeping the diagnostic body
      -- typechecked does not make it candidate authority.
      diagnostic <- loadGitSnapshotDiagnostic git root
      pure $ case diagnostic of
        Left problems -> Left problems
        Right _ ->
          Left
            [ CallerSelectedGitDiagnosticOnly diagnosticExecutable
            , SourceSnapshotAtomicityRequiresExternalObserver
            ]

-- | Acquire a diagnostic snapshot from a caller-selected Git executable.  The
-- exact stage-zero index, referenced blobs, worktree, authored-root inventory,
-- object format, and HEAD are checked for internal consistency, but the result
-- intentionally carries no candidate authority.
loadGitSnapshotDiagnostic :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadGitSnapshotDiagnostic _ root | not (isAbsolute root) = pure (Left [RepositoryRootNotAbsolute root])
loadGitSnapshotDiagnostic git root = case internalAcquisitionEnvelopeProblems of
  problems@(_ : _) -> pure (Left problems)
  [] -> loadGitSnapshotDiagnosticUnchecked git root

loadGitSnapshotDiagnosticUnchecked :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadGitSnapshotDiagnosticUnchecked git root
  | not (isAbsolute root) = pure (Left [RepositoryRootNotAbsolute root])
  | otherwise = do
      topResult <- runGit git root ["rev-parse", "--show-toplevel"] ByteString.empty
      case topResult of
        Left problem -> pure (Left [problem])
        Right topBytes ->
          case decodeOneLine topBytes of
            Left detail -> pure (Left [GitProcessIoFailure ["rev-parse", "--show-toplevel"] detail])
            Right top
              | canonicalPath top /= canonicalPath root ->
                  pure (Left [RepositoryRootMismatch root top])
              | otherwise -> do
                  initialHeadResult <- observeRepositoryHead git root
                  case initialHeadResult of
                    Left problem -> pure (Left [problem])
                    Right initialHead -> do
                      workspaceProblems <- checkGitReportedWorkspaceDiagnostic git root
                      if null workspaceProblems
                        then loadIndexDiagnostic git root initialHead
                        else pure (Left workspaceProblems)

loadIndexDiagnostic
  :: GitExecutable
  -> FilePath
  -> Text
  -> IO (Either [SnapshotProblem] SourceSnapshot)
loadIndexDiagnostic git root initialHead = do
  formatResult <- observeRepositoryObjectFormat git root
  case formatResult of
    Left problem -> pure (Left [problem])
    Right objectFormat -> loadIndexWithFormatDiagnostic git root initialHead objectFormat

loadIndexWithFormatDiagnostic
  :: GitExecutable
  -> FilePath
  -> Text
  -> GitObjectFormat
  -> IO (Either [SnapshotProblem] SourceSnapshot)
loadIndexWithFormatDiagnostic git root initialHead objectFormat = do
  listing <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "--stage", "-z"]
      ByteString.empty
  case listing of
    Left problem -> pure (Left [problem])
    Right raw -> case parseLsFilesStage raw of
      Left problems -> pure (Left problems)
      Right entries ->
        case indexObjectFormatProblems objectFormat entries of
          problems@(_ : _) -> pure (Left problems)
          [] -> do
            blobs <- loadBlobs git root entries
            case blobs of
              Left problems -> pure (Left problems)
              Right byObject -> case traverse (attachLoadedBlob byObject) entries of
                Left problem -> pure (Left [problem])
                Right tracked -> do
                  let diagnosticSnapshot =
                        SourceSnapshot
                          { snapshotRoot = root
                          , snapshotIdentity = computeSourceSnapshotIdentity objectFormat tracked
                          , snapshotEntries = tracked
                          }
                  beforeResult <- observeAcquisitionBoundary git root entries tracked
                  case beforeResult of
                    Left problems -> pure (Left problems)
                    Right before
                      | formatProblems@(_ : _) <-
                          objectFormatBoundaryProblems objectFormat (acquisitionObjectFormat before) ->
                          pure (Left formatProblems)
                    Right before -> do
                      workspaceProblems <- checkGitReportedWorkspaceDiagnostic git root
                      afterResult <- observeAcquisitionBoundary git root entries tracked
                      finalFormatResult <- observeRepositoryObjectFormat git root
                      -- These are deliberately the final Git observations. The
                      -- exact index listing precedes the final HEAD read; the
                      -- candidate seam still refuses because sequential reads
                      -- cannot prove atomicity without an external observer.
                      finalIndexProblems <- observeFinalIndexVisibility git root entries
                      finalHeadResult <- observeRepositoryHead git root
                      let (afterProblems, boundaryProblems) = case afterResult of
                            Left problems -> (problems, [])
                            Right after -> ([], compareAcquisitionBoundaries before after)
                          formatProblems = case finalFormatResult of
                            Left problem -> [problem]
                            Right finalFormat -> objectFormatBoundaryProblems objectFormat finalFormat
                          headProblems = case finalHeadResult of
                            Left problem -> [problem]
                            Right finalHead -> repositoryHeadBoundaryProblemsDiagnostic initialHead finalHead
                          finalProblems =
                            workspaceProblems
                              <> afterProblems
                              <> boundaryProblems
                              <> formatProblems
                              <> finalIndexProblems
                              <> headProblems
                      pure $
                        if null finalProblems
                          then Right diagnosticSnapshot
                          else Left finalProblems

internalAcquisitionEnvelopeProblems :: [SnapshotProblem]
internalAcquisitionEnvelopeProblems =
  [ internalGitCaptureEnvelopeProblem
  , internalTrackedReadEnvelopeProblem
  , internalAuthoredTraversalEnvelopeProblem
  ]

internalGitCaptureEnvelopeProblem :: SnapshotProblem
internalGitCaptureEnvelopeProblem =
  InternalGitCaptureEnvelopeUnavailable
    maximumInternalGitStdoutBytes
    maximumInternalGitStderrBytes

internalTrackedReadEnvelopeProblem :: SnapshotProblem
internalTrackedReadEnvelopeProblem =
  InternalTrackedReadEnvelopeUnavailable
    maximumInternalTrackedBlobBytes
    maximumInternalAggregateBlobBytes

internalAuthoredTraversalEnvelopeProblem :: SnapshotProblem
internalAuthoredTraversalEnvelopeProblem =
  InternalAuthoredTraversalEnvelopeUnavailable
    maximumInternalAuthoredEntries
    maximumInternalAuthoredDepth
    maximumInternalAuthoredPathBytes

observeRepositoryObjectFormat
  :: GitExecutable
  -> FilePath
  -> IO (Either SnapshotProblem GitObjectFormat)
observeRepositoryObjectFormat git root = do
  result <- runGit git root ["rev-parse", "--show-object-format=storage"] ByteString.empty
  pure $ case result of
    Left problem -> Left problem
    Right bytes -> case decodeOneLine bytes of
      Right "sha1" -> Right GitObjectSha1
      Right "sha256" -> Right GitObjectSha256
      Right value -> Left (UnsupportedRepositoryObjectFormat (Text.pack value))
      Left detail -> Left (UnsupportedRepositoryObjectFormat detail)

-- | Compare independently acquired storage-format observations.  Acquisition
-- currently refuses at its resource envelope, so this unreachable helper is
-- intentionally not a selectable changed-production subject.
objectFormatBoundaryProblems :: GitObjectFormat -> GitObjectFormat -> [SnapshotProblem]
objectFormatBoundaryProblems before after =
  [RepositoryObjectFormatChanged before after | before /= after]

-- | Compare the exact commit identities observed at the acquisition boundary.
-- This is a diagnostic race detector, not proof that HEAD could not change and
-- change back between sequential observations.
repositoryHeadBoundaryProblemsDiagnostic :: Text -> Text -> [SnapshotProblem]
repositoryHeadBoundaryProblemsDiagnostic before after =
  [RepositoryHeadChangedDuringAcquisition before after | before /= after]

attachLoadedBlob :: Map Text ByteString -> IndexEntry -> Either SnapshotProblem TrackedEntry
attachLoadedBlob byObject entry =
  case Map.lookup (indexObjectId entry) byObject of
    Nothing -> Left (MissingLoadedBlob (indexObjectId entry))
    Just bytes -> Right (TrackedEntry entry bytes)

-- | Observe every acquisition boundary which Git's ordinary dirty-worktree
-- summary can conceal: index visibility flags, raw worktree bytes/kinds/modes,
-- and recursively discovered material outside Git's control root.  Generated
-- state roots are not silently excluded: their kind is observed without
-- following links and their presence refuses until an external clean-room
-- observer can prove run-local ownership and freshness.
observeAcquisitionBoundary
  :: GitExecutable
  -> FilePath
  -> [IndexEntry]
  -> [TrackedEntry]
  -> IO (Either [SnapshotProblem] WorktreeAcquisitionObservation)
observeAcquisitionBoundary git root entries tracked = do
  formatResult <- observeRepositoryObjectFormat git root
  flagProblems <- observeIndexVisibility git root entries
  trackedResult <- observeTrackedWorktree root tracked
  authoredResult <- inventoryAuthoredPaths root
  let (formatObservationProblems, formatValue) = case formatResult of
        Left problem -> ([problem], Nothing)
        Right value -> ([], Just value)
      (trackedObservationProblems, trackedValues) = case trackedResult of
        Left foundProblems -> (foundProblems, Nothing)
        Right values -> ([], Just values)
      (authoredObservationProblems, authoredValues) = case authoredResult of
        Left foundProblems -> (foundProblems, Nothing)
        Right values ->
          let expectedLeaves = Set.fromList (map indexPath entries)
              expectedAncestors = Set.fromList (concatMap (trackedPathParents . indexPath) entries)
              expectedPaths = expectedLeaves `Set.union` expectedAncestors
              unexpected = Set.toAscList (Map.keysSet values `Set.difference` expectedPaths)
              wrongAncestors =
                [ AuthoredRootAncestorKindMismatch path observedKind
                | path <- Set.toAscList expectedAncestors
                , Just observedKind <- [Map.lookup path values]
                , observedKind /= WorktreeDirectory
                ]
              foundProblems =
                wrongAncestors
                  <> [UnexpectedAuthoredRootMaterial unexpected | not (null unexpected)]
           in (foundProblems, Just values)
      allProblems =
        formatObservationProblems
          <> flagProblems
          <> trackedObservationProblems
          <> authoredObservationProblems
  pure $ case (allProblems, formatValue, trackedValues, authoredValues) of
    ([], Just objectFormat, Just trackedObservation, Just authoredObservation) ->
      Right
        WorktreeAcquisitionObservation
          { acquisitionObjectFormat = objectFormat
          , acquisitionTrackedEntries = trackedObservation
          , acquisitionAuthoredPaths = authoredObservation
          }
    _ -> Left allProblems

compareAcquisitionBoundaries
  :: WorktreeAcquisitionObservation
  -> WorktreeAcquisitionObservation
  -> [SnapshotProblem]
compareAcquisitionBoundaries before after = formatProblems <> trackedProblems <> authoredProblems
 where
  formatProblems =
    objectFormatBoundaryProblems
      (acquisitionObjectFormat before)
      (acquisitionObjectFormat after)
  beforeTracked = acquisitionTrackedEntries before
  afterTracked = acquisitionTrackedEntries after
  changedTracked =
    Set.toAscList
      ( Set.fromList
          [ path
          | path <- Set.toAscList (Map.keysSet beforeTracked `Set.union` Map.keysSet afterTracked)
          , Map.lookup path beforeTracked /= Map.lookup path afterTracked
          ]
      )
  trackedProblems = [TrackedWorktreeChangedDuringAcquisition changedTracked | not (null changedTracked)]
  beforeAuthored = acquisitionAuthoredPaths before
  afterAuthored = acquisitionAuthoredPaths after
  commonAuthored = Map.keysSet beforeAuthored `Set.intersection` Map.keysSet afterAuthored
  added = Set.toAscList (Map.keysSet afterAuthored `Set.difference` Map.keysSet beforeAuthored)
  removed = Set.toAscList (Map.keysSet beforeAuthored `Set.difference` Map.keysSet afterAuthored)
  changed =
    [ path
    | path <- Set.toAscList commonAuthored
    , Map.lookup path beforeAuthored /= Map.lookup path afterAuthored
    ]
  authoredProblems =
    [ AuthoredRootChangedDuringAcquisition added removed changed
    | not (null added) || not (null removed) || not (null changed)
    ]

observeIndexVisibility :: GitExecutable -> FilePath -> [IndexEntry] -> IO [SnapshotProblem]
observeIndexVisibility git root entries = do
  assumeResult <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "-v", "-z"]
      ByteString.empty
  skipResult <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "-t", "-z"]
      ByteString.empty
  let expected = sort (map indexPath entries)
  pure
    ( taggedObservationProblems AssumeUnchangedObservation expected isAssumeUnchanged assumeResult
        <> taggedObservationProblems SkipWorktreeObservation expected isSkipWorktree skipResult
    )

-- | Make the final index observation one tagged stage listing.  The @-v@ tag
-- retains @S@ for skip-worktree and lower-cases every assume-unchanged tag, so
-- this one NUL-delimited stream binds both visibility flags to the exact mode,
-- object id, stage, and path inventory observed at the end of acquisition.
observeFinalIndexVisibility :: GitExecutable -> FilePath -> [IndexEntry] -> IO [SnapshotProblem]
observeFinalIndexVisibility git root expected = do
  result <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "--stage", "-v", "-z"]
      ByteString.empty
  pure $ case result of
    Left problem -> [problem]
    Right raw -> case parseLsFilesTaggedStage raw of
      Left problems -> problems
      Right tagged ->
        let actual = map snd tagged
            expectedPaths = sort (map indexPath expected)
            actualPaths = sort (map indexPath actual)
            inventoryProblems =
              [ IndexFlagInventoryMismatch AssumeUnchangedObservation expectedPaths actualPaths
              | expectedPaths /= actualPaths
              ]
            indexProblems = finalIndexBoundaryProblemsDiagnostic expected actual
            assumeUnchanged = sort [indexPath entry | (tag, entry) <- tagged, isAssumeUnchanged tag]
            skipWorktree = sort [indexPath entry | (tag, entry) <- tagged, isSkipWorktree tag]
            flagProblems =
              [AssumeUnchangedTrackedPaths assumeUnchanged | not (null assumeUnchanged)]
                <> [SkipWorktreeTrackedPaths skipWorktree | not (null skipWorktree)]
         in inventoryProblems <> indexProblems <> flagProblems

-- | Compare complete canonical stage-zero entries.  In particular, retaining
-- the same path while changing only its object id or mode is a boundary change.
finalIndexBoundaryProblemsDiagnostic :: [IndexEntry] -> [IndexEntry] -> [SnapshotProblem]
finalIndexBoundaryProblemsDiagnostic expected actual =
  [ IndexChangedDuringAcquisition
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

taggedObservationProblems
  :: IndexFlagObservation
  -> [FilePath]
  -> (Char -> Bool)
  -> Either SnapshotProblem ByteString
  -> [SnapshotProblem]
taggedObservationProblems _ _ _ (Left problem) = [problem]
taggedObservationProblems observationKind expected isFlagged (Right bytes) =
  case parseLsFilesTaggedPaths observationKind bytes of
    Left problems -> problems
    Right tagged ->
      let actual = sort (map snd tagged)
          inventoryProblems =
            [IndexFlagInventoryMismatch observationKind expected actual | expected /= actual]
          flagged = sort [path | (tag, path) <- tagged, isFlagged tag]
          flagProblems = case observationKind of
            AssumeUnchangedObservation -> [AssumeUnchangedTrackedPaths flagged | not (null flagged)]
            SkipWorktreeObservation -> [SkipWorktreeTrackedPaths flagged | not (null flagged)]
       in inventoryProblems <> flagProblems

isAssumeUnchanged :: Char -> Bool
isAssumeUnchanged tag = tag >= 'a' && tag <= 'z'

isSkipWorktree :: Char -> Bool
isSkipWorktree tag = tag == 'S' || tag == 's'

observeTrackedWorktree
  :: FilePath
  -> [TrackedEntry]
  -> IO (Either [SnapshotProblem] (Map FilePath WorktreeEntryObservation))
observeTrackedWorktree root entries = do
  results <- forM entries (observeTrackedEntry root)
  let problems = concat [items | Left items <- results]
      observations = [item | Right item <- results]
  pure $
    if null problems
      then Right (Map.fromList observations)
      else Left problems

observeTrackedEntry
  :: FilePath
  -> TrackedEntry
  -> IO (Either [SnapshotProblem] (FilePath, WorktreeEntryObservation))
observeTrackedEntry root entry = do
  let indexed = trackedIndex entry
      path = indexPath indexed
      absolute = root </> path
  result <- readWorktreeEntry root path absolute
  pure $ case result of
    Left problem -> Left [problem]
    Right observed ->
      let comparisonProblems = compareTrackedEntry entry observed
       in if null comparisonProblems then Right (path, observed) else Left comparisonProblems

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
-- acquisition. It carries no path, bytes, or acquisition authority.
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

compareTrackedEntry :: TrackedEntry -> WorktreeEntryObservation -> [SnapshotProblem]
compareTrackedEntry entry observed = kindProblems <> executableProblems <> byteProblems
 where
  indexed = trackedIndex entry
  path = indexPath indexed
  expectedMode = indexMode indexed
  expectedKind = case expectedMode of
    RegularFile -> WorktreeRegularFile
    ExecutableFile -> WorktreeRegularFile
    SymbolicLink -> WorktreeSymbolicLink
  expectedExecutable = expectedMode == ExecutableFile
  actualKind = worktreeObservedKind observed
  kindProblems = [TrackedWorktreeKindMismatch path expectedMode actualKind | actualKind /= expectedKind]
  executableProblems =
    [ TrackedWorktreeExecutableMismatch path expectedExecutable (worktreeObservedExecutable observed)
    | actualKind == WorktreeRegularFile
    , worktreeObservedExecutable observed /= expectedExecutable
    ]
  byteProblems =
    [ TrackedWorktreeBytesMismatch path
    | actualKind `elem` [WorktreeRegularFile, WorktreeSymbolicLink]
    , worktreeObservedBytes observed /= trackedBytes entry
    ]

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

trackedPathParents :: FilePath -> [FilePath]
trackedPathParents path = go (takeDirectory path)
 where
  go parent
    | null parent || parent == "." || parent == path = []
    | otherwise = parent : go (takeDirectory parent)

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
-- and cannot be candidate authority. Full acquisition additionally performs
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

loadBlobs
  :: GitExecutable
  -> FilePath
  -> [IndexEntry]
  -> IO (Either [SnapshotProblem] (Map Text ByteString))
loadBlobs git root entries =
  foldM loadOne (Right Map.empty) (Set.toAscList objectIds)
  where
    objectIds = Set.fromList (map indexObjectId entries)
    loadOne (Left problems) _ = pure (Left problems)
    loadOne (Right loaded) objectId = do
      bytes <- runGit git root ["cat-file", "blob", Text.unpack objectId] ByteString.empty
      pure $ case bytes of
        Left problem -> Left [problem]
        Right value -> case verifyBlobObjectId objectId value of
          Left problem -> Left [problem]
          Right () -> Right (Map.insert objectId value loaded)

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
  ordered = sortOn (indexPath . trackedIndex) entries
  domainContext = SHA256.update SHA256.init "amoebius-source-snapshot-v2\0"
  formatContext = updateSnapshotFormat domainContext objectFormat
  formatSeparatorContext = SHA256.update formatContext "\0"
  finalContext = foldl' updateSnapshotMember formatSeparatorContext ordered

updateSnapshotFormat :: SHA256.Ctx -> GitObjectFormat -> SHA256.Ctx
#if defined(VALIDATION_SOURCE_CLOSURE_SNAPSHOT_FORMAT_COMMITMENT_MUTANT)
updateSnapshotFormat context _ = context
#else
updateSnapshotFormat context = SHA256.update context . TextEncoding.encodeUtf8 . renderGitObjectFormat
#endif

updateSnapshotMember :: SHA256.Ctx -> TrackedEntry -> SHA256.Ctx
updateSnapshotMember initialContext trackedEntry = SHA256.update pathContext "\0"
 where
  indexEntry = trackedIndex trackedEntry
  modeContext = SHA256.update initialContext (TextEncoding.encodeUtf8 (snapshotModeCommitment indexEntry))
  modeSeparatorContext = SHA256.update modeContext "\0"
  objectContext = SHA256.update modeSeparatorContext (TextEncoding.encodeUtf8 (snapshotObjectCommitment indexEntry))
  objectSeparatorContext = SHA256.update objectContext "\0"
  blobContext = SHA256.update objectSeparatorContext (TextEncoding.encodeUtf8 (snapshotBlobByteCommitment trackedEntry))
  blobSeparatorContext = SHA256.update blobContext "\0"
  pathContext = SHA256.update blobSeparatorContext (TextEncoding.encodeUtf8 (snapshotPathCommitment indexEntry))

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

indexObjectFormatProblems :: GitObjectFormat -> [IndexEntry] -> [SnapshotProblem]
indexObjectFormatProblems objectFormat entries =
  [ IndexObjectFormatMismatch objectFormat mismatches
  | let expectedWidth = case objectFormat of
          GitObjectSha1 -> 40
          GitObjectSha256 -> 64
        mismatches =
          [ (indexPath entry, indexObjectId entry)
          | entry <- entries
          , Text.length (indexObjectId entry) /= expectedWidth
          ]
  , not (null mismatches)
  ]

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
    pbEntries =
      [ toPbTrackedFile entry
      | entry <- snapshotEntries snapshot
      , under canonicalPbRoot (pathOf entry)
      ]
    pbAdmission = Pb.pbBootstrapGrammarDiagnostic pbEntries
    -- A caller-supplied refusal diagnostic is not source-custody authority.
    -- The bounded pb exception remains registered migration debt until a
    -- separately authenticated opaque acquisition boundary can consume it.
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
  ( indexPath indexed
  , case indexMode indexed of
      RegularFile -> "100644"
      ExecutableFile -> "100755"
      SymbolicLink -> "120000"
  , trackedBytes entry
  )
 where
  indexed = trackedIndex entry

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
    reasons = primaryReasons initial path bytes <> structuralReasons <> signatureReasons
    finalClass
      | isRegistered initial = initial
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

admittedDocumentationPath :: FilePath -> Bool
admittedDocumentationPath path =
  path `Set.member` canonicalGovernedDocumentationPaths

-- | Closed, reviewed path-to-role inventory for non-behavioural Markdown.
-- A newly named file is unregistered until this Haskell declaration and the
-- independent documentation-corpus manifest are both updated. Bytes still
-- require structural checking, compiler-resolved consumer closure, and human
-- semantic custody; this path list never claims that prose is non-behavioural.
canonicalGovernedDocumentationPaths :: Set FilePath
canonicalGovernedDocumentationPaths =
  Set.fromList
    [ "AGENTS.md"
    , "CLAUDE.md"
    , "DEVELOPMENT_PLAN/README.md"
    , "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
    , "DEVELOPMENT_PLAN/development_plan_phase_model.md"
    , "DEVELOPMENT_PLAN/development_plan_standards.md"
    , "DEVELOPMENT_PLAN/later_phases.md"
    , "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
    , "DEVELOPMENT_PLAN/overview.md"
    , "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
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
    , "DEVELOPMENT_PLAN/substrates.md"
    , "DEVELOPMENT_PLAN/system_components.md"
    , "README.md"
    , "documents/README.md"
    , "documents/documentation_standards.md"
    , "documents/engineering/README.md"
    , "documents/engineering/app_vs_deployment_doctrine.md"
    , "documents/engineering/apple_metal_headless_builds.md"
    , "documents/engineering/backup_recovery_doctrine.md"
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
    , "documents/engineering/tla_modelling_assumptions.md"
    , "documents/engineering/ui_realtime_coordination_doctrine.md"
    , "documents/engineering/validation_frame_doctrine.md"
    , "documents/engineering/vault_pki_doctrine.md"
    , "documents/engineering/workflow_calculus_doctrine.md"
    , "documents/glossary.md"
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
    , "documents/reading_order.md"
    ]
#if defined(VALIDATION_SOURCE_CLOSURE_DOCUMENT_INVENTORY_WIDEN_MUTANT)
    `Set.union` Set.singleton "documents/renamed_program.md"
#endif

entryFacets :: TrackedEntry -> [SourceFacet]
entryFacets entry = modeFacets <> shebangFacets <> contentFacets
  where
    bytes = trackedBytes entry
    modeFacets = case indexMode (trackedIndex entry) of
      RegularFile -> []
      ExecutableFile -> [ExecutableModeFacet]
      SymbolicLink -> [SymbolicLinkFacet (decodeLenient bytes)]
    shebangFacets = maybe [] (pure . ShebangFacet) (shebang bytes)
    contentFacets
      | ByteString.elem 0 bytes = [BinaryContentFacet]
      | otherwise = maybe [] (pure . ForeignSourceSignatureFacet) (foreignSourceSignature bytes)

disallowedStructure :: SourceClass -> [SourceFacet] -> [Text]
disallowedStructure sourceClass facets
  | isRegistered sourceClass = []
  | otherwise =
      concat
        [ ["tracked executable mode is not an authored-source role" | retainedExecutableFacetRefusal facets]
        , ["tracked symbolic links are not admitted source" | retainedSymlinkFacetRefusal facets]
        , ["tracked binary bytes are not admitted source" | retainedBinaryFacetRefusal facets]
        , ["a shebang may not disguise an authored source role" | retainedShebangFacetRefusal facets]
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
  | sourceClass == UnregisteredBehavioralSource = ["path has no admitted authored-source class"]
  | retainedInvalidUtf8Refusal bytes = ["authored text is not valid UTF-8"]
  | sourceClass == HaskellSource && retainedHaskellForeignSignatureRefusal facets =
      [".hs bytes begin with a foreign-language source signature"]
  | sourceClass `elem` [DocumentationInput, ProjectDeclaration]
      && retainedNoncodeForeignSignatureRefusal facets =
      ["an admitted non-code input begins with a behavioral-source signature"]
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
  ["pb authorization requires the complete exact snapshot-level grammar"]
primaryReasons UnregisteredBehavioralSource _ _ = ["no closed-grammar class matched"]
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
      "caller-supplied source closure is diagnostic input, not candidate acquisition authority"
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
-- correctness evidence. Legacy compares it with a separately reviewed Haskell
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

renderSourceDebtId :: SourceDebtId -> Text
renderSourceDebtId SourceTools = "LTD-SRC-001"
renderSourceDebtId SourceDhall = "LTD-SRC-002"
renderSourceDebtId SourceProto = "LTD-SRC-003"
renderSourceDebtId SourceUi = "LTD-SRC-004"
renderSourceDebtId SourcePulumi = "LTD-SRC-005"
renderSourceDebtId SourceTest = "LTD-SRC-006"
renderSourceDebtId SourceProbe = "LTD-SRC-007"
renderSourceDebtId SourcePb = "LTD-SRC-008"
renderSourceDebtId SourceVendor = "LTD-SRC-009"

renderSourceClass :: SourceClass -> Text
renderSourceClass HaskellSource = "haskell"
renderSourceClass DocumentationInput = "documentation"
renderSourceClass ProjectDeclaration = "project-declaration"
renderSourceClass (RegisteredLegacy identifier) = "registered:" <> renderSourceDebtId identifier
renderSourceClass UnregisteredBehavioralSource = "unregistered"

renderIndexMode :: IndexMode -> Text
renderIndexMode RegularFile = "100644"
renderIndexMode ExecutableFile = "100755"
renderIndexMode SymbolicLink = "120000"

renderGitObjectFormat :: GitObjectFormat -> Text
renderGitObjectFormat GitObjectSha1 = "sha1"
renderGitObjectFormat GitObjectSha256 = "sha256"

renderSourceFacet :: SourceFacet -> Text
renderSourceFacet ExecutableModeFacet = "executable"
renderSourceFacet (ShebangFacet value) = "shebang=" <> value
renderSourceFacet (SymbolicLinkFacet value) = "symlink=" <> value
renderSourceFacet BinaryContentFacet = "binary"
renderSourceFacet (ForeignSourceSignatureFacet value) = "foreign-signature=" <> value

renderSnapshotProblem :: SnapshotProblem -> Text
renderSnapshotProblem problem = case problem of
  GitExecutableNotAbsolute path -> "Git executable is not absolute: " <> Text.pack path
  CallerSelectedGitDiagnosticOnly path ->
    "caller-selected Git is diagnostic-only and cannot mint candidate authority: " <> Text.pack path
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
  RepositoryHeadChangedDuringAcquisition before after ->
    "repository HEAD changed during acquisition: " <> before <> " -> " <> after
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
    "Git repository storage object format changed during acquisition: before="
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
  TrackedWorktreeChangedDuringAcquisition paths ->
    "tracked worktree observation changed during acquisition: " <> renderPaths paths
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
  AuthoredRootChangedDuringAcquisition added removed changed ->
    "authored-root inventory changed during acquisition: added="
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
  IndexChangedDuringAcquisition -> "Git index changed during snapshot acquisition"
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
    [ intToDigit (fromIntegral value `div` 16)
    , intToDigit (fromIntegral value `mod` 16)
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
textual bytes = not (ByteString.elem 0 bytes) && either (const False) (const True) (TextEncoding.decodeUtf8' bytes)

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
