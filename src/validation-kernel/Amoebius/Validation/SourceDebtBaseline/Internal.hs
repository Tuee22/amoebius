{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceDebtBaseline.Internal
  ( SourceDebtEvidence
  , analyzeAcquiredSourceDebt
  , foldAcquiredSourceDebtState
  , sourceDebtClosureDiagnosticCheck
  , sourceDebtEvidenceCheck
  , sourceDebtRawDiagnosticCheck
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
  , renderSourceDebtId
  , snapshotIdentity
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
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

data SourceDebtBaseline = SourceDebtBaseline Int Text Text
  deriving (Eq, Ord, Show)

data SourceDebtObservation = SourceDebtObservation Int Text Text
  deriving (Eq, Ord, Show)

data SourceDebtProblem
  = SourceDebtBaselineFamilySetMismatch (Set SourceDebtId) (Set SourceDebtId)
  | SourceDebtFamilySetMismatch (Set SourceDebtId) (Set SourceDebtId)
  | SourcePbObservationPresent SourceDebtObservation
  | SourceDebtPathCountMismatch SourceDebtId Int Int
  | SourceDebtFingerprintMismatch SourceDebtId Text Text
  | SourceDebtPathInventoryDigestMismatch SourceDebtId Text Text
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
#if defined(VALIDATION_SOURCE_DEBT_OBSERVATION_LIMIT_WIDEN_MUTANT)
maximumSourceDebtObservations = 27
#else
maximumSourceDebtObservations = 26
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
  [ SourceTools
  , SourceDhall
  , SourceProto
  , SourceUi
  , SourcePulumi
  , SourceTest
  , SourceProbe
  , SourcePb
  , SourceVendor
  ]

laterOwnedSourceDebtIds :: Set SourceDebtId
laterOwnedSourceDebtIds =
  Set.fromList
    [ SourceTools
    , SourceDhall
    , SourceProto
    , SourceUi
    , SourcePulumi
    , SourceTest
    , SourceProbe
    , SourceVendor
    ]

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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FINGERPRINT_MUTANT)
        "7a370eba5fefa423d19fe03b62a4bb0d1a42f081276c92edef9b8799b6202bdc"
#else
        "6a370eba5fefa423d19fe03b62a4bb0d1a42f081276c92edef9b8799b6202bdc"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PATH_INVENTORY_MUTANT)
        "b3e7165733971922668b4c283f2a4f5fe9001f143fd621a9091455c23df01504"
#else
        "a3e7165733971922668b4c283f2a4f5fe9001f143fd621a9091455c23df01504"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_DHALL_FINGERPRINT_MUTANT)
        "2b6ec412272fc7a9894e0e6aed604eb1ea45e5adb059ae8a85a9b0988231ddfb"
#else
        "1b6ec412272fc7a9894e0e6aed604eb1ea45e5adb059ae8a85a9b0988231ddfb"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_DHALL_PATH_INVENTORY_MUTANT)
        "8360f0c7a1065e8aba3e8c241668703f65075dcf3dfe7e91f7923939291f17e2"
#else
        "9360f0c7a1065e8aba3e8c241668703f65075dcf3dfe7e91f7923939291f17e2"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROTO_FINGERPRINT_MUTANT)
        "929974a9fe5d21a566f7b9fe6a6311e2b9cc0d3ce6bd61c6db7c3b8e89e30d0f"
#else
        "829974a9fe5d21a566f7b9fe6a6311e2b9cc0d3ce6bd61c6db7c3b8e89e30d0f"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROTO_PATH_INVENTORY_MUTANT)
        "498ee861ab5e554a723bcc0cf94b943cf89b033bc62571fcb4387ab350e5e716"
#else
        "398ee861ab5e554a723bcc0cf94b943cf89b033bc62571fcb4387ab350e5e716"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_UI_FINGERPRINT_MUTANT)
        "8e7d4b91e6b2d0b410bfab949a5aa56d7437c498282bee93640fde14d01897da"
#else
        "7e7d4b91e6b2d0b410bfab949a5aa56d7437c498282bee93640fde14d01897da"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_UI_PATH_INVENTORY_MUTANT)
        "4992d81deb5b947f633846cb62279a3fe0f4ff03701bfd27ca382855177b6223"
#else
        "3992d81deb5b947f633846cb62279a3fe0f4ff03701bfd27ca382855177b6223"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_FINGERPRINT_MUTANT)
        "2cb177d7a74486fcc58159ecc05f43eb929f9c4e5d2d31c8762f282b04ef4697"
#else
        "1cb177d7a74486fcc58159ecc05f43eb929f9c4e5d2d31c8762f282b04ef4697"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_PATH_INVENTORY_MUTANT)
        "f55482b85a31758b72c112284c741f16766f6d1ffaf030ea0d7773d88b0f3022"
#else
        "e55482b85a31758b72c112284c741f16766f6d1ffaf030ea0d7773d88b0f3022"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_TEST_FINGERPRINT_MUTANT)
        "38947c7c6000818cc08d4bd347efde7ba8d1d27e3318fe66566ffca6db7bcfd6"
#else
        "28947c7c6000818cc08d4bd347efde7ba8d1d27e3318fe66566ffca6db7bcfd6"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_TEST_PATH_INVENTORY_MUTANT)
        "90fc42c24a9de83a8d7cbfd4232417058b7c8a72a9a8f4dec529aab5e5d96542"
#else
        "80fc42c24a9de83a8d7cbfd4232417058b7c8a72a9a8f4dec529aab5e5d96542"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROBE_FINGERPRINT_MUTANT)
        "a04fda09d0d0932c7e58f5fe2b134da8fc97c3ab7b48e19092df1ae97709d75e"
#else
        "904fda09d0d0932c7e58f5fe2b134da8fc97c3ab7b48e19092df1ae97709d75e"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_PROBE_PATH_INVENTORY_MUTANT)
        "88e3bbf2977c0e3f8a8f3dab020a8e504a0d11a453529bd12bda559b32367e14"
#else
        "78e3bbf2977c0e3f8a8f3dab020a8e504a0d11a453529bd12bda559b32367e14"
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
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_FINGERPRINT_MUTANT)
        "945e295527ccfeb1cea5434a488124890b680f5dd17baed6dfe9881bcdba07f6"
#else
        "845e295527ccfeb1cea5434a488124890b680f5dd17baed6dfe9881bcdba07f6"
#endif
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_PATH_INVENTORY_MUTANT)
        "2cac8ad1d2f7115323fb503d56ce04463338a94dbb98a8c313adfe67c0e66764"
#else
        "1cac8ad1d2f7115323fb503d56ce04463338a94dbb98a8c313adfe67c0e66764"
#endif
    )
#endif

-- | Analyze only an opaque acquired snapshot. There is no public constructor
-- for the resulting evidence and no public baseline, observation, or problem
-- projection with which a caller can fabricate an accepted comparison.
analyzeAcquiredSourceDebt :: AcquiredSourceSnapshot -> SourceDebtEvidence
analyzeAcquiredSourceDebt acquired =
  SourceDebtEvidence acquired result states
 where
  snapshot = acquiredSourceSnapshot acquired
  closure = classifySnapshot snapshot
  SourceDebtAnalysis result states = analyzeSourceDebt closure

-- | Extract the candidate CheckResult only while rejoining the evidence to the
-- exact opaque acquisition. A value analyzed from another snapshot refuses.
sourceDebtEvidenceCheck
  :: AcquiredSourceSnapshot
  -> SourceDebtEvidence
  -> CheckResult
sourceDebtEvidenceCheck acquired (SourceDebtEvidence evidenceAcquired result _)
  | acquired == evidenceAcquired = result
  | otherwise =
      result
        { checkFindings =
            checkFindings result
              <> [sourceDebtEvidenceMismatchFinding expectedIdentity evidenceIdentity]
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
  | acquired /= evidenceAcquired =
      onRefused
        ( "source-debt evidence snapshot mismatch: expected="
            <> expectedIdentity
            <> ", actual="
            <> evidenceIdentity
        )
  | otherwise = case Map.lookup identifier states of
      Nothing -> onRefused ("closed source-debt evidence is missing " <> renderSourceDebtId identifier)
      Just state -> case state of
        SourceDebtStateOpen count fingerprint -> onOpen count fingerprint
        SourceDebtStateZero -> onZero
        SourceDebtStateRefused detail -> onRefused detail
 where
  expectedIdentity = snapshotIdentity (acquiredSourceSnapshot acquired)
  evidenceIdentity = snapshotIdentity (acquiredSourceSnapshot evidenceAcquired)

sourceDebtEvidenceMismatchFinding :: Text -> Text -> Finding
sourceDebtEvidenceMismatchFinding expected actual =
  finding
    "SOURCE-DEBT-EVIDENCE-SNAPSHOT-MISMATCH"
    "source-debt-baseline"
    ("expected=" <> expected <> ", actual=" <> actual)

-- | The raw standard-value facade is bounded before it constructs production
-- source types. Mode text has one closed interpretation and invalid values
-- refuse explicitly instead of being coerced to a production constructor.
sourceDebtRawDiagnosticCheck
  :: [(FilePath, Text, Text, ByteString.ByteString)]
  -> CheckResult
sourceDebtRawDiagnosticCheck rawEntries =
  case boundedPrefix maximumSourceDebtTraversalEntries rawEntries of
    PrefixExceeded observedAtLeast ->
      diagnosticResult
        ( analysisResult
            ( limitAnalysis
                "traversal"
                "SOURCE-DEBT-TRAVERSAL-LIMIT"
                maximumSourceDebtTraversalEntries
                observedAtLeast
            )
        )
    PrefixWithin boundedEntries ->
      case rawSourceDebtResourceFailure boundedEntries of
        Just resourceFailure ->
          diagnosticResult
            (analysisResult (resourceLimitAnalysis resourceFailure))
        Nothing ->
          case traverse rawTrackedEntry boundedEntries of
            Left _ ->
              CheckResult
                { checkName = "source-debt-baseline"
                , checkObservations = []
                , checkFindings =
                    sourceDebtDiagnosticFindings
                      <> [ finding
                             "SOURCE-DEBT-RAW-MODE-INVALID"
                             "source-debt-baseline"
                             "raw mode must be exactly one of 100644,100755,120000"
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
    let pathBytes = boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes path
        objectIdBytes = boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes objectId
        blobBytes = boundedByteStringLength maximumSourceDebtBlobBytes bytes
        nextAggregate =
          min
            (maximumSourceDebtAggregateBlobBytes + 1)
            (aggregateBytes + blobBytes)
     in if pathBytes > maximumSourceDebtPathUtf8Bytes
          then Just (SourceDebtPathUtf8LimitExceeded pathBytes)
          else
            if objectIdBytes > maximumSourceDebtObjectIdUtf8Bytes
              then Just (SourceDebtObjectIdLimitExceeded objectIdBytes)
              else
                if blobBytes > maximumSourceDebtBlobBytes
                  then Just (SourceDebtBlobLimitExceeded blobBytes)
                  else
                    if nextAggregate > maximumSourceDebtAggregateBlobBytes
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
          { trackedIndex = IndexEntry path indexMode objectId
          , trackedBytes = bytes
          }

rawIndexMode :: Text -> Maybe IndexMode
rawIndexMode "100644" = Just RegularFile
rawIndexMode "100755" = Just ExecutableFile
rawIndexMode "120000" = Just SymbolicLink
#if defined(VALIDATION_SOURCE_DEBT_RAW_MODE_BYPASS_MUTANT)
rawIndexMode _ = Just RegularFile
#else
rawIndexMode _ = Nothing
#endif

analysisResult :: SourceDebtAnalysis -> CheckResult
analysisResult (SourceDebtAnalysis result _) = result

diagnosticResult :: CheckResult -> CheckResult
diagnosticResult result =
  result {checkFindings = sourceDebtDiagnosticFindings <> checkFindings result}

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
      "SOURCE-DEBT-DIAGNOSTIC-ONLY"
      "<caller-supplied-source-closure>"
      "caller-supplied source-debt observations are diagnostic input, not candidate acquisition authority"
  ]
#endif

analyzeSourceDebt :: SourceClosure -> SourceDebtAnalysis
analyzeSourceDebt closure =
  case boundedPrefix maximumSourceDebtTraversalEntries (closurePaths closure) of
    PrefixExceeded observedAtLeast ->
      limitAnalysis
        "traversal"
        "SOURCE-DEBT-TRAVERSAL-LIMIT"
        maximumSourceDebtTraversalEntries
        observedAtLeast
    PrefixWithin _ ->
      case boundedPrefix maximumSourceDebtPreallocationEntries registeredPaths of
        PrefixExceeded observedAtLeast ->
          limitAnalysis
            "preallocation"
            "SOURCE-DEBT-PREALLOCATION-LIMIT"
            maximumSourceDebtPreallocationEntries
            observedAtLeast
        PrefixWithin _ -> case prepareSourceDebt closure of
          Left resourceFailure -> resourceLimitAnalysis resourceFailure
          Right prepared -> analyzeBoundedSourceDebt prepared
 where
  registeredPaths =
    [ ()
    | classified <- closurePaths closure
    , RegisteredLegacy _ <- [classifiedAs classified]
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
            pathBytes = boundedFilePathUtf8Length maximumSourceDebtPathUtf8Bytes (indexPath indexed)
            objectIdBytes = boundedTextUtf8Length maximumSourceDebtObjectIdUtf8Bytes (indexObjectId indexed)
            blobBytes = boundedByteStringLength maximumSourceDebtBlobBytes (trackedBytes entry)
            nextAggregate =
              min
                (maximumSourceDebtAggregateBlobBytes + 1)
                (aggregateBytes + blobBytes)
         in if pathBytes > maximumSourceDebtPathUtf8Bytes
              then Left (SourceDebtPathUtf8LimitExceeded pathBytes)
              else
                if objectIdBytes > maximumSourceDebtObjectIdUtf8Bytes
                  then Left (SourceDebtObjectIdLimitExceeded objectIdBytes)
                  else
                    if blobBytes > maximumSourceDebtBlobBytes
                      then Left (SourceDebtBlobLimitExceeded blobBytes)
                      else
                        if nextAggregate > maximumSourceDebtAggregateBlobBytes
                          then Left (SourceDebtAggregateBlobLimitExceeded nextAggregate)
                          else
                            go
                              nextAggregate
                              (Map.insertWith (<>) identifier [entry] members)
                              rest
      _ -> go aggregateBytes members rest

boundedFilePathUtf8Length :: Integer -> FilePath -> Integer
boundedFilePathUtf8Length maximumBytes = go 0
 where
  go observed _ | observed > maximumBytes = maximumBytes + 1
  go observed [] = observed
  go observed (character : rest) =
    go (min (maximumBytes + 1) (observed + utf8CharacterBytes character)) rest

boundedTextUtf8Length :: Integer -> Text -> Integer
boundedTextUtf8Length maximumBytes = go 0
 where
  go observed _ | observed > maximumBytes = maximumBytes + 1
  go observed remaining = case Text.uncons remaining of
    Nothing -> observed
    Just (character, rest) ->
      go (min (maximumBytes + 1) (observed + utf8CharacterBytes character)) rest

boundedByteStringLength :: Integer -> ByteString.ByteString -> Integer
boundedByteStringLength maximumBytes =
  min (maximumBytes + 1) . fromIntegral . ByteString.length

utf8CharacterBytes :: Char -> Integer
utf8CharacterBytes character
  | codePoint <= 0x7f = 1
  | codePoint <= 0x7ff = 2
  | codePoint <= 0xffff = 3
  | otherwise = 4
 where
  codePoint = ord character

analyzeBoundedSourceDebt :: PreparedSourceDebt -> SourceDebtAnalysis
analyzeBoundedSourceDebt prepared =
  SourceDebtAnalysis result states
 where
  observed = observeSourceDebt prepared
  rawObservations =
    [ observation "source-debt.expected-family-count" (renderInt (Set.size laterOwnedSourceDebtIds))
    , observation "source-debt.actual-family-count" (renderInt (Map.size observed))
    ]
      <> concatMap renderObserved (Map.toAscList observed)
  rawProblems = sourceDebtProblems observed
  observationBound = boundedPrefix maximumSourceDebtObservations rawObservations
  problemBound = boundedPrefix maximumSourceDebtProblems rawProblems
  observationLimitFindings = case observationBound of
    PrefixWithin _ -> []
    PrefixExceeded observedAtLeast ->
      [limitFinding "SOURCE-DEBT-OBSERVATION-LIMIT" maximumSourceDebtObservations observedAtLeast]
  boundedObservations = case observationBound of
    PrefixWithin values -> values
    PrefixExceeded observedAtLeast ->
      limitObservations "observation" maximumSourceDebtObservations observedAtLeast
  boundedProblemFindings = case problemBound of
    PrefixWithin problems -> map problemFinding problems
    PrefixExceeded observedAtLeast ->
      [limitFinding "SOURCE-DEBT-PROBLEM-LIMIT" maximumSourceDebtProblems observedAtLeast]
  result =
    CheckResult
      { checkName = "source-debt-baseline"
      , checkObservations = boundedObservations
      , checkFindings = observationLimitFindings <> boundedProblemFindings <> stateIntegrityFindings states
      }
  states = case (observationBound, problemBound) of
    (PrefixWithin _, PrefixWithin _) -> sourceDebtStates observed
    _ -> refusedStates "source-debt analysis exceeded a closed result bound"

observeSourceDebt :: PreparedSourceDebt -> Map SourceDebtId SourceDebtObservation
observeSourceDebt (PreparedSourceDebt membersByFamily) =
  Map.mapWithKey observeOne membersByFamily

observeOne :: SourceDebtId -> [TrackedEntry] -> SourceDebtObservation
observeOne identifier unsortedMembers =
  let actual =
        SourceDebtObservation
          (observedPathCount members)
          (observedFingerprint identifier members)
          (observedPathInventoryDigest identifier members)
      members = sortOn (indexPath . trackedIndex) unsortedMembers
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
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-v2\0"
  identifierContext = updateText domainContext (renderSourceDebtId identifier)
  prefixContext = SHA256.update identifierContext nulByte
  finalContext = foldl' updateDebtMember prefixContext members

updateDebtMember :: SHA256.Ctx -> TrackedEntry -> SHA256.Ctx
updateDebtMember initialContext entry =
  SHA256.update blobSeparatorContext nulByte
 where
  indexed = trackedIndex entry
  pathContext = updateText initialContext (Text.pack (indexPath indexed))
  pathSeparatorContext = SHA256.update pathContext nulByte
  modeContext = updateText pathSeparatorContext (renderIndexMode (indexMode indexed))
  modeSeparatorContext = SHA256.update modeContext nulByte
  objectContext = updateText modeSeparatorContext (indexObjectId indexed)
  objectSeparatorContext = SHA256.update objectContext nulByte
  blobSeparatorContext = updateText objectSeparatorContext (sourceDebtBlobCommitment entry)

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
  domainContext = SHA256.update SHA256.init "amoebius-source-debt-path-inventory-v1\0"
  identifierContext = updateText domainContext (renderSourceDebtId identifier)
  prefixContext = SHA256.update identifierContext nulByte
  finalContext = foldl' updatePathMember prefixContext members
  updatePathMember context entry =
    SHA256.update
      (updateText context (Text.pack (indexPath (trackedIndex entry))))
      nulByte

sha256Incremental :: ByteString.ByteString -> ByteString.ByteString
sha256Incremental = SHA256.finalize . SHA256.update SHA256.init

updateText :: SHA256.Ctx -> Text -> SHA256.Ctx
updateText context = SHA256.update context . TextEncoding.encodeUtf8

renderIndexMode :: IndexMode -> Text
renderIndexMode RegularFile = "100644"
renderIndexMode ExecutableFile = "100755"
renderIndexMode SymbolicLink = "120000"

nulByte :: ByteString.ByteString
nulByte = ByteString.singleton 0

sourceDebtProblems :: Map SourceDebtId SourceDebtObservation -> [SourceDebtProblem]
sourceDebtProblems observed =
  baselineFamilyProblems
    <> observedFamilyProblems
    <> pbProblems
    <> concatMap compareOne (Map.toAscList laterOwnedSourceDebtBaselines)
 where
  declaredFamilies = Map.keysSet laterOwnedSourceDebtBaselines
  baselineFamilyProblems =
    [ SourceDebtBaselineFamilySetMismatch laterOwnedSourceDebtIds declaredFamilies
    | not (sourceDebtBaselineFamilySetMatches laterOwnedSourceDebtIds declaredFamilies)
    ]
  actualLaterOwned = Set.delete SourcePb (Map.keysSet observed)
  observedFamilyProblems =
    [ SourceDebtFamilySetMismatch laterOwnedSourceDebtIds actualLaterOwned
    | not (sourceDebtObservedFamilySetMatches laterOwnedSourceDebtIds actualLaterOwned)
    ]
  pbProblems =
    [ SourcePbObservationPresent value
    | not (sourceDebtPbIsZero observed)
    , Just value <- [Map.lookup SourcePb observed]
    ]
  compareOne (identifier, expected) = case Map.lookup identifier observed of
    Nothing -> []
    Just actual ->
      [ SourceDebtPathCountMismatch identifier (baselineCount expected) (observationCount actual)
      | not (sourceDebtCountMatches expected actual)
      ]
        <> [ SourceDebtFingerprintMismatch identifier (baselineFingerprint expected) (observationFingerprint actual)
           | not (sourceDebtFingerprintMatches expected actual)
           ]
        <> [ SourceDebtPathInventoryDigestMismatch identifier (baselinePathDigest expected) (observationPathDigest actual)
           | not (sourceDebtPathInventoryMatches expected actual)
           ]

sourceDebtBaselineFamilySetMatches :: Set SourceDebtId -> Set SourceDebtId -> Bool
#if defined(VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_SET_INVERSION_MUTANT)
sourceDebtBaselineFamilySetMatches expected actual = expected /= actual
#else
sourceDebtBaselineFamilySetMatches expected actual = expected == actual
#endif

sourceDebtObservedFamilySetMatches :: Set SourceDebtId -> Set SourceDebtId -> Bool
#if defined(VALIDATION_SOURCE_DEBT_OBSERVED_FAMILY_SET_BYPASS_MUTANT)
sourceDebtObservedFamilySetMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtObservedFamilySetMatches expected actual = expected == actual
#endif

sourceDebtPbIsZero :: Map SourceDebtId SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_PB_ZERO_BYPASS_MUTANT)
sourceDebtPbIsZero observed = observed `seq` True
#else
sourceDebtPbIsZero = Map.notMember SourcePb
#endif

sourceDebtCountMatches :: SourceDebtBaseline -> SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_COUNT_COMPARISON_BYPASS_MUTANT)
sourceDebtCountMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtCountMatches expected actual = baselineCount expected == observationCount actual
#endif

sourceDebtFingerprintMatches :: SourceDebtBaseline -> SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_FINGERPRINT_COMPARISON_BYPASS_MUTANT)
sourceDebtFingerprintMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtFingerprintMatches expected actual = baselineFingerprint expected == observationFingerprint actual
#endif

sourceDebtPathInventoryMatches :: SourceDebtBaseline -> SourceDebtObservation -> Bool
#if defined(VALIDATION_SOURCE_DEBT_PATH_INVENTORY_COMPARISON_BYPASS_MUTANT)
sourceDebtPathInventoryMatches expected actual = expected `seq` actual `seq` True
#else
sourceDebtPathInventoryMatches expected actual = baselinePathDigest expected == observationPathDigest actual
#endif

sourceDebtStates :: Map SourceDebtId SourceDebtObservation -> Map SourceDebtId SourceDebtState
sourceDebtStates observed =
  Map.fromList [(identifier, sourceDebtState identifier observed) | identifier <- allSourceDebtIds]

stateIntegrityFindings :: Map SourceDebtId SourceDebtState -> [Finding]
stateIntegrityFindings states =
  keyFindings <> zeroFindings
 where
  expectedKeys = Set.fromList allSourceDebtIds
  actualKeys = Map.keysSet states
  keyFindings =
    [ finding
        "SOURCE-DEBT-STATE-INVENTORY-MISMATCH"
        "source-debt-baseline"
        ("expected=" <> renderIds expectedKeys <> ", actual=" <> renderIds actualKeys)
    | actualKeys /= expectedKeys
    ]
  zeroFindings =
    [ finding
        "SOURCE-DEBT-STATE-ZERO-UNAUTHORIZED"
        (Text.unpack (renderSourceDebtId identifier))
        "only the acquired Phase-0-owned pb family may have a zero source-debt lifecycle state"
    | identifier <- Set.toAscList laterOwnedSourceDebtIds
    , Just SourceDebtStateZero <- [Map.lookup identifier states]
    ]

sourceDebtState :: SourceDebtId -> Map SourceDebtId SourceDebtObservation -> SourceDebtState
sourceDebtState SourcePb observed
  | sourceDebtPbIsZero observed = SourceDebtStateZero
  | otherwise = SourceDebtStateRefused "bounded pb source debt is not zero"
sourceDebtState identifier observed =
  case (sourceDebtBaseline identifier, Map.lookup identifier observed) of
    (Nothing, _) ->
      SourceDebtStateRefused ("missing closed source-debt baseline for " <> renderSourceDebtId identifier)
    (Just _, Nothing) ->
#if defined(VALIDATION_SOURCE_DEBT_MISSING_OBSERVATION_ZERO_MUTANT)
      SourceDebtStateZero
#else
      SourceDebtStateRefused ("missing acquired source-debt observation for " <> renderSourceDebtId identifier)
#endif
    (Just expected, Just actual)
      | sourceDebtCountMatches expected actual
          && sourceDebtFingerprintMatches expected actual
          && sourceDebtPathInventoryMatches expected actual ->
          SourceDebtStateOpen (observationCount actual) (observationFingerprint actual)
      | otherwise ->
          SourceDebtStateRefused ("source-debt baseline mismatch for " <> renderSourceDebtId identifier)

baselineCount :: SourceDebtBaseline -> Int
baselineCount (SourceDebtBaseline value _ _) = value

baselineFingerprint :: SourceDebtBaseline -> Text
baselineFingerprint (SourceDebtBaseline _ value _) = value

baselinePathDigest :: SourceDebtBaseline -> Text
baselinePathDigest (SourceDebtBaseline _ _ value) = value

observationCount :: SourceDebtObservation -> Int
observationCount (SourceDebtObservation value _ _) = value

observationFingerprint :: SourceDebtObservation -> Text
observationFingerprint (SourceDebtObservation _ value _) = value

observationPathDigest :: SourceDebtObservation -> Text
observationPathDigest (SourceDebtObservation _ _ value) = value

renderObserved :: (SourceDebtId, SourceDebtObservation) -> [Observation]
renderObserved (identifier, value) =
  [ observation ("source-debt.count." <> renderSourceDebtId identifier) (renderInt (observationCount value))
  , observation ("source-debt.fingerprint." <> renderSourceDebtId identifier) (observationFingerprint value)
  , observation ("source-debt.path-inventory." <> renderSourceDebtId identifier) (observationPathDigest value)
  ]

problemFinding :: SourceDebtProblem -> Finding
problemFinding problem = case problem of
  SourceDebtBaselineFamilySetMismatch expected actual ->
    finding
      "SOURCE-DEBT-BASELINE-FAMILY-SET-MISMATCH"
      "source-debt-baseline"
      ("expected=" <> renderIds expected <> ", actual=" <> renderIds actual)
  SourceDebtFamilySetMismatch expected actual ->
    finding
      "SOURCE-DEBT-FAMILY-SET-MISMATCH"
      "source-debt-baseline"
      ("expected=" <> renderIds expected <> ", actual=" <> renderIds actual)
  SourcePbObservationPresent actual ->
    finding
      "SOURCE-DEBT-PB-NOT-ZERO"
      (Text.unpack (renderSourceDebtId SourcePb))
      ( "expected absent/zero, actual count="
          <> renderInt (observationCount actual)
          <> ", fingerprint="
          <> observationFingerprint actual
      )
  SourceDebtPathCountMismatch identifier expected actual ->
    finding
      "SOURCE-DEBT-COUNT-MISMATCH"
      (Text.unpack (renderSourceDebtId identifier))
      ("expected=" <> renderInt expected <> ", actual=" <> renderInt actual)
  SourceDebtFingerprintMismatch identifier expected actual ->
    finding
      "SOURCE-DEBT-FINGERPRINT-MISMATCH"
      (Text.unpack (renderSourceDebtId identifier))
      ("expected=" <> expected <> ", actual=" <> actual)
  SourceDebtPathInventoryDigestMismatch identifier expected actual ->
    finding
      "SOURCE-DEBT-PATH-INVENTORY-MISMATCH"
      (Text.unpack (renderSourceDebtId identifier))
      ("expected=" <> expected <> ", actual=" <> actual)

resourceLimitAnalysis :: SourceDebtResourceFailure -> SourceDebtAnalysis
resourceLimitAnalysis resourceFailure =
  case resourceFailure of
    SourceDebtPathUtf8LimitExceeded observedAtLeast ->
      resourceBoundedAnalysis
        "path-utf8"
        "SOURCE-DEBT-PATH-UTF8-LIMIT"
        maximumSourceDebtPathUtf8Bytes
        observedAtLeast
    SourceDebtObjectIdLimitExceeded observedAtLeast ->
      resourceBoundedAnalysis
        "object-id"
        "SOURCE-DEBT-OBJECT-ID-LIMIT"
        maximumSourceDebtObjectIdUtf8Bytes
        observedAtLeast
    SourceDebtBlobLimitExceeded observedAtLeast ->
      resourceBoundedAnalysis
        "blob"
        "SOURCE-DEBT-BLOB-LIMIT"
        maximumSourceDebtBlobBytes
        observedAtLeast
    SourceDebtAggregateBlobLimitExceeded observedAtLeast ->
      resourceBoundedAnalysis
        "aggregate-blob"
        "SOURCE-DEBT-AGGREGATE-BLOB-LIMIT"
        maximumSourceDebtAggregateBlobBytes
        observedAtLeast

resourceBoundedAnalysis :: Text -> Text -> Integer -> Integer -> SourceDebtAnalysis
resourceBoundedAnalysis dimension code maximumBytes observedAtLeast =
  SourceDebtAnalysis
    CheckResult
      { checkName = "source-debt-baseline"
      , checkObservations = limitObservations dimension maximumBytes observedAtLeast
      , checkFindings = [limitFinding code maximumBytes observedAtLeast]
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
      { checkName = "source-debt-baseline"
      , checkObservations = limitObservations dimension maximumValue observedAtLeast
      , checkFindings = [limitFinding code maximumValue observedAtLeast]
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
  [ observation ("source-debt." <> dimension <> "-limit.maximum") (renderNumber maximumValue)
  , observation ("source-debt." <> dimension <> "-limit.observed-at-least") (renderNumber observedAtLeast)
  ]

limitFinding :: Show number => Text -> number -> number -> Finding
limitFinding code maximumValue observedAtLeast =
  finding
    code
    "source-debt-baseline"
    ( "maximum="
        <> renderNumber maximumValue
        <> ", observed-at-least="
        <> renderNumber observedAtLeast
    )

refusedStates :: Text -> Map SourceDebtId SourceDebtState
refusedStates detail =
  Map.fromList [(identifier, SourceDebtStateRefused detail) | identifier <- allSourceDebtIds]

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix maximumValue values =
  let prefix = take (maximumValue + 1) values
   in if length prefix > maximumValue
        then PrefixExceeded (maximumValue + 1)
        else PrefixWithin prefix

renderIds :: Set SourceDebtId -> Text
renderIds = Text.intercalate "," . map renderSourceDebtId . Set.toAscList

renderInt :: Int -> Text
renderInt = Text.pack . show

renderInteger :: Integer -> Text
renderInteger = Text.pack . show

renderNumber :: Show number => number -> Text
renderNumber = Text.pack . show

_zeroDigest :: Text
_zeroDigest = Text.replicate 64 "0"

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex byte =
    [ intToDigit (fromIntegral byte `div` 16)
    , intToDigit (fromIntegral byte `mod` 16)
    ]
