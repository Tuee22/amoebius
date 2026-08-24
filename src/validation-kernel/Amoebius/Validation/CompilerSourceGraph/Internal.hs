{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerSourceGraph.Internal
  ( AcquiredCompilerSourceGraph
  , acquiredCompilerSnapshotIdentity
  , acquiredCompilerSourceCheck
  , analyzeAcquiredCompilerSourceGraph
  , rawCompilerSourceGraphDiagnostic
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( analyzeSourceConsumerGraph
  , sourceConsumerGraphCheck
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (isAsciiLower, isAsciiUpper, ord, toLower)
import Data.List (group, isPrefixOf, sort)
import Data.List qualified as List
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (isAbsolute, takeExtension)

-- These are diagnostic-fixture ceilings, not acquired-repository ceilings.
-- Every applicable bound is checked before splitting, sorting, hashing, or
-- constructing maps and semantic values.
maximumRawIdentityBytes, maximumRawEntries, maximumRawPathBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_LIMIT_WIDEN_MUTANT)
maximumRawIdentityBytes = 65
#else
maximumRawIdentityBytes = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_LIMIT_WIDEN_MUTANT)
maximumRawEntries = 129
#else
maximumRawEntries = 128
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_LIMIT_WIDEN_MUTANT)
maximumRawPathBytes = 1025
#else
maximumRawPathBytes = 1024
#endif

maximumRawPathDepth, maximumRawPathSegmentBytes, maximumRawModeBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DEPTH_LIMIT_WIDEN_MUTANT)
maximumRawPathDepth = 65
#else
maximumRawPathDepth = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SEGMENT_LIMIT_WIDEN_MUTANT)
maximumRawPathSegmentBytes = 256
#else
maximumRawPathSegmentBytes = 255
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_LIMIT_WIDEN_MUTANT)
maximumRawModeBytes = 7
#else
maximumRawModeBytes = 6
#endif

maximumRawObjectIdentityBytes, maximumRawBlobBytes, maximumRawAggregateBlobBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_LIMIT_WIDEN_MUTANT)
maximumRawObjectIdentityBytes = 65
#else
maximumRawObjectIdentityBytes = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_LIMIT_WIDEN_MUTANT)
maximumRawBlobBytes = 65537
#else
maximumRawBlobBytes = 65536
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_LIMIT_WIDEN_MUTANT)
maximumRawAggregateBlobBytes = 262145
#else
maximumRawAggregateBlobBytes = 262144
#endif

maximumRawHaskellSubjects, maximumRawCabalEntries :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_LIMIT_WIDEN_MUTANT)
maximumRawHaskellSubjects = 65
#else
maximumRawHaskellSubjects = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_LIMIT_WIDEN_MUTANT)
maximumRawCabalEntries = 5
#else
maximumRawCabalEntries = 4
#endif

-- This is a separate repository-scale ceiling for the opaque acquired path;
-- it is not the 128-row caller-fixture ceiling.  SourceClosure must establish
-- its own path/blob/aggregate invariants before it can mint the opaque input.
maximumAcquiredCompilerEntries :: Int
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_LIMIT_WIDEN_MUTANT)
maximumAcquiredCompilerEntries = 16385
#else
maximumAcquiredCompilerEntries = 16384
#endif

data AcquiredCompilerSourceGraph
  = AcquiredCompilerSourceGraph Text CheckResult
  deriving (Eq, Show)

acquiredCompilerSnapshotIdentity :: AcquiredCompilerSourceGraph -> Text
acquiredCompilerSnapshotIdentity (AcquiredCompilerSourceGraph identity _) = identity

acquiredCompilerSourceCheck :: AcquiredCompilerSourceGraph -> CheckResult
acquiredCompilerSourceCheck (AcquiredCompilerSourceGraph _ result) = result

-- | Acquired source custody alone is insufficient. This path deliberately does
-- not invoke GHC until opaque authenticated elaboration, toolchain, subject-role
-- and supervisor inputs exist.
analyzeAcquiredCompilerSourceGraph
  :: AcquiredSourceSnapshot
  -> IO AcquiredCompilerSourceGraph
analyzeAcquiredCompilerSourceGraph acquired =
  pure (AcquiredCompilerSourceGraph identity result)
 where
  snapshot = acquiredSourceSnapshot acquired
  identity = snapshotIdentity snapshot
  (entryCount, consumerComposition, consumerObservations, consumerFindings, envelopeFindings) =
    case boundedPrefix maximumAcquiredCompilerEntries (snapshotEntries snapshot) of
      PrefixExceeded observed ->
        ( decimalText observed <> "+"
        , "refused-before-source-consumer-diagnostic"
        , []
        , []
        , [ finding
              "SRC-COMPILER-ACQUIRED-ENTRY-LIMIT"
              "compiler-source-graph"
              ( "limit="
                  <> decimalText maximumAcquiredCompilerEntries
                  <> "; observed-at-least="
                  <> decimalText observed
              )
          ]
        )
      PrefixWithin boundedEntries ->
        let consumerCheck = sourceConsumerGraphCheck (analyzeSourceConsumerGraph snapshot)
         in ( decimalText (length boundedEntries)
            , "source-consumer-diagnostic-only"
            , checkObservations consumerCheck
            , checkFindings consumerCheck
            , []
            )
  result =
    CheckResult
      { checkName = "acquired-compiler-source-graph-refusal"
      , checkObservations =
          consumerObservations
            <> [ observation "source-compiler.snapshot" identity
               , observation
                   "source-compiler.inventory-entry-count"
                   entryCount
               , observation "source-compiler.consumer-graph-composition" consumerComposition
               , observation "source-compiler.subject-role-registry" "absent"
               , observation "source-compiler.elaborated-multi-run-plan" "absent"
               , observation "source-compiler.toolchain-authentication" "absent"
               , observation "source-compiler.execution" "not-attempted"
               , observation "source-compiler.semantic-closure" "absent"
               ]
      , checkFindings = consumerFindings <> envelopeFindings <> acquiredRefusalFindings
      }

acquiredRefusalFindings :: [Finding]
-- The acquired wrapper has no success constructor or discharge branch in this
-- component. Each mandatory residue is independently retained so a selective
-- omission is an atomic changed-production subject.
acquiredRefusalFindings =
  [ finding
      "SRC-COMPILER-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE"
      "compiler-source-graph"
      "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is two-way complete against the acquired .hs inventory"
  | retainAcquiredSubjectRegistryResidue
  ]
    <> [ finding
      "SRC-COMPILER-ELABORATED-MULTI-RUN-UNAVAILABLE"
      "compiler-source-graph"
      "no authenticated Cabal elaboration binds every component, flag vector, generated input, compiler argument, and expected compile-refusal run"
       | retainAcquiredElaborationResidue
       ]
    <> [ finding
      "SRC-COMPILER-TOOLCHAIN-UNAUTHENTICATED"
      "compiler-source-graph"
      "the compiler executable, libdir, package databases, dependencies, and build-info inputs have no independent authenticated network-independent observation"
       | retainAcquiredToolchainResidue
       ]
    <> [ finding
      "SRC-COMPILER-EXECUTION-UNSUPERVISED"
      "compiler-source-graph"
      "no challenged source-bound Haskell supervisor has bounded compiler time, memory, output, filesystem inputs, and process identity"
       | retainAcquiredExecutionResidue
       ]
    <> [ finding
      "SRC-COMPILER-SEMANTIC-CLOSURE-UNAVAILABLE"
      "compiler-source-graph"
      "resolved calls, indirect calls, control flow, effects, tracked-content provenance, behaviour sinks, and dynamic loading are not completely established"
       | retainAcquiredSemanticResidue
       ]

retainAcquiredSubjectRegistryResidue, retainAcquiredElaborationResidue,
  retainAcquiredToolchainResidue, retainAcquiredExecutionResidue,
  retainAcquiredSemanticResidue :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT)
retainAcquiredSubjectRegistryResidue = False
#else
retainAcquiredSubjectRegistryResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DROP_MUTANT)
retainAcquiredElaborationResidue = False
#else
retainAcquiredElaborationResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DROP_MUTANT)
retainAcquiredToolchainResidue = False
#else
retainAcquiredToolchainResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DROP_MUTANT)
retainAcquiredExecutionResidue = False
#else
retainAcquiredExecutionResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DROP_MUTANT)
retainAcquiredSemanticResidue = False
#else
retainAcquiredSemanticResidue = True
#endif

data RawEntry = RawEntry FilePath Text Text ByteString

rawPath :: RawEntry -> FilePath
rawPath (RawEntry value _ _ _) = value

rawMode :: RawEntry -> Text
rawMode (RawEntry _ value _ _) = value

rawObjectIdentity :: RawEntry -> Text
rawObjectIdentity (RawEntry _ _ value _) = value

rawBytes :: RawEntry -> ByteString
rawBytes (RawEntry _ _ _ value) = value

data RawSummary = RawSummary Text Text Text Text Text (Maybe RawProblem)

data RawProblem
  = RawIdentityByteLimit Int Int
  | RawEntryLimit Int Int
  | RawPathByteLimit Int Int Int
  | RawPathDepthLimit Int Int Int
  | RawPathSegmentLimit Int Int Int
  | RawModeByteLimit Int Int Int
  | RawObjectIdentityByteLimit Int Int Int
  | RawBlobByteLimit Int Int Int
  | RawAggregateBlobByteLimit Int Int
  | RawHaskellSubjectLimit Int Int
  | RawCabalEntryLimit Int Int
  | RawIdentityMalformed
  | RawIdentityMismatch Text Text
  | RawPathEmpty Int
  | RawPathAbsolute Int
  | RawPathNul Int
  | RawPathBackslash Int
  | RawPathEmptySegment Int
  | RawPathDotSegment Int
  | RawPathParentSegment Int
  | RawPathCharacterUnsafe Int
  | RawPathDuplicate FilePath
  | RawPathPortableCaseCollision FilePath FilePath
  | RawPathPrefixConflict FilePath FilePath
  | RawEntryOrderInvalid
  | RawModeMalformed Int
  | RawObjectIdentityMalformed Int
  | RawObjectIdentityMismatch Int Text Text
  | RawObjectFormatsMixed
  | RawHaskellSubjectModeRejected Int
  | RawCabalEntryModeRejected Int
  | RawHaskellSubjectInventoryEmpty
  | RawCabalEntryInventoryEmpty
  deriving (Eq, Show)

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

rawCompilerSourceGraphDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
rawCompilerSourceGraphDiagnostic claimedIdentity tuples =
  CheckResult
    { checkName = "compiler-source-graph-diagnostic"
    , checkObservations = rawObservations summary
    , checkFindings = rawProblemFindings summary <> rawMandatoryFindings
    }
 where
  summary = analyzeRawInput claimedIdentity tuples

rawObservations :: RawSummary -> [Observation]
rawObservations (RawSummary entryCount aggregate identity haskellCount cabalCount problem) =
  [ observation "compiler-graph.input.entry-count" entryCount
  , observation "compiler-graph.input.aggregate-blob-bytes" aggregate
  , observation "compiler-graph.input.inventory-sha256" identity
  , observation "compiler-graph.input.haskell-subject-count" haskellCount
  , observation "compiler-graph.input.cabal-entry-count" cabalCount
  , observation "compiler-graph.input.problem-count" (maybe "0" (const "1") problem)
  , observation "compiler-graph.compiler-execution" "not-attempted"
  , observation "compiler-graph.semantic-closure" "absent"
  , observation "compiler-graph.diagnostic-status" "refused"
  ]

rawProblemFindings :: RawSummary -> [Finding]
rawProblemFindings (RawSummary _ _ _ _ _ problem) = maybe [] (pure . rawProblemFinding) problem

rawMandatoryFindings :: [Finding]
rawMandatoryFindings =
  concat
    [
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-DIAGNOSTIC-ONLY" "compiler-source-graph" "raw caller input can produce diagnostics only; it cannot mint compiler-source-graph evidence"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SOURCE_CUSTODY_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-SOURCE-CUSTODY-UNAVAILABLE" "compiler-source-graph" "the raw inventory has no authenticated immutable source-custody token"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE" "compiler-source-graph" "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-ELABORATION-CUSTODY-UNAVAILABLE" "compiler-source-graph" "no authenticated elaborated multi-component configuration-run plan is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-TOOLCHAIN-CUSTODY-UNAVAILABLE" "compiler-source-graph" "no authenticated compiler, libdir, package-database, dependency, or build-info identity is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-EXECUTION-SUPERVISION-UNAVAILABLE" "compiler-source-graph" "the compiler was not invoked by a challenged source-bound Haskell supervisor with closed resource and filesystem custody"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-SEMANTIC-CLOSURE-UNAVAILABLE" "compiler-source-graph" "complete calls, control flow, effect, provenance, sink, and dynamic-loading facts are absent"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_DROP_MUTANT)
      [finding "COMPILER-GRAPH-ORACLE-QUALIFICATION-UNAVAILABLE" "compiler-source-graph" "the component diagnostic is not an independently qualified phase-gate observation"]
#else
      []
#endif
    ]

analyzeRawInput
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> RawSummary
analyzeRawInput claimedIdentity tuples =
  case boundedTextUtf8Length maximumRawIdentityBytes claimedIdentity of
    PrefixExceeded observed -> rawFailure (RawIdentityByteLimit maximumRawIdentityBytes observed)
    PrefixWithin _ -> case boundedPrefix maximumRawEntries tuples of
      PrefixExceeded observed -> rawFailure (RawEntryLimit maximumRawEntries observed)
      PrefixWithin boundedTuples ->
        analyzeBounded claimedIdentity
          [RawEntry path mode objectIdentity bytes | (path, mode, objectIdentity, bytes) <- boundedTuples]

analyzeBounded :: Text -> [RawEntry] -> RawSummary
analyzeBounded claimedIdentity entries =
  case firstResourceProblem entries of
    Just problem -> rawFailure problem
    Nothing -> case firstGrammarProblem claimedIdentity entries of
      Just problem -> rawFailure problem
      Nothing ->
        RawSummary
          (decimalText (length entries))
          (decimalText (sum (map (ByteString.length . rawBytes) entries)))
          (inventoryIdentity entries)
          (decimalText (length (filter isHaskellEntry entries)))
          (decimalText (length (filter isCabalEntry entries)))
          Nothing

rawFailure :: RawProblem -> RawSummary
rawFailure = RawSummary "unavailable" "unavailable" "unavailable" "unavailable" "unavailable" . Just

firstResourceProblem :: [RawEntry] -> Maybe RawProblem
firstResourceProblem entries =
  firstJust (zipWith entryResourceProblem [1 ..] entries)
    `orElse` aggregateProblem entries
    `orElse` countProblem maximumRawHaskellSubjects RawHaskellSubjectLimit (filter isHaskellEntry entries)
    `orElse` countProblem maximumRawCabalEntries RawCabalEntryLimit (filter isCabalEntry entries)

entryResourceProblem :: Int -> RawEntry -> Maybe RawProblem
entryResourceProblem ordinal entry =
  exceeded
    (boundedFilePathUtf8Length maximumRawPathBytes (rawPath entry))
    (RawPathByteLimit ordinal maximumRawPathBytes)
    `orElse` pathDepthProblem ordinal (rawPath entry)
    `orElse` pathSegmentProblem ordinal (rawPath entry)
    `orElse` exceeded
      (boundedTextUtf8Length maximumRawModeBytes (rawMode entry))
      (RawModeByteLimit ordinal maximumRawModeBytes)
    `orElse` exceeded
      (boundedTextUtf8Length maximumRawObjectIdentityBytes (rawObjectIdentity entry))
      (RawObjectIdentityByteLimit ordinal maximumRawObjectIdentityBytes)
    `orElse` blobProblem
 where
  observedBlobBytes = ByteString.length (rawBytes entry)
  blobProblem =
    [RawBlobByteLimit ordinal maximumRawBlobBytes observedBlobBytes | observedBlobBytes > maximumRawBlobBytes]
      `listHead` Nothing

aggregateProblem :: [RawEntry] -> Maybe RawProblem
aggregateProblem = go 0
 where
  go total remaining = case remaining of
    [] -> Nothing
    entry : rest ->
      let next = min (maximumRawAggregateBlobBytes + 1) (total + ByteString.length (rawBytes entry))
       in if next > maximumRawAggregateBlobBytes
            then Just (RawAggregateBlobByteLimit maximumRawAggregateBlobBytes next)
            else go next rest

countProblem :: Int -> (Int -> Int -> RawProblem) -> [value] -> Maybe RawProblem
countProblem limit constructor values = case boundedPrefix limit values of
  PrefixExceeded observed -> Just (constructor limit observed)
  PrefixWithin _ -> Nothing

pathDepthProblem :: Int -> FilePath -> Maybe RawProblem
pathDepthProblem ordinal path = case boundedPrefix maximumRawPathDepth (splitSlash path) of
  PrefixExceeded observed -> Just (RawPathDepthLimit ordinal maximumRawPathDepth observed)
  PrefixWithin _ -> Nothing

pathSegmentProblem :: Int -> FilePath -> Maybe RawProblem
pathSegmentProblem ordinal path =
  firstJust
    [ exceeded
        (boundedFilePathUtf8Length maximumRawPathSegmentBytes segment)
        (RawPathSegmentLimit ordinal maximumRawPathSegmentBytes)
    | segment <- splitSlash path
    ]

firstGrammarProblem :: Text -> [RawEntry] -> Maybe RawProblem
firstGrammarProblem claimedIdentity entries =
  firstJust (zipWith entryGrammarProblem [1 ..] entries)
    `orElse` duplicateProblem paths
    `orElse` portableCaseProblem paths
    `orElse` prefixProblem paths
    `orElse` orderProblem paths
    `orElse` mixedFormatProblem entries
    `orElse` inventoryCountGrammarProblem entries
    `orElse` identityGrammarProblem claimedIdentity entries
 where
  paths = map rawPath entries

entryGrammarProblem :: Int -> RawEntry -> Maybe RawProblem
entryGrammarProblem ordinal entry =
  pathGrammarProblem ordinal (rawPath entry)
    `orElse` modeGrammarProblem ordinal (rawMode entry)
    `orElse` objectGrammarProblem ordinal (rawObjectIdentity entry) (rawBytes entry)
    `orElse` haskellModeProblem
    `orElse` cabalModeProblem
 where
  haskellModeProblem =
    [ RawHaskellSubjectModeRejected ordinal
    | isHaskellEntry entry
    , rawMode entry /= "100644"
    , not haskellModeBypassed
    ] `listHead` Nothing
  cabalModeProblem =
    [ RawCabalEntryModeRejected ordinal
    | isCabalEntry entry
    , rawMode entry /= "100644"
    , not cabalModeBypassed
    ] `listHead` Nothing

pathGrammarProblem :: Int -> FilePath -> Maybe RawProblem
pathGrammarProblem ordinal path
  | null path && not pathEmptyBypassed = Just (RawPathEmpty ordinal)
  | isAbsolute path && not pathAbsoluteBypassed = Just (RawPathAbsolute ordinal)
  | '\0' `elem` path && not pathNulBypassed = Just (RawPathNul ordinal)
  | '\\' `elem` path && not pathBackslashBypassed = Just (RawPathBackslash ordinal)
  | any null parts && not pathEmptySegmentBypassed = Just (RawPathEmptySegment ordinal)
  | "." `elem` parts && not pathDotBypassed = Just (RawPathDotSegment ordinal)
  | ".." `elem` parts && not pathParentBypassed = Just (RawPathParentSegment ordinal)
  | any (not . safePathCharacter) path && not pathCharacterBypassed = Just (RawPathCharacterUnsafe ordinal)
  | otherwise = Nothing
 where
  parts = splitSlash path

modeGrammarProblem :: Int -> Text -> Maybe RawProblem
modeGrammarProblem ordinal mode
  | mode `elem` ["100644", "100755", "120000"] = Nothing
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_GRAMMAR_WIDEN_MUTANT)
  | mode == "100664" = Nothing
#endif
  | otherwise = Just (RawModeMalformed ordinal)

objectGrammarProblem :: Int -> Text -> ByteString -> Maybe RawProblem
objectGrammarProblem ordinal objectIdentity bytes
  | not (validObjectIdentity objectIdentity) = Just (RawObjectIdentityMalformed ordinal)
  | objectIdentity /= expected && not objectContentBypassed =
      Just (RawObjectIdentityMismatch ordinal expected objectIdentity)
  | otherwise = Nothing
 where
  expected = gitBlobIdentity objectIdentity bytes

validObjectIdentity :: Text -> Bool
validObjectIdentity value =
  (Text.length value == 40 || Text.length value == 64)
    && Text.all lowercaseHex value
 where
  lowercaseHex character =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_HEX_WIDEN_MUTANT)
    asciiDigit character || (character >= 'a' && character <= 'g')
#else
    asciiDigit character || (character >= 'a' && character <= 'f')
#endif

duplicateProblem :: [FilePath] -> Maybe RawProblem
duplicateProblem paths
  | duplicatePathBypassed = Nothing
  | repeated : _ <-
      [path | groupedPaths <- group (sort paths), path : _ : _ <- [groupedPaths]] =
      Just (RawPathDuplicate repeated)
  | otherwise = Nothing

portableCaseProblem :: [FilePath] -> Maybe RawProblem
portableCaseProblem paths
  | portableCaseBypassed = Nothing
  | colliding : _ <- [sort originals | originals <- grouped, length originals > 1]
  , first : second : _ <- colliding =
      Just (RawPathPortableCaseCollision first second)
  | otherwise = Nothing
 where
  grouped = map (map snd) (groupByKey (sort [(map toLower path, path) | path <- paths]))

prefixProblem :: [FilePath] -> Maybe RawProblem
prefixProblem paths
  | prefixBypassed = Nothing
  | (parent, child) : _ <-
      [ (parent, child)
      | parent <- ordered
      , child <- ordered
      , parent /= child
      , (parent <> "/") `isPrefixOf` child
      ] = Just (RawPathPrefixConflict parent child)
  | otherwise = Nothing
 where
  ordered = sort paths

orderProblem :: [FilePath] -> Maybe RawProblem
orderProblem paths
  | orderBypassed || paths == sort paths = Nothing
  | otherwise = Just RawEntryOrderInvalid

mixedFormatProblem :: [RawEntry] -> Maybe RawProblem
mixedFormatProblem entries
  | mixedFormatBypassed || allSame (map (Text.length . rawObjectIdentity) entries) = Nothing
  | otherwise = Just RawObjectFormatsMixed

inventoryCountGrammarProblem :: [RawEntry] -> Maybe RawProblem
inventoryCountGrammarProblem entries
  | null (filter isHaskellEntry entries) && not haskellEmptyBypassed = Just RawHaskellSubjectInventoryEmpty
  | null (filter isCabalEntry entries) && not cabalEmptyBypassed = Just RawCabalEntryInventoryEmpty
  | otherwise = Nothing

identityGrammarProblem :: Text -> [RawEntry] -> Maybe RawProblem
identityGrammarProblem claimedIdentity entries
  | not (validRawIdentity claimedIdentity) = Just RawIdentityMalformed
  | claimedIdentity /= expected && not identityMatchBypassed = Just (RawIdentityMismatch expected claimedIdentity)
  | otherwise = Nothing
 where
  expected = inventoryIdentity entries

validRawIdentity :: Text -> Bool
validRawIdentity value = Text.length value == 64 && Text.all lowercaseHex value
 where
  lowercaseHex character =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_HEX_WIDEN_MUTANT)
    asciiDigit character || (character >= 'a' && character <= 'g')
#else
    asciiDigit character || (character >= 'a' && character <= 'f')
#endif

inventoryIdentity :: [RawEntry] -> Text
inventoryIdentity entries =
  digestChunks
    (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
    ("amoebius.compiler-source-graph.raw.v1\0" : concatMap entryChunks entries)

entryChunks :: RawEntry -> [ByteString]
entryChunks entry =
  [ TextEncoding.encodeUtf8 (rawMode entry)
  , "\0"
  , TextEncoding.encodeUtf8 (rawObjectIdentity entry)
  , "\0"
  , TextEncoding.encodeUtf8 (Text.pack (rawPath entry))
  , "\0"
  , ByteString8.pack (show (ByteString.length (rawBytes entry)))
  , "\0"
  , rawBytes entry
  , "\0"
  ]

gitBlobIdentity :: Text -> ByteString -> Text
gitBlobIdentity shape bytes
  | Text.length shape == 40 =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA1)
        [gitBlobHeader bytes, bytes]
  | otherwise =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
        [gitBlobHeader bytes, bytes]

gitBlobHeader :: ByteString -> ByteString
gitBlobHeader bytes = ByteString8.pack ("blob " <> show (ByteString.length bytes) <> "\0")

digestChunks
  :: Crypto.HashAlgorithm algorithm
  => Crypto.Context algorithm
  -> [ByteString]
  -> Text
digestChunks initial chunks =
  Text.pack (show (Crypto.hashFinalize (List.foldl' Crypto.hashUpdate initial chunks)))

rawProblemFinding :: RawProblem -> Finding
rawProblemFinding problem = case problem of
  RawIdentityByteLimit limit observed -> resource "IDENTITY-BYTE-LIMIT" "claimed-identity" limit observed
  RawEntryLimit limit observed -> resource "ENTRY-LIMIT" "inventory" limit observed
  RawPathByteLimit ordinal limit observed -> resource "PATH-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawPathDepthLimit ordinal limit observed -> resource "PATH-DEPTH-LIMIT" (entrySubject ordinal) limit observed
  RawPathSegmentLimit ordinal limit observed -> resource "PATH-SEGMENT-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawModeByteLimit ordinal limit observed -> resource "MODE-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawObjectIdentityByteLimit ordinal limit observed -> resource "OBJECT-IDENTITY-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawBlobByteLimit ordinal limit observed -> resource "BLOB-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawAggregateBlobByteLimit limit observed -> resource "AGGREGATE-BLOB-BYTE-LIMIT" "inventory" limit observed
  RawHaskellSubjectLimit limit observed -> resource "HASKELL-SUBJECT-LIMIT" "inventory" limit observed
  RawCabalEntryLimit limit observed -> resource "CABAL-ENTRY-LIMIT" "inventory" limit observed
  RawIdentityMalformed -> grammar "IDENTITY-MALFORMED" "claimed-identity" "expected exactly 64 lowercase hexadecimal characters"
  RawIdentityMismatch expected observed -> grammar "IDENTITY-MISMATCH" "claimed-identity" ("expected=" <> expected <> "; observed=" <> observed)
  RawPathEmpty ordinal -> entryGrammar "PATH-EMPTY" ordinal "path must be nonempty"
  RawPathAbsolute ordinal -> entryGrammar "PATH-ABSOLUTE" ordinal "path must be relative"
  RawPathNul ordinal -> entryGrammar "PATH-NUL" ordinal "path must not contain NUL"
  RawPathBackslash ordinal -> entryGrammar "PATH-BACKSLASH" ordinal "path must use POSIX separators"
  RawPathEmptySegment ordinal -> entryGrammar "PATH-EMPTY-SEGMENT" ordinal "path segments must be nonempty"
  RawPathDotSegment ordinal -> entryGrammar "PATH-DOT-SEGMENT" ordinal "dot segments are forbidden"
  RawPathParentSegment ordinal -> entryGrammar "PATH-PARENT-SEGMENT" ordinal "parent segments are forbidden"
  RawPathCharacterUnsafe ordinal -> entryGrammar "PATH-CHARACTER-UNSAFE" ordinal "path contains a character outside the portable compiler-input alphabet"
  RawPathDuplicate path -> grammar "PATH-DUPLICATE" "inventory" ("duplicate path=" <> Text.pack path)
  RawPathPortableCaseCollision first second -> grammar "PATH-PORTABLE-CASE-COLLISION" "inventory" (Text.pack first <> " collides with " <> Text.pack second)
  RawPathPrefixConflict first second -> grammar "PATH-PREFIX-CONFLICT" "inventory" (Text.pack first <> " conflicts with " <> Text.pack second)
  RawEntryOrderInvalid -> grammar "ENTRY-ORDER-INVALID" "inventory" "paths must be in strict canonical ascending order"
  RawModeMalformed ordinal -> entryGrammar "MODE-MALFORMED" ordinal "expected one of 100644, 100755, or 120000"
  RawObjectIdentityMalformed ordinal -> entryGrammar "OBJECT-IDENTITY-MALFORMED" ordinal "expected 40 or 64 lowercase hexadecimal characters"
  RawObjectIdentityMismatch ordinal expected observed -> entryGrammar "OBJECT-IDENTITY-MISMATCH" ordinal ("expected=" <> expected <> "; observed=" <> observed)
  RawObjectFormatsMixed -> grammar "OBJECT-FORMATS-MIXED" "inventory" "all Git object identities must use one storage format"
  RawHaskellSubjectModeRejected ordinal -> entryGrammar "HASKELL-SUBJECT-MODE-REJECTED" ordinal "tracked .hs compiler subjects must use mode 100644"
  RawCabalEntryModeRejected ordinal -> entryGrammar "CABAL-ENTRY-MODE-REJECTED" ordinal "tracked .cabal compiler declarations must use mode 100644"
  RawHaskellSubjectInventoryEmpty -> grammar "HASKELL-SUBJECT-INVENTORY-EMPTY" "inventory" "at least one exact .hs subject is required"
  RawCabalEntryInventoryEmpty -> grammar "CABAL-ENTRY-INVENTORY-EMPTY" "inventory" "at least one exact .cabal declaration is required"
 where
  resource suffix subject limit observed =
    finding
      ("COMPILER-GRAPH-RAW-" <> suffix)
      subject
      ("limit=" <> Text.pack (show limit) <> "; observed-at-least=" <> Text.pack (show observed))
  grammar suffix subject detail = finding ("COMPILER-GRAPH-RAW-" <> suffix) subject detail
  entryGrammar suffix ordinal detail = grammar suffix (entrySubject ordinal) detail

entrySubject :: Int -> FilePath
entrySubject ordinal = "entry-" <> show ordinal

isHaskellEntry :: RawEntry -> Bool
isHaskellEntry = (== ".hs") . takeExtension . rawPath

isCabalEntry :: RawEntry -> Bool
isCabalEntry = (== ".cabal") . takeExtension . rawPath

safePathCharacter :: Char -> Bool
safePathCharacter character =
  isAsciiLower character
    || isAsciiUpper character
    || asciiDigit character
    || character `elem` ("._+-/" :: String)

asciiDigit :: Char -> Bool
asciiDigit character = character >= '0' && character <= '9'

splitSlash :: FilePath -> [FilePath]
splitSlash value = case break (== '/') value of
  (part, []) -> [part]
  (part, _ : rest) -> part : splitSlash rest

boundedFilePathUtf8Length :: Int -> FilePath -> BoundedPrefix ()
boundedFilePathUtf8Length limit = boundedUtf8Length limit

boundedTextUtf8Length :: Int -> Text -> BoundedPrefix ()
boundedTextUtf8Length limit = boundedUtf8Length limit . Text.unpack

boundedUtf8Length :: Int -> String -> BoundedPrefix ()
boundedUtf8Length limit = go 0
 where
  go count remaining = case remaining of
    [] -> PrefixWithin []
    character : rest ->
      let next = count + utf8Width character
       in if next > limit then PrefixExceeded next else go next rest

utf8Width :: Char -> Int
utf8Width character
  | code <= 0x7f = 1
  | code <= 0x7ff = 2
  | code <= 0xffff = 3
  | otherwise = 4
 where
  code = ord character

exceeded :: BoundedPrefix () -> (Int -> RawProblem) -> Maybe RawProblem
exceeded bounded constructor = case bounded of
  PrefixExceeded observed -> Just (constructor observed)
  PrefixWithin _ -> Nothing

firstJust :: [Maybe value] -> Maybe value
firstJust values = case values of
  [] -> Nothing
  Just value : _ -> Just value
  Nothing : rest -> firstJust rest

orElse :: Maybe value -> Maybe value -> Maybe value
orElse first second = case first of
  Just _ -> first
  Nothing -> second

listHead :: [value] -> Maybe value -> Maybe value
listHead values fallback = case values of
  value : _ -> Just value
  [] -> fallback

decimalText :: Int -> Text
decimalText = Text.pack . show

allSame :: Eq value => [value] -> Bool
allSame values = case values of
  [] -> True
  first : rest -> all (== first) rest

groupByKey :: Eq key => [(key, value)] -> [[(key, value)]]
groupByKey values = case values of
  [] -> []
  first@(key, _) : rest ->
    let (same, remaining) = span ((== key) . fst) rest
     in (first : same) : groupByKey remaining

pathEmptyBypassed, pathAbsoluteBypassed, pathNulBypassed, pathBackslashBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_BYPASS_MUTANT)
pathEmptyBypassed = True
#else
pathEmptyBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_ABSOLUTE_BYPASS_MUTANT)
pathAbsoluteBypassed = True
#else
pathAbsoluteBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_NUL_BYPASS_MUTANT)
pathNulBypassed = True
#else
pathNulBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_BACKSLASH_BYPASS_MUTANT)
pathBackslashBypassed = True
#else
pathBackslashBypassed = False
#endif

pathEmptySegmentBypassed, pathDotBypassed, pathParentBypassed, pathCharacterBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_SEGMENT_BYPASS_MUTANT)
pathEmptySegmentBypassed = True
#else
pathEmptySegmentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DOT_BYPASS_MUTANT)
pathDotBypassed = True
#else
pathDotBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_PARENT_BYPASS_MUTANT)
pathParentBypassed = True
#else
pathParentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_CHARACTER_BYPASS_MUTANT)
pathCharacterBypassed = True
#else
pathCharacterBypassed = False
#endif

duplicatePathBypassed, portableCaseBypassed, prefixBypassed, orderBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_BYPASS_MUTANT)
duplicatePathBypassed = True
#else
duplicatePathBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_CASE_BYPASS_MUTANT)
portableCaseBypassed = True
#else
portableCaseBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_BYPASS_MUTANT)
prefixBypassed = True
#else
prefixBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ORDER_BYPASS_MUTANT)
orderBypassed = True
#else
orderBypassed = False
#endif

objectContentBypassed, mixedFormatBypassed, identityMatchBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_CONTENT_BYPASS_MUTANT)
objectContentBypassed = True
#else
objectContentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MIXED_FORMAT_BYPASS_MUTANT)
mixedFormatBypassed = True
#else
mixedFormatBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MATCH_BYPASS_MUTANT)
identityMatchBypassed = True
#else
identityMatchBypassed = False
#endif

haskellModeBypassed, cabalModeBypassed, haskellEmptyBypassed, cabalEmptyBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_MODE_BYPASS_MUTANT)
haskellModeBypassed = True
#else
haskellModeBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_MODE_BYPASS_MUTANT)
cabalModeBypassed = True
#else
cabalModeBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_EMPTY_BYPASS_MUTANT)
haskellEmptyBypassed = True
#else
haskellEmptyBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_EMPTY_BYPASS_MUTANT)
cabalEmptyBypassed = True
#else
cabalEmptyBypassed = False
#endif
