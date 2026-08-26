{-# LANGUAGE OverloadedStrings #-}

module SourceClosureOracle
  ( runSourceClosureOracle
  , runSourceClosureSelectorOracle
  , sourceClosureSelectorNames
  ) where

-- Component diagnostics only. Every comparison is an exact, ordered,
-- whole-CheckResult comparison through the single public raw facade. This
-- oracle imports no production parser, classifier, model, bound, fixture, or
-- projection and performs no Git, pb, network, hardware, or container action.

import Amoebius.Validation.SourceClosure (sourceClosureDiagnostic)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sortOn)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.Encoding.Error qualified as TextError
import Data.Word (Word8)

data WireEntry = WireEntry
  { wirePath :: FilePath
  , wireMode :: Text
  , wireObject :: Text
  , wireBytes :: ByteString
  }
  deriving (Eq, Show)

data ObjectFormat = ObjectSha1 | ObjectSha256
  deriving (Eq, Show)

data ExpectedClass
  = ExpectedHaskell
  | ExpectedDocumentation
  | ExpectedProject
  | ExpectedLegacy Text
  | ExpectedUnregistered
  deriving (Eq, Show)

data ExpectedFacet
  = ExpectedExecutable
  | ExpectedShebang Text
  | ExpectedSymlink Text
  | ExpectedBinary
  | ExpectedForeign Text
  deriving (Eq, Show)

data ExpectedPath = ExpectedPath
  { expectedEntry :: WireEntry
  , expectedClass :: ExpectedClass
  , expectedFacets :: [ExpectedFacet]
  , expectedReasons :: [Text]
  }
  deriving (Eq, Show)

data ExpectedFailure = ExpectedFailure
  { failureCommitmentKind :: Text
  , failureCommitmentSha256 :: Text
  , failureClaimedObservation :: Text
  , failureEntryCount :: Text
  , failureAggregateBytes :: Text
  , failureComputedSnapshot :: Text
  , failureProblemCount :: Text
  , failureFindingsWithoutCommitment :: [Finding]
  }

data RawCommitment = RawCommitment Text Text

maximumIdentityBytes, maximumEntries, maximumPathBytes, maximumPathDepth :: Int
maximumIdentityBytes = 64
maximumEntries = 16384
maximumPathBytes = 1024
maximumPathDepth = 64

maximumSegmentBytes, maximumModeBytes, maximumObjectBytes, maximumBlobBytes :: Int
maximumSegmentBytes = 255
maximumModeBytes = 6
maximumObjectBytes = 64
maximumBlobBytes = 16777216

maximumAggregateBytes, maximumSemanticBytes, maximumProblems, maximumResultFindings :: Int
maximumAggregateBytes = 33554432
maximumSemanticBytes = 4096
maximumProblems = 128
maximumResultFindings = 196

-- Independently literal selector-to-case intent.  Production CPP declarations
-- and Cabal mappings are reconciled against these names by the external
-- diagnostic; neither is used to construct this closed inventory.
sourceClosureSelectorIntents :: [(String, String)]
sourceClosureSelectorIntents =
  [ ("VALIDATION_SOURCE_CLOSURE_AGGREGATE_BLOB_BYTE_LIMIT_BYPASS_MUTANT", "aggregate blob bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_BINARY_FACET_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_BLOB_BYTE_LIMIT_BYPASS_MUTANT", "blob bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_BLOB_SHA1_MATCH_BYPASS_MUTANT", "blob object identity recomputes ObjectSha1")
  , ("VALIDATION_SOURCE_CLOSURE_BLOB_SHA256_MATCH_BYPASS_MUTANT", "blob object identity recomputes ObjectSha256")
  , ("VALIDATION_SOURCE_CLOSURE_CASE_COLLISION_BYPASS_MUTANT", "portable case collision refuses exactly")
  , ("VALIDATION_SOURCE_CLOSURE_CUSTODY_BYPASS_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_DHALL_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_DHALL_SUFFIX_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_DIAGNOSTIC_BYPASS_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_DISCOVERY_BYPASS_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_DOCUMENT_INVENTORY_WIDEN_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_DUPLICATE_PATH_BYPASS_MUTANT", "duplicate paths refuse exactly")
  , ("VALIDATION_SOURCE_CLOSURE_EMPTY_INVENTORY_BYPASS_MUTANT", "empty inventory refuses exactly")
  , ("VALIDATION_SOURCE_CLOSURE_ENTRY_LIMIT_BYPASS_MUTANT", "entry count maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_ENTRY_ORDER_BYPASS_MUTANT", "entry order is exact")
  , ("VALIDATION_SOURCE_CLOSURE_EXECUTABLE_FACET_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_GENERATED_BUILD_CLASS_REDIRECT_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_GENERATED_DATA_CLASS_REDIRECT_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_GENERATED_TEST_DATA_CLASS_REDIRECT_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_APP_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_FOREIGN_SIGNATURE_BYPASS_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_PROBE_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_SRC_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_SUFFIX_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_HASKELL_TEST_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_IDENTITY_ALPHABET_BYPASS_MUTANT", "claimed identity alphabet is lowercase hexadecimal")
  , ("VALIDATION_SOURCE_CLOSURE_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT", "claimed identity bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_IDENTITY_MATCH_BYPASS_MUTANT", "claimed snapshot identity is joined exactly")
  , ("VALIDATION_SOURCE_CLOSURE_IDENTITY_WIDTH_BYPASS_MUTANT", "claimed identity width is exact")
  , ("VALIDATION_SOURCE_CLOSURE_INVALID_UTF8_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_MIXED_OBJECT_FORMAT_BYPASS_MUTANT", "mixed object formats refuse exactly")
  , ("VALIDATION_SOURCE_CLOSURE_MODE_BYTE_LIMIT_BYPASS_MUTANT", "mode bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_MODE_EXECUTABLE_REMOVAL_MUTANT", "all three exact Git mode identifiers remain distinct")
  , ("VALIDATION_SOURCE_CLOSURE_MODE_REGULAR_REMOVAL_MUTANT", "all three exact Git mode identifiers remain distinct")
  , ("VALIDATION_SOURCE_CLOSURE_MODE_SYMLINK_REMOVAL_MUTANT", "all three exact Git mode identifiers remain distinct")
  , ("VALIDATION_SOURCE_CLOSURE_NONCODE_FOREIGN_SIGNATURE_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_OBJECT_ID_ALPHABET_BYPASS_MUTANT", "object identity alphabet is lowercase hexadecimal")
  , ("VALIDATION_SOURCE_CLOSURE_OBJECT_ID_BYTE_LIMIT_BYPASS_MUTANT", "object identity bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_OBJECT_ID_WIDTH_BYPASS_MUTANT", "object identity width is closed")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_ALPHABET_BYPASS_MUTANT", "path alphabet")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_AT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_BYTE_LIMIT_BYPASS_MUTANT", "portable path bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_COMMA_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_DEPTH_LIMIT_BYPASS_MUTANT", "portable path depth maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_DIGIT_RANGE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_DOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_DOT_SEGMENT_BYPASS_MUTANT", "dot path segment")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_EMPTY_SEGMENT_BYPASS_MUTANT", "empty path segment")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_GIT_SEGMENT_BYPASS_MUTANT", "repository-control path segment")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_HYPHEN_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_LOWER_RANGE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_NONEMPTY_BYPASS_MUTANT", "empty path")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_PARENT_SEGMENT_BYPASS_MUTANT", "parent path segment")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_PLUS_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RELATIVE_BYPASS_MUTANT", "absolute path")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_AUX_BYPASS_MUTANT", "reserved core AUX")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_CASEFOLD_BYPASS_MUTANT", "reserved case fold")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM1_BYPASS_MUTANT", "reserved COM range")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM2_BYPASS_MUTANT", "reserved COM2")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM3_BYPASS_MUTANT", "reserved COM3")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM4_BYPASS_MUTANT", "reserved COM4")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM5_BYPASS_MUTANT", "reserved COM5")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM6_BYPASS_MUTANT", "reserved COM6")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM7_BYPASS_MUTANT", "reserved COM7")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM8_BYPASS_MUTANT", "reserved COM8")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_COM9_BYPASS_MUTANT", "reserved COM9")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_CON_BYPASS_MUTANT", "reserved core")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_EXTENSION_BYPASS_MUTANT", "reserved extension")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT1_BYPASS_MUTANT", "reserved LPT range")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT2_BYPASS_MUTANT", "reserved LPT2")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT3_BYPASS_MUTANT", "reserved LPT3")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT4_BYPASS_MUTANT", "reserved LPT4")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT5_BYPASS_MUTANT", "reserved LPT5")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT6_BYPASS_MUTANT", "reserved LPT6")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT7_BYPASS_MUTANT", "reserved LPT7")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT8_BYPASS_MUTANT", "reserved LPT8")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_LPT9_BYPASS_MUTANT", "reserved LPT9")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_NUL_BYPASS_MUTANT", "reserved core NUL")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_RESERVED_PRN_BYPASS_MUTANT", "reserved core PRN")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT", "portable segment bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_SLASH_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_TRAILING_DOT_BYPASS_MUTANT", "trailing-dot path segment")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_UNDERSCORE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PATH_UPPER_RANGE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PB_DIAGNOSTIC_RETENTION_DROP_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_PB_FIRST_RUNTIME_RETENTION_DROP_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_PB_ROOT_REMOVAL_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_PREFIX_CONFLICT_BYPASS_MUTANT", "portable prefix conflict survives an intervening sibling")
  , ("VALIDATION_SOURCE_CLOSURE_PROBE_DEBT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROBLEM_LIMIT_BYPASS_MUTANT", "problem traversal maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_AMOEBIUS_CABAL_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_CABAL_PROJECT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_DOCKERIGNORE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_EDITORCONFIG_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_GITATTRIBUTES_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_GITIGNORE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROJECT_PROBE_CABAL_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROTO_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PROTO_SUFFIX_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_PULUMI_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_RESULT_FINDING_LIMIT_BYPASS_MUTANT", "result findings maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_SEMANTIC_LINE_BYTE_LIMIT_BYPASS_MUTANT", "semantic inspection bytes maximum plus one")
  , ("VALIDATION_SOURCE_CLOSURE_SHEBANG_FACET_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_JAVASCRIPT_CONST_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_JAVASCRIPT_FUNCTION_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_JSON_OBJECT_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_PROTO_SCHEMA_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_PYTHON_DEF_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_PYTHON_FROM_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_SHEBANG_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_SHELL_SET_E_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SIGNATURE_XML_DOCUMENT_REMOVAL_MUTANT", "foreign signature identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_SNAPSHOT_BYTE_COMMITMENT_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_SNAPSHOT_FORMAT_COMMITMENT_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_SNAPSHOT_MODE_COMMITMENT_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_SNAPSHOT_OBJECT_COMMITMENT_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_SNAPSHOT_PATH_COMMITMENT_MUTANT", "canonical SHA-1 pb refusal retains the entire ordered residue")
  , ("VALIDATION_SOURCE_CLOSURE_SYMLINK_FACET_BYPASS_MUTANT", "mode and structural facet catalog")
  , ("VALIDATION_SOURCE_CLOSURE_TEST_DEBT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_TOOLS_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_UI_PACKAGE_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_UI_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  , ("VALIDATION_SOURCE_CLOSURE_VENDOR_ROOT_REMOVAL_MUTANT", "closed primary-class and project identifier catalog")
  ]

runSourceClosureOracle :: IO ()
runSourceClosureOracle = do
  caseProblems <- case literalIntegrityProblems of
    [] -> firstFailingCase exactCases
    _ -> pure []
  let problems = literalIntegrityProblems <> caseProblems
  unless
    (null problems)
    (fail (unlines ("SourceClosureOracle component diagnostics failed:" : map ("  " <>) problems)))

-- | Run the independently declared exact case assigned to one production
-- selector.  The mutation driver obtains its selector inventory from
-- 'sourceClosureSelectorNames'; production discovery is not authoritative.
runSourceClosureSelectorOracle :: String -> IO ()
runSourceClosureSelectorOracle selector = do
  caseProblems <- case literalIntegrityProblems of
    [] -> case (selectorTargets selector, selectorExactCases selector) of
      ([_], [candidate]) -> runExactCase candidate
      (targets, candidates) ->
        pure
          [ "selector intent is not exactly resolvable: selector="
              <> selector
              <> "; targets="
              <> show targets
              <> "; exact-case-count="
              <> show (length candidates)
          ]
    _ -> pure []
  let problems = literalIntegrityProblems <> caseProblems
  unless
    (null problems)
    (fail (unlines ("SourceClosureOracle selector diagnostics failed:" : map ("  " <>) problems)))

selectorTargets :: String -> [String]
selectorTargets selector =
  [ target
  | (candidate, target) <- sourceClosureSelectorIntents
  , candidate == selector
  ]

selectorExactCases :: String -> [ExactCase]
selectorExactCases selector =
  [ candidate
  | target <- selectorTargets selector
  , candidate@(label, _, _) <- exactCases
  , label == target
  ]

firstFailingCase :: [ExactCase] -> IO [String]
firstFailingCase cases = case cases of
  [] -> pure []
  candidate : remaining -> do
    problems <- runExactCase candidate
    if null problems then firstFailingCase remaining else pure problems

literalIntegrityProblems :: [String]
literalIntegrityProblems =
  [ "canonical pb literal byte count changed"
  | ByteString.length canonicalPbBytes /= 4770
  ]
    <> [ "canonical pb literal SHA-256 changed"
       | sha256Hex canonicalPbBytes
           /= "e210494d3ad4bcaad716daed5bb89cb5611107547e83eb018a6369e134cd5418"
       ]
    <> [ "selector intent cardinality changed: expected=124; observed=" <> show (length sourceClosureSelectorIntents)
       | length sourceClosureSelectorIntents /= 124
       ]
    <> [ "duplicate selector intent: " <> selector
       | selector <- duplicateStrings sourceClosureSelectorNames
       ]
    <> [ "duplicate exact-case label: " <> label
       | label <- duplicateStrings exactCaseLabels
       ]
    <> [ "selector target must occur exactly once: selector="
           <> selector
           <> "; target="
           <> target
           <> "; observed="
           <> show (occurrenceCount target exactCaseLabels)
       | (selector, target) <- sourceClosureSelectorIntents
       , occurrenceCount target exactCaseLabels /= 1
       ]

sourceClosureSelectorNames :: [String]
sourceClosureSelectorNames = map fst sourceClosureSelectorIntents

exactCaseLabels :: [String]
exactCaseLabels = [label | (label, _, _) <- exactCases]

duplicateStrings :: [String] -> [String]
duplicateStrings = Set.toAscList . snd . foldl remember (Set.empty, Set.empty)
 where
  remember (seen, repeated) value
    | Set.member value seen = (seen, Set.insert value repeated)
    | otherwise = (Set.insert value seen, repeated)

occurrenceCount :: String -> [String] -> Int
occurrenceCount expected = go 0
 where
  go count values = case values of
    [] -> count
    value : remaining -> go (if value == expected then count + 1 else count) remaining

type ExactCase = (String, CheckResult, CheckResult)

runExactCase :: ExactCase -> IO [String]
runExactCase (label, expected, actual) =
  pure
    [ label <> ": exact ordered CheckResult mismatch; " <> firstResultDifference expected actual
    | expected /= actual
    ]

firstResultDifference :: CheckResult -> CheckResult -> String
firstResultDifference expected actual
  | checkName expected /= checkName actual =
      "checkName expected=" <> show (checkName expected) <> "; actual=" <> show (checkName actual)
  | otherwise = case firstListDifference (checkObservations expected) (checkObservations actual) of
      Just detail -> "observations " <> detail
      Nothing -> case firstListDifference (checkFindings expected) (checkFindings actual) of
        Just detail -> "findings " <> detail
        Nothing -> "equality disagreed without a field-level divergence"

firstListDifference :: (Eq value, Show value) => [value] -> [value] -> Maybe String
firstListDifference = go (0 :: Int)
 where
  go ordinal expected actual = case (expected, actual) of
    ([], []) -> Nothing
    (left : leftRest, right : rightRest)
      | left == right -> go (ordinal + 1) leftRest rightRest
      | otherwise -> Just ("ordinal=" <> show ordinal <> "; expected=" <> show left <> "; actual=" <> show right)
    ([], right) -> Just ("ordinal=" <> show ordinal <> "; expected end; actual tail=" <> show right)
    (left, []) -> Just ("ordinal=" <> show ordinal <> "; expected tail=" <> show left <> "; actual end")

exactCases :: [ExactCase]
exactCases =
  canonicalCases
    <> resourceBoundaryCases
    <> grammarCases
    <> inventoryCases
    <> classificationCases
    <> problemAndResultBoundaryCases

canonicalCases :: [ExactCase]
canonicalCases =
  [ successCase "canonical SHA-1 pb refusal retains the entire ordered residue" ObjectSha1 [pbEntry ObjectSha1]
  , successCase "canonical SHA-256 pb refusal retains the entire ordered residue" ObjectSha256 [pbEntry ObjectSha256]
  , identityMismatchCase
  ]

successCase :: String -> ObjectFormat -> [WireEntry] -> ExactCase
successCase label objectFormat entries =
  let claimed = expectedSnapshotIdentity objectFormat entries
   in (label, expectedSuccess objectFormat claimed entries, runFacade claimed entries)

identityMismatchCase :: ExactCase
identityMismatchCase =
  let entries = [pbEntry ObjectSha1]
      claimed = Text.replicate 64 "0"
      computed = expectedSnapshotIdentity ObjectSha1 entries
      commitment = completeCommitment claimed entries
      expected =
        expectedFailure
          ExpectedFailure
            { failureCommitmentKind = "complete-input"
            , failureCommitmentSha256 = commitment
            , failureClaimedObservation = claimed
            , failureEntryCount = "1"
            , failureAggregateBytes = "4770"
            , failureComputedSnapshot = computed
            , failureProblemCount = "1"
            , failureFindingsWithoutCommitment =
                [ Finding
                    "SOURCE-CLOSURE-IDENTITY-MISMATCH"
                    "<claimed-snapshot>"
                    ("expected=" <> computed <> "; observed=" <> claimed)
                ]
            }
   in ("claimed snapshot identity is joined exactly", expected, runFacade claimed entries)

runFacade :: Text -> [WireEntry] -> CheckResult
runFacade claimed entries = sourceClosureDiagnostic claimed (map wireTuple entries)

wireTuple :: WireEntry -> (FilePath, Text, Text, ByteString)
wireTuple entry = (wirePath entry, wireMode entry, wireObject entry, wireBytes entry)

expectedSuccess :: ObjectFormat -> Text -> [WireEntry] -> CheckResult
expectedSuccess objectFormat claimed entries =
  CheckResult
    { checkName = "source-closure-diagnostic"
    , checkObservations = expectedObservations
    , checkFindings = boundedExpectedFindings
    }
 where
  commitment = RawCommitment "complete-input" (completeCommitment claimed entries)
  classified = map expectedClassify entries
  classDigest = expectedClassificationDigest classified
  classCounts = expectedClassCounts classified
  snapshot = expectedSnapshotIdentity objectFormat entries
  dynamicFindings = expectedUnregisteredFindings commitment classified <> expectedPbFindings commitment
  candidateFindings = mandatoryExpectedFindings commitment <> dynamicFindings
  boundedExpectedFindings
    | lengthAtLeast (maximumResultFindings + 1) candidateFindings =
        mandatoryExpectedFindings commitment
          <> [ Finding
                "SOURCE-CLOSURE-RESULT-FINDING-LIMIT"
                "<raw-source-closure>"
                (limitDetail maximumResultFindings (maximumResultFindings + 1) <> commitmentDetail commitment)
             ]
    | otherwise = candidateFindings
  expectedObservations =
    successObservations
      commitment
      claimed
      (Text.pack (show (length entries)))
      (Text.pack (show (sum (map (ByteString.length . wireBytes) entries))))
      snapshot
      classDigest
      classCounts

successObservations
  :: RawCommitment
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> [Text]
  -> [Observation]
successObservations (RawCommitment kind digest) claimed entryCount aggregate snapshot classification counts =
  [ Observation "source-closure.input-commitment.kind" kind
  , Observation "source-closure.input-commitment.sha256" digest
  , Observation "source-closure.input.claimed-snapshot" claimed
  , Observation "source-closure.input.entry-count" entryCount
  , Observation "source-closure.input.aggregate-blob-bytes" aggregate
  , Observation "source-closure.derived.snapshot" snapshot
  , Observation "source-closure.derived.classification-sha256" classification
  , Observation "source-closure.derived.haskell-count" (countAt 0 counts)
  , Observation "source-closure.derived.documentation-count" (countAt 1 counts)
  , Observation "source-closure.derived.project-count" (countAt 2 counts)
  , Observation "source-closure.derived.pb-debt-count" (countAt 3 counts)
  , Observation "source-closure.derived.legacy-count" (countAt 4 counts)
  , Observation "source-closure.derived.unregistered-count" (countAt 5 counts)
  , Observation "source-closure.preflight.problem-count" "0"
  , Observation "source-closure.diagnostic-status" "refused"
  ]

countAt :: Int -> [Text] -> Text
countAt index values = go index values
 where
  go remaining items = case (remaining, items) of
    (0, value : _) -> value
    (_, _ : rest) -> go (remaining - 1) rest
    (_, []) -> "unavailable"

expectedFailure :: ExpectedFailure -> CheckResult
expectedFailure failure =
  CheckResult
    { checkName = "source-closure-diagnostic"
    , checkObservations =
        [ Observation "source-closure.input-commitment.kind" (failureCommitmentKind failure)
        , Observation "source-closure.input-commitment.sha256" (failureCommitmentSha256 failure)
        , Observation "source-closure.input.claimed-snapshot" (failureClaimedObservation failure)
        , Observation "source-closure.input.entry-count" (failureEntryCount failure)
        , Observation "source-closure.input.aggregate-blob-bytes" (failureAggregateBytes failure)
        , Observation "source-closure.derived.snapshot" (failureComputedSnapshot failure)
        , Observation "source-closure.derived.classification-sha256" "unavailable"
        , Observation "source-closure.derived.haskell-count" "unavailable"
        , Observation "source-closure.derived.documentation-count" "unavailable"
        , Observation "source-closure.derived.project-count" "unavailable"
        , Observation "source-closure.derived.pb-debt-count" "unavailable"
        , Observation "source-closure.derived.legacy-count" "unavailable"
        , Observation "source-closure.derived.unregistered-count" "unavailable"
        , Observation "source-closure.preflight.problem-count" (failureProblemCount failure)
        , Observation "source-closure.diagnostic-status" "refused"
        ]
    , checkFindings =
        mandatoryExpectedFindings commitment
          <> map (appendFindingCommitment commitment) (failureFindingsWithoutCommitment failure)
    }
 where
  commitment = RawCommitment (failureCommitmentKind failure) (failureCommitmentSha256 failure)

mandatoryExpectedFindings :: RawCommitment -> [Finding]
mandatoryExpectedFindings commitment =
  [ Finding
      "SOURCE-CLOSURE-DIAGNOSTIC-ONLY"
      "<raw-source-closure>"
      ("caller-supplied source inventory is diagnostic input and cannot mint source-closure evidence" <> commitmentDetail commitment)
  , Finding
      "SOURCE-CLOSURE-AUTHENTICATED-CUSTODY-UNAVAILABLE"
      "<raw-source-closure>"
      ("no authenticated network-independent source-custody authority is attached" <> commitmentDetail commitment)
  , Finding
      "SOURCE-CLOSURE-ATOMIC-COMPLETE-DISCOVERY-UNAVAILABLE"
      "<raw-source-closure>"
      ("caller tuples cannot prove atomic tracked, ignored, untracked, special-file, and replacement-race discovery" <> commitmentDetail commitment)
  ]

appendFindingCommitment :: RawCommitment -> Finding -> Finding
appendFindingCommitment commitment item =
  item {findingDetail = findingDetail item <> commitmentDetail commitment}

commitmentDetail :: RawCommitment -> Text
commitmentDetail (RawCommitment kind digest) =
  "; source-closure.input-commitment-kind="
    <> kind
    <> "; source-closure.input-commitment-sha256="
    <> digest

limitDetail :: Int -> Int -> Text
limitDetail maximumValue observed =
  "maximum=" <> decimal maximumValue <> "; observed-at-least=" <> decimal observed

decimal :: Int -> Text
decimal = Text.pack . show

lengthAtLeast :: Int -> [value] -> Bool
lengthAtLeast limit = go 0
 where
  go count _ | count >= limit = True
  go _ [] = False
  go count (_ : rest) = go (count + 1) rest

-- Case groups are declared below their independent expected-wire helpers.
resourceBoundaryCases, grammarCases, inventoryCases, classificationCases, problemAndResultBoundaryCases :: [ExactCase]
resourceBoundaryCases =
  [ successCase "entry count exact maximum" ObjectSha1 exactEntryBoundary
  , boundedProblemCase
      "entry count maximum plus one"
      zeroIdentity
      overEntryBoundary
      "16385+"
      "unavailable"
      ["entries:16384:16385"]
      [resourceFinding "SOURCE-CLOSURE-ENTRY-LIMIT" "<raw-source-closure>" maximumEntries (maximumEntries + 1)]
  , successCase "portable path bytes exact maximum" ObjectSha1 (sortedWithPb [wireEntry ObjectSha1 exactPath1024 "100644" "x\n"])
  , boundedSingleEntryResourceCase
      "portable path bytes maximum plus one"
      (wireEntry ObjectSha1 overPath1025 "100644" "x\n")
      "path-bytes:1:1024:1025"
      (resourceFinding "SOURCE-CLOSURE-PATH-BYTE-LIMIT" "<entry-1>" maximumPathBytes (maximumPathBytes + 1))
  , successCase "portable path depth exact maximum" ObjectSha1 (sortedWithPb [wireEntry ObjectSha1 exactDepth64 "100644" "x\n"])
  , boundedSingleEntryResourceCase
      "portable path depth maximum plus one"
      (wireEntry ObjectSha1 overDepth65 "100644" "x\n")
      "path-depth:1:64:65"
      (resourceFinding "SOURCE-CLOSURE-PATH-DEPTH-LIMIT" "<entry-1>" maximumPathDepth (maximumPathDepth + 1))
  , successCase "portable segment bytes exact maximum" ObjectSha1 (sortedWithPb [wireEntry ObjectSha1 exactSegment255 "100644" "x\n"])
  , boundedSingleEntryResourceCase
      "portable segment bytes maximum plus one"
      (wireEntry ObjectSha1 overSegment256 "100644" "x\n")
      "path-segment-bytes:1:255:256"
      (resourceFinding "SOURCE-CLOSURE-PATH-SEGMENT-BYTE-LIMIT" "<entry-1>" maximumSegmentBytes (maximumSegmentBytes + 1))
  , boundedSingleEntryResourceCase
      "mode bytes maximum plus one"
      ((wireEntry ObjectSha1 "src/A.hs" "100644" "x\n") {wireMode = "1006440"})
      "mode-bytes:1:6:7"
      (resourceFinding "SOURCE-CLOSURE-MODE-BYTE-LIMIT" "<entry-1>" maximumModeBytes (maximumModeBytes + 1))
  , boundedSingleEntryResourceCase
      "object identity bytes maximum plus one"
      ((wireEntry ObjectSha1 "src/A.hs" "100644" "x\n") {wireObject = Text.replicate 65 "0"})
      "object-id-bytes:1:64:65"
      (resourceFinding "SOURCE-CLOSURE-OBJECT-ID-BYTE-LIMIT" "<entry-1>" maximumObjectBytes (maximumObjectBytes + 1))
  , successCase "blob bytes exact maximum" ObjectSha1 exactBlobBoundary
  , boundedSingleEntryResourceCase
      "blob bytes maximum plus one"
      (wireEntry ObjectSha1 "large/blob.txt" "100644" (significantBlob (maximumBlobBytes + 1)))
      "blob-bytes:1:16777216:16777217"
      (resourceFinding "SOURCE-CLOSURE-BLOB-BYTE-LIMIT" "<entry-1>" maximumBlobBytes (maximumBlobBytes + 1))
  , successCase "aggregate blob bytes exact maximum" ObjectSha1 exactAggregateBoundary
  , boundedProblemCase
      "aggregate blob bytes maximum plus one"
      zeroIdentity
      overAggregateBoundary
      "3"
      "unavailable"
      ["aggregate-blob-bytes:33554432:33554433"]
      [resourceFinding "SOURCE-CLOSURE-AGGREGATE-BLOB-BYTE-LIMIT" "<raw-source-closure>" maximumAggregateBytes (maximumAggregateBytes + 1)]
  , successCase "semantic inspection bytes exact maximum" ObjectSha1 exactSemanticBoundary
  , boundedSingleEntryResourceCase
      "semantic inspection bytes maximum plus one"
      (wireEntry ObjectSha1 "src/LongLine.hs" "100644" (ByteString8.replicate (maximumSemanticBytes + 1) 'x'))
      "semantic-line-bytes:1:4096:4097"
      (resourceFinding "SOURCE-CLOSURE-SEMANTIC-LINE-BYTE-LIMIT" "<entry-1>" maximumSemanticBytes (maximumSemanticBytes + 1))
  , boundedProblemCase
      "claimed identity bytes maximum plus one"
      (Text.replicate (maximumIdentityBytes + 1) "0")
      [pbEntry ObjectSha1]
      "unavailable"
      "unavailable"
      ["identity-bytes:64:65"]
      [resourceFinding "SOURCE-CLOSURE-IDENTITY-BYTE-LIMIT" "<claimed-snapshot>" maximumIdentityBytes (maximumIdentityBytes + 1)]
  ]

boundedSingleEntryResourceCase :: String -> WireEntry -> Text -> Finding -> ExactCase
boundedSingleEntryResourceCase label entry tag expectedFinding =
  boundedProblemCase
    label
    zeroIdentity
    [entry]
    "1"
    aggregateObservation
    [tag]
    [expectedFinding]
 where
  aggregateObservation = decimal (ByteString.length (wireBytes entry))

boundedProblemCase
  :: String
  -> Text
  -> [WireEntry]
  -> Text
  -> Text
  -> [Text]
  -> [Finding]
  -> ExactCase
boundedProblemCase label claimed entries entryCount aggregate tags findings =
  let commitment = boundedRefusalCommitment claimed entries tags
      claimedObservation
        | Text.length claimed > maximumIdentityBytes = "<over-limit>"
        | otherwise = claimed
      expected =
        expectedFailure
          ExpectedFailure
            { failureCommitmentKind = "bounded-preflight-refusal"
            , failureCommitmentSha256 = commitment
            , failureClaimedObservation = claimedObservation
            , failureEntryCount = entryCount
            , failureAggregateBytes = aggregate
            , failureComputedSnapshot = "unavailable"
            , failureProblemCount = decimal (length findings)
            , failureFindingsWithoutCommitment = findings
            }
   in (label, expected, runFacade claimed entries)

boundedRefusalCommitment :: Text -> [WireEntry] -> [Text] -> Text
boundedRefusalCommitment claimed entries tags =
  sha256Hex
    ( ByteString.concat
        ( "amoebius-source-closure-bounded-refusal-v1\0"
            : lengthText (Text.take (maximumIdentityBytes + 1) claimed)
            : lengthText entryState
            : map lengthText tags
        )
    )
 where
  entryState
    | lengthAtLeast (maximumEntries + 1) entries = "exceeded-at-least:16385"
    | otherwise = "within:" <> decimal (length entries)

resourceFinding :: Text -> FilePath -> Int -> Int -> Finding
resourceFinding code subject maximumValue observed =
  Finding code subject (limitDetail maximumValue observed)

zeroIdentity :: Text
zeroIdentity = Text.replicate 64 "0"

exactEntryBoundary, overEntryBoundary :: [WireEntry]
exactEntryBoundary = sortOn wirePath (pbEntry ObjectSha1 : numberedEntries "tools/e" (maximumEntries - 1) "100644" "x\n")
overEntryBoundary = sortOn wirePath (pbEntry ObjectSha1 : numberedEntries "tools/o" maximumEntries "100644" "x\n")

numberedEntries :: FilePath -> Int -> Text -> ByteString -> [WireEntry]
numberedEntries prefix count mode bytes =
  [wireEntry ObjectSha1 (prefix <> pad5 ordinal <> ".txt") mode bytes | ordinal <- [0 .. count - 1]]

pad5 :: Int -> String
pad5 value = replicate (5 - length rendered) '0' <> rendered
 where
  rendered = show value

exactPath1024, overPath1025, exactDepth64, overDepth65, exactSegment255, overSegment256 :: FilePath
exactPath1024 = joinPathSegments [255, 255, 255, 254, 1]
overPath1025 = joinPathSegments [255, 255, 255, 255, 1]
exactDepth64 = Text.unpack (Text.intercalate "/" (replicate maximumPathDepth "a"))
overDepth65 = Text.unpack (Text.intercalate "/" (replicate (maximumPathDepth + 1) "a"))
exactSegment255 = "misc/" <> replicate maximumSegmentBytes 's'
overSegment256 = "misc/" <> replicate (maximumSegmentBytes + 1) 's'

joinPathSegments :: [Int] -> FilePath
joinPathSegments lengths = Text.unpack (Text.intercalate "/" (map (Text.pack . flip replicate 'p') lengths))

significantBlob :: Int -> ByteString
significantBlob size
  | size <= 0 = ByteString.empty
  | size == 1 = "x"
  | otherwise = "x\n" <> ByteString8.replicate (size - 2) 'x'

exactBlobBoundary :: [WireEntry]
exactBlobBoundary = sortedWithPb [wireEntry ObjectSha1 "large/blob.txt" "100644" (significantBlob maximumBlobBytes)]

exactAggregateBoundary, overAggregateBoundary :: [WireEntry]
exactAggregateBoundary =
  sortOn wirePath
    [ wireEntry ObjectSha1 "large/a.txt" "100644" (significantBlob maximumBlobBytes)
    , wireEntry ObjectSha1 "large/b.txt" "100644" (significantBlob (maximumBlobBytes - ByteString.length canonicalPbBytes))
    , pbEntry ObjectSha1
    ]
overAggregateBoundary =
  sortOn wirePath
    [ wireEntry ObjectSha1 "large/a.txt" "100644" (significantBlob maximumBlobBytes)
    , wireEntry ObjectSha1 "large/b.txt" "100644" (significantBlob (maximumBlobBytes - ByteString.length canonicalPbBytes + 1))
    , pbEntry ObjectSha1
    ]

exactSemanticBoundary :: [WireEntry]
exactSemanticBoundary =
  sortedWithPb [wireEntry ObjectSha1 "src/LongLine.hs" "100644" (ByteString8.replicate maximumSemanticBytes 'x')]

sortedWithPb :: [WireEntry] -> [WireEntry]
sortedWithPb entries = sortOn wirePath (pbEntry ObjectSha1 : entries)

grammarCases = identityGrammarCases <> pathGrammarCases <> modeObjectGrammarCases

identityGrammarCases :: [ExactCase]
identityGrammarCases =
  [ completeProblemCase
      "claimed identity width is exact"
      (Text.replicate 63 "0")
      [pbEntry ObjectSha1]
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-IDENTITY-GRAMMAR" "<claimed-snapshot>" ("expected exactly 64 lowercase ASCII hexadecimal characters; observed=" <> Text.replicate 63 "0")]
  , completeProblemCase
      "claimed identity alphabet is lowercase hexadecimal"
      (Text.replicate 63 "0" <> "g")
      [pbEntry ObjectSha1]
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-IDENTITY-GRAMMAR" "<claimed-snapshot>" ("expected exactly 64 lowercase ASCII hexadecimal characters; observed=" <> Text.replicate 63 "0" <> "g")]
  ]

pathGrammarCases :: [ExactCase]
pathGrammarCases = map pathProblemCase pathProblemRows

pathProblemRows :: [(String, FilePath, Text)]
pathProblemRows =
  [ ("empty path", "", "path is empty")
  , ("absolute path", "/src/A.hs", "path is absolute")
  , ("path alphabet", "src/A?.hs", "path contains a non-portable character")
  , ("empty path segment", "src//A.hs", "path contains an empty segment")
  , ("dot path segment", "src/./A.hs", "path contains a dot segment")
  , ("parent path segment", "src/../A.hs", "path contains a parent segment")
  , ("repository-control path segment", "src/.GiT/A.hs", "path contains a repository-control segment")
  , ("trailing-dot path segment", "src/A.", "path contains a trailing-dot segment")
  , ("reserved extension", "CON.txt", "path contains reserved segment CON.txt")
  , ("reserved case fold", "con", "path contains reserved segment con")
  , ("reserved core", "CON", "path contains reserved segment CON")
  , ("reserved core PRN", "PRN", "path contains reserved segment PRN")
  , ("reserved core AUX", "AUX", "path contains reserved segment AUX")
  , ("reserved core NUL", "NUL", "path contains reserved segment NUL")
  , ("reserved COM range", "COM1", "path contains reserved segment COM1")
  , ("reserved COM2", "COM2", "path contains reserved segment COM2")
  , ("reserved COM3", "COM3", "path contains reserved segment COM3")
  , ("reserved COM4", "COM4", "path contains reserved segment COM4")
  , ("reserved COM5", "COM5", "path contains reserved segment COM5")
  , ("reserved COM6", "COM6", "path contains reserved segment COM6")
  , ("reserved COM7", "COM7", "path contains reserved segment COM7")
  , ("reserved COM8", "COM8", "path contains reserved segment COM8")
  , ("reserved COM9", "COM9", "path contains reserved segment COM9")
  , ("reserved LPT range", "LPT1", "path contains reserved segment LPT1")
  , ("reserved LPT2", "LPT2", "path contains reserved segment LPT2")
  , ("reserved LPT3", "LPT3", "path contains reserved segment LPT3")
  , ("reserved LPT4", "LPT4", "path contains reserved segment LPT4")
  , ("reserved LPT5", "LPT5", "path contains reserved segment LPT5")
  , ("reserved LPT6", "LPT6", "path contains reserved segment LPT6")
  , ("reserved LPT7", "LPT7", "path contains reserved segment LPT7")
  , ("reserved LPT8", "LPT8", "path contains reserved segment LPT8")
  , ("reserved LPT9", "LPT9", "path contains reserved segment LPT9")
  ]

pathProblemCase :: (String, FilePath, Text) -> ExactCase
pathProblemCase (label, path, detail) =
  let entry = wireEntry ObjectSha1 path "100644" "x\n"
      subject = if null path then "<entry-1>" else path
   in completeProblemCase
        label
        zeroIdentity
        [entry]
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-PATH-GRAMMAR" subject detail]

modeObjectGrammarCases :: [ExactCase]
modeObjectGrammarCases =
  [ completeProblemCase
      "mode grammar is closed"
      zeroIdentity
      [((wireEntry ObjectSha1 "src/A.hs" "100644" "x\n") {wireMode = "100600"})]
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-MODE-GRAMMAR" "<entry-1>" "observed=100600"]
  , completeProblemCase
      "object identity width is closed"
      zeroIdentity
      [((wireEntry ObjectSha1 "src/A.hs" "100644" "x\n") {wireObject = Text.replicate 39 "0"})]
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-OBJECT-ID-GRAMMAR" "<entry-1>" ("observed=" <> Text.replicate 39 "0")]
  , completeProblemCase
      "object identity alphabet is lowercase hexadecimal"
      zeroIdentity
      [((wireEntry ObjectSha1 "src/A.hs" "100644" "x\n") {wireObject = Text.replicate 39 "0" <> "g"})]
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-OBJECT-ID-GRAMMAR" "<entry-1>" ("observed=" <> Text.replicate 39 "0" <> "g")]
  , objectMismatchCase ObjectSha1
  , objectMismatchCase ObjectSha256
  ]

objectMismatchCase :: ObjectFormat -> ExactCase
objectMismatchCase objectFormat =
  let bytes = "x\n"
      actual = gitBlobObject objectFormat bytes
      wrong = Text.replicate (Text.length actual) "0"
      entry = WireEntry "src/A.hs" "100644" wrong bytes
   in completeProblemCase
        ("blob object identity recomputes " <> show objectFormat)
        zeroIdentity
        [entry]
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-OBJECT-ID-MISMATCH" "<entry-1>" ("expected=" <> wrong <> "; recomputed=" <> actual)]

completeProblemCase
  :: String
  -> Text
  -> [WireEntry]
  -> Text
  -> Text
  -> [Finding]
  -> ExactCase
completeProblemCase label claimed entries computed problemCount findings =
  let commitment = completeCommitment claimed entries
      expected =
        expectedFailure
          ExpectedFailure
            { failureCommitmentKind = "complete-input"
            , failureCommitmentSha256 = commitment
            , failureClaimedObservation = claimed
            , failureEntryCount = decimal (length entries)
            , failureAggregateBytes = decimal (sum (map (ByteString.length . wireBytes) entries))
            , failureComputedSnapshot = computed
            , failureProblemCount = problemCount
            , failureFindingsWithoutCommitment = findings
            }
   in (label, expected, runFacade claimed entries)

inventoryCases =
  [ completeProblemCase
      "empty inventory refuses exactly"
      zeroIdentity
      []
      "unavailable"
      "1"
      [Finding "SOURCE-CLOSURE-INVENTORY-EMPTY" "<raw-source-closure>" "raw inventory must contain at least one tracked entry"]
  , duplicateCase
  , orderCase
  , caseCollisionCase
  , prefixConflictCase
  , mixedFormatCase
  ]

duplicateCase, orderCase, caseCollisionCase, prefixConflictCase, mixedFormatCase :: ExactCase
duplicateCase =
  let entry = wireEntry ObjectSha1 "src/A.hs" "100644" "x\n"
   in completeProblemCase
        "duplicate paths refuse exactly"
        zeroIdentity
        [entry, entry]
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-DUPLICATE-PATH" "src/A.hs" "path occurs more than once"]
orderCase =
  let entries =
        [ wireEntry ObjectSha1 "src/B.hs" "100644" "b\n"
        , wireEntry ObjectSha1 "src/A.hs" "100644" "a\n"
        ]
   in completeProblemCase
        "entry order is exact"
        zeroIdentity
        entries
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-ENTRY-ORDER" "<raw-source-closure>" ("observed-count=2; first-two=" <> Text.pack (show (map wirePath entries)))]
caseCollisionCase =
  let entries =
        [ wireEntry ObjectSha1 "src/A.hs" "100644" "a\n"
        , wireEntry ObjectSha1 "src/a.hs" "100644" "b\n"
        ]
   in completeProblemCase
        "portable case collision refuses exactly"
        zeroIdentity
        entries
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-PORTABLE-CASE-COLLISION" "src/A.hs" "collides with src/a.hs"]
prefixConflictCase =
  let entries =
        [ wireEntry ObjectSha1 "src/A" "100644" "a\n"
        , wireEntry ObjectSha1 "src/A-B" "100644" "b\n"
        , wireEntry ObjectSha1 "src/A/B.hs" "100644" "c\n"
        ]
   in completeProblemCase
        "portable prefix conflict survives an intervening sibling"
        zeroIdentity
        entries
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-PORTABLE-PREFIX-CONFLICT" "src/A" "conflicts with src/A/B.hs"]
mixedFormatCase =
  let entries =
        [wireEntry ObjectSha1 "src/A.hs" "100644" "a\n", wireEntry ObjectSha256 "src/B.hs" "100644" "b\n"]
   in completeProblemCase
        "mixed object formats refuse exactly"
        zeroIdentity
        entries
        "unavailable"
        "1"
        [Finding "SOURCE-CLOSURE-OBJECT-FORMAT-MIXED" "<raw-source-closure>" "[40,64]"]

classificationCases =
  [ successCase "closed primary-class and project identifier catalog" ObjectSha1 classificationCatalog
  , successCase "mode and structural facet catalog" ObjectSha1 facetCatalog
  , successCase "foreign signature identifier catalog" ObjectSha1 signatureCatalog
  ]

classificationCatalog :: [WireEntry]
classificationCatalog =
  sortOn wirePath
    ( pbEntry ObjectSha1
        : map
          (\(path, bytes) -> wireEntry ObjectSha1 path "100644" bytes)
          [ (".build/x.hs", "module X where\n")
          , (".data/x.hs", "module X where\n")
          , (".dockerignore", "dist-newstyle\n")
          , (".editorconfig", "root=true\n")
          , (".gitattributes", "* text\n")
          , (".gitignore", ".build\n")
          , (".test_data/x.hs", "module X where\n")
          , ("README.md", "# README\n")
          , ("amoebius.cabal", "name: amoebius\n")
          , ("app/App.hs", "module App where\n")
          , ("cabal.project", "packages: .\n")
          , ("config.dhall", "value\n")
          , ("config.proto", "value\n")
          , ("dhall/config.txt", "value\n")
          , ("documents/renamed_program.md", "# renamed\n")
          , ("package.json", "value\n")
          , ("probe/Probe.hs", "module Probe where\n")
          , ("probe/helper.py", "value\n")
          , ("probe/probe.cabal", "name: probe\n")
          , ("proto/schema.txt", "value\n")
          , ("pulumi/main.py", "value\n")
          , ("schema/item.proto", "value\n")
          , ("src/A1_@+,-.hs", "module A where\n")
          , ("src/azAZ09._@+,-.hs", "module Alphabet where\n")
          , ("test/Spec.hs", "module Spec where\n")
          , ("test/helper.py", "value\n")
          , ("tools/tool.py", "value\n")
          , ("ui/app.js", "value\n")
          , ("vendor/lib.c", "value\n")
          ]
    )

facetCatalog :: [WireEntry]
facetCatalog =
  sortOn wirePath
    [ wireEntry ObjectSha1 "README.md" "100644" "def disguised():\n"
    , wireEntry ObjectSha1 "app/Binary.hs" "100644" (ByteString.pack [97, 0, 10])
    , wireEntry ObjectSha1 "app/Executable.hs" "100755" "module Executable where\n"
    , wireEntry ObjectSha1 "app/Invalid.hs" "100644" (ByteString.pack [255, 10])
    , wireEntry ObjectSha1 "app/Link.hs" "120000" "target\n"
    , wireEntry ObjectSha1 "app/Shebang.hs" "100644" "#!/bin/sh\n"
    , pbEntry ObjectSha1
    ]

signatureCatalog :: [WireEntry]
signatureCatalog =
  sortOn wirePath
    ( pbEntry ObjectSha1
        : map
          (\(path, bytes) -> wireEntry ObjectSha1 path "100644" bytes)
          [ ("src/Const.hs", "const value = 1\n")
          , ("src/Def.hs", "def value():\n")
          , ("src/From.hs", "from value import item\n")
          , ("src/Function.hs", "function value() {}\n")
          , ("src/Json.hs", "{\"value\":1}\n")
          , ("src/Proto.hs", "syntax = proto3\n")
          , ("src/SetE.hs", "set -e\n")
          , ("src/ShebangSignature.hs", "#!/bin/sh\n")
          , ("src/Xml.hs", "<?xml version=\"1.0\"?>\n")
          ]
    )

problemAndResultBoundaryCases =
  [ problemBoundaryCase maximumProblems
  , problemBoundaryCase (maximumProblems + 1)
  , resultBoundaryCase 171
  , resultBoundaryCase 172
  , modeIdentifierCatalogCase
  ]

problemBoundaryCase :: Int -> ExactCase
problemBoundaryCase count
  | count <= maximumProblems =
      completeProblemCase
        "problem traversal exact maximum"
        zeroIdentity
        entries
        "unavailable"
        (decimal count)
        [ Finding
            "SOURCE-CLOSURE-MODE-GRAMMAR"
            ("<entry-" <> show ordinal <> ">")
            "observed=100600"
        | ordinal <- [1 .. count]
        ]
  | otherwise =
      completeProblemCase
        "problem traversal maximum plus one"
        zeroIdentity
        entries
        "unavailable"
        "129+"
        [ Finding
            "SOURCE-CLOSURE-PROBLEM-LIMIT"
            "<raw-source-closure>"
            (limitDetail maximumProblems (maximumProblems + 1))
        ]
 where
  entries =
    [ (wireEntry ObjectSha1 ("misc/p" <> pad5 ordinal <> ".txt") "100644" "x\n")
        { wireMode = "100600"
        }
    | ordinal <- [0 .. count - 1]
    ]

resultBoundaryCase :: Int -> ExactCase
resultBoundaryCase unregisteredCount =
  successCase
    ( if unregisteredCount == 171
        then "result findings exact maximum"
        else "result findings maximum plus one"
    )
    ObjectSha1
    entries
 where
  entries =
    sortOn wirePath
      ( pbEntry ObjectSha1
          : [ wireEntry ObjectSha1 ("misc/u" <> pad5 ordinal <> ".txt") "100644" "x\n"
            | ordinal <- [0 .. unregisteredCount - 1]
            ]
      )

modeIdentifierCatalogCase :: ExactCase
modeIdentifierCatalogCase =
  successCase
    "all three exact Git mode identifiers remain distinct"
    ObjectSha1
    ( sortOn wirePath
        [ pbEntry ObjectSha1
        , wireEntry ObjectSha1 "src/ExecutableMode.hs" "100755" "module ExecutableMode where\n"
        , wireEntry ObjectSha1 "src/RegularMode.hs" "100644" "module RegularMode where\n"
        , wireEntry ObjectSha1 "src/SymlinkMode.hs" "120000" "target\n"
        ]
    )

-- Filled by the independent literal declaration at the end of this module.
canonicalPbBytes :: ByteString
canonicalPbBytes =
  ByteString8.unlines
    [ "import hashlib"
    , "import os"
    , "import platform"
    , "import subprocess"
    , "import sys"
    , "import urllib.request"
    , "from pathlib import Path"
    , "GHCUP_VERSION = \"0.2.6.2\""
    , "GHC_VERSION = \"9.12.4\""
    , "CABAL_VERSION = \"3.16.1.0\""
    , "BUILD_TARGET = \"exe:amoebius\""
    , "def select_artifact(system, machine):"
    , "    if system == \"Linux\" and machine == \"x86_64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-linux-ghcup-0.2.6.2\", \"9ed5da5449b48043a0d17e767c05d2ef585e25a639bb934329496c6d2fad9cf8\", \"linux-amd64\", \"ghcup\", \"\")"
    , "    if system == \"Linux\" and machine == \"aarch64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2\", \"65a5f05120288ee4f1a81d28825374b6af317456a351a586adfce90c6dc29e3b\", \"linux-arm64\", \"ghcup\", \"\")"
    , "    if system == \"Darwin\" and machine == \"arm64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-apple-darwin-ghcup-0.2.6.2\", \"4e521e008fe0813db6db4b91cfeebd0c44c80c68afb458ea32a1c94cf5c7cc1d\", \"darwin-arm64\", \"ghcup\", \"\")"
    , "    if system == \"Windows\" and machine == \"AMD64\":"
    , "        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-mingw64-ghcup-0.2.6.2.exe\", \"94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db\", \"windows-amd64\", \"ghcup.exe\", \".exe\")"
    , "    raise RuntimeError(\"unsupported-platform\")"
    , "class BootstrapAdapter:"
    , "    def repository_root(self):"
    , "        return Path(__file__).resolve().parents[1]"
    , "    def platform(self):"
    , "        return (platform.system(), platform.machine())"
    , "    def ensure_ghcup(self, url, digest, target):"
    , "        if target.is_file():"
    , "            existing_payload = target.read_bytes()"
    , "            existing_hash_value = hashlib.sha256(existing_payload)"
    , "            existing_digest = existing_hash_value.hexdigest()"
    , "            if existing_digest == digest:"
    , "                return target"
    , "            raise RuntimeError(\"ghcup-existing-sha256\")"
    , "        target.parent.mkdir(parents=True, exist_ok=True)"
    , "        response = urllib.request.urlopen(url)"
    , "        payload = response.read()"
    , "        hash_value = hashlib.sha256(payload)"
    , "        observed = hash_value.hexdigest()"
    , "        if observed != digest:"
    , "            raise RuntimeError(\"ghcup-sha256\")"
    , "        target.write_bytes(payload)"
    , "        target.chmod(448)"
    , "        return target"
    , "    def environment(self, toolchain):"
    , "        home = toolchain / \"home\""
    , "        cache = toolchain / \"cache\""
    , "        temporary = toolchain / \"tmp\""
    , "        home.mkdir(parents=True, exist_ok=True)"
    , "        cache.mkdir(parents=True, exist_ok=True)"
    , "        temporary.mkdir(parents=True, exist_ok=True)"
    , "        environment = {}"
    , "        environment[\"GHCUP_INSTALL_BASE_PREFIX\"] = str(toolchain)"
    , "        environment[\"GHCUP_SKIP_UPDATE_CHECK\"] = \"yes\""
    , "        environment[\"HOME\"] = str(home)"
    , "        environment[\"XDG_CACHE_HOME\"] = str(cache)"
    , "        environment[\"TMPDIR\"] = str(temporary)"
    , "        environment[\"TEMP\"] = str(temporary)"
    , "        environment[\"TMP\"] = str(temporary)"
    , "        return environment"
    , "    def run(self, root, arguments, environment):"
    , "        subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False)"
    , "    def capture(self, root, arguments, environment):"
    , "        return subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False, stdout=subprocess.PIPE).stdout"
    , "    def handoff(self, binary, arguments):"
    , "        os.execv(binary, arguments)"
    , "def bootstrap(adapter, arguments):"
    , "    root = adapter.repository_root()"
    , "    observed_platform = adapter.platform()"
    , "    artifact = select_artifact(observed_platform[0], observed_platform[1])"
    , "    toolchain = root / \".build\" / \"toolchain\" / artifact[2]"
    , "    ghcup_target = toolchain / \"bootstrap\" / artifact[3]"
    , "    ghcup = adapter.ensure_ghcup(artifact[0], artifact[1], ghcup_target)"
    , "    environment = adapter.environment(toolchain)"
    , "    adapter.run(root, [str(ghcup), \"install\", \"ghc\", GHC_VERSION, \"--set\"], environment)"
    , "    adapter.run(root, [str(ghcup), \"install\", \"cabal\", CABAL_VERSION, \"--set\"], environment)"
    , "    ghc = toolchain / \".ghcup\" / \"ghc\" / GHC_VERSION / \"bin\" / (\"ghc\" + artifact[4])"
    , "    cabal = toolchain / \".ghcup\" / \"bin\" / (\"cabal\" + artifact[4])"
    , "    builddir = toolchain / \"dist-newstyle\""
    , "    store = toolchain / \"cabal-store\""
    , "    adapter.run(root, [str(cabal), \"--store-dir=\" + str(store), \"build\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
    , "    binary_bytes = adapter.capture(root, [str(cabal), \"--store-dir=\" + str(store), \"list-bin\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
    , "    binary_text = binary_bytes.decode(\"utf-8\")"
    , "    binary = binary_text.strip()"
    , "    adapter.handoff(binary, [binary] + arguments)"
    , "def main():"
    , "    adapter = BootstrapAdapter()"
    , "    bootstrap(adapter, sys.argv[1:])"
    , "if __name__ == \"__main__\":"
    , "    main()"
    ]

pbEntry :: ObjectFormat -> WireEntry
pbEntry objectFormat = wireEntry objectFormat "pb/__main__.py" "100644" canonicalPbBytes

wireEntry :: ObjectFormat -> FilePath -> Text -> ByteString -> WireEntry
wireEntry objectFormat path mode bytes =
  WireEntry path mode (gitBlobObject objectFormat bytes) bytes

-- Independent expected-wire algorithms and classification follow.
completeCommitment :: Text -> [WireEntry] -> Text
completeCommitment claimed entries = sha256Hex (ByteString.concat frames)
 where
  frames = "amoebius-source-closure-input-v1\0" : lengthText claimed : concatMap entryFrames entries
  entryFrames entry =
    [ lengthBytes (TextEncoding.encodeUtf8 (Text.pack (wirePath entry)))
    , lengthText (wireMode entry)
    , lengthText (wireObject entry)
    , lengthBytes (wireBytes entry)
    ]

expectedSnapshotIdentity :: ObjectFormat -> [WireEntry] -> Text
expectedSnapshotIdentity objectFormat entries = sha256Hex (ByteString.concat frames)
 where
  frames =
    ["amoebius-source-snapshot-v2\0", renderObjectFormatBytes objectFormat, "\0"]
      <> concatMap memberFrames (sortOn wirePath entries)
  memberFrames entry =
    [ TextEncoding.encodeUtf8 (wireMode entry)
    , "\0"
    , TextEncoding.encodeUtf8 (wireObject entry)
    , "\0"
    , TextEncoding.encodeUtf8 (sha256Hex (wireBytes entry))
    , "\0"
    , TextEncoding.encodeUtf8 (Text.pack (wirePath entry))
    , "\0"
    ]

expectedClassificationDigest :: [ExpectedPath] -> Text
expectedClassificationDigest paths = sha256Hex (ByteString.concat frames)
 where
  frames = "amoebius-source-closure-classification-v1\0" : concatMap pathFrames paths
  pathFrames item =
    map
      lengthText
      [ Text.pack (wirePath entry)
      , wireMode entry
      , wireObject entry
      , renderExpectedClass (expectedClass item)
      , Text.intercalate "," (map renderExpectedFacet (expectedFacets item))
      , Text.intercalate "; " (expectedReasons item)
      ]
   where
    entry = expectedEntry item

lengthText :: Text -> ByteString
lengthText = lengthBytes . TextEncoding.encodeUtf8

lengthBytes :: ByteString -> ByteString
lengthBytes bytes = ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

sha256Hex :: ByteString -> Text
sha256Hex = Text.pack . show . (Crypto.hash :: ByteString -> Crypto.Digest Crypto.SHA256)

gitBlobObject :: ObjectFormat -> ByteString -> Text
gitBlobObject objectFormat bytes = case objectFormat of
  ObjectSha1 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA1))
  ObjectSha256 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA256))
 where
  framed = "blob " <> ByteString8.pack (show (ByteString.length bytes)) <> "\0" <> bytes

renderObjectFormatBytes :: ObjectFormat -> ByteString
renderObjectFormatBytes ObjectSha1 = "sha1"
renderObjectFormatBytes ObjectSha256 = "sha256"

expectedClassify :: WireEntry -> ExpectedPath
expectedClassify entry = ExpectedPath entry finalClass facets reasons
 where
  initial = expectedPrimaryClass (wirePath entry)
  facets = expectedEntryFacets entry
  structural = expectedStructuralReasons initial facets
  signature = expectedSignatureReasons initial (wireBytes entry) facets
  reasons = expectedPrimaryReasons initial <> structural <> signature
  finalClass
    | expectedRegistered initial = initial
    | null structural && null signature = initial
    | otherwise = ExpectedUnregistered

expectedPrimaryClass :: FilePath -> ExpectedClass
expectedPrimaryClass path
  | any (`pathUnder` path) [".build", ".data", ".test_data"] = ExpectedUnregistered
  | pathUnder "vendor" path = ExpectedLegacy "LTD-SRC-009"
  | pathSuffix ".dhall" path || pathUnder "dhall" path = ExpectedLegacy "LTD-SRC-002"
  | pathSuffix ".proto" path || pathUnder "proto" path = ExpectedLegacy "LTD-SRC-003"
  | path == "package.json" || pathUnder "ui" path = ExpectedLegacy "LTD-SRC-004"
  | pathUnder "pulumi" path = ExpectedLegacy "LTD-SRC-005"
  | pathUnder "probe" path && not (pathSuffix ".hs" path || path == "probe/probe.cabal") = ExpectedLegacy "LTD-SRC-007"
  | pathUnder "test" path && not (pathSuffix ".hs" path) = ExpectedLegacy "LTD-SRC-006"
  | pathUnder "tools" path = ExpectedLegacy "LTD-SRC-001"
  | pathUnder "pb" path = ExpectedLegacy "LTD-SRC-008"
  | pathSuffix ".hs" path && any (`pathUnder` path) ["src", "app", "test", "probe"] = ExpectedHaskell
  | path `Set.member` expectedDocumentationPaths = ExpectedDocumentation
  | path `elem` expectedProjectPaths = ExpectedProject
  | otherwise = ExpectedUnregistered

expectedDocumentationPaths :: Set.Set FilePath
expectedDocumentationPaths = Set.fromList ["AGENTS.md", "CLAUDE.md", "README.md"]

expectedProjectPaths :: [FilePath]
expectedProjectPaths =
  [ "amoebius.cabal"
  , "cabal.project"
  , "probe/probe.cabal"
  , ".gitignore"
  , ".dockerignore"
  , ".gitattributes"
  , ".editorconfig"
  ]

pathUnder :: FilePath -> FilePath -> Bool
pathUnder root path = Text.pack (root <> "/") `Text.isPrefixOf` Text.pack path

pathSuffix :: FilePath -> FilePath -> Bool
pathSuffix suffix path = Text.pack suffix `Text.isSuffixOf` Text.pack path

expectedEntryFacets :: WireEntry -> [ExpectedFacet]
expectedEntryFacets entry = modeFacets <> shebangFacets <> contentFacets
 where
  bytes = wireBytes entry
  modeFacets = case wireMode entry of
    "100644" -> []
    "100755" -> [ExpectedExecutable]
    "120000" -> [ExpectedSymlink (decodeLenient bytes)]
    _ -> []
  shebangFacets = case expectedShebang bytes of
    Nothing -> []
    Just value -> [ExpectedShebang value]
  contentFacets
    | ByteString.elem 0 bytes = [ExpectedBinary]
    | otherwise = case expectedForeignSignature bytes of
        Nothing -> []
        Just value -> [ExpectedForeign value]

expectedStructuralReasons :: ExpectedClass -> [ExpectedFacet] -> [Text]
expectedStructuralReasons sourceClass facets
  | expectedRegistered sourceClass = []
  | otherwise =
      ["tracked executable mode is not an authored-source role" | ExpectedExecutable `elem` facets]
        <> ["tracked symbolic links are not admitted source" | any expectedSymlinkFacet facets]
        <> ["tracked binary bytes are not admitted source" | ExpectedBinary `elem` facets]
        <> ["a shebang may not disguise an authored source role" | any expectedShebangFacet facets]

expectedSignatureReasons :: ExpectedClass -> ByteString -> [ExpectedFacet] -> [Text]
expectedSignatureReasons sourceClass bytes facets
  | expectedRegistered sourceClass = []
  | sourceClass == ExpectedUnregistered = ["path has no admitted authored-source class"]
  | not (expectedTextual bytes) = ["authored text is not valid UTF-8"]
  | sourceClass == ExpectedHaskell && any expectedForeignFacet facets =
      [".hs bytes begin with a foreign-language source signature"]
  | sourceClass `elem` [ExpectedDocumentation, ExpectedProject] && any expectedForeignFacet facets =
      ["an admitted non-code input begins with a behavioral-source signature"]
  | otherwise = []

expectedPrimaryReasons :: ExpectedClass -> [Text]
expectedPrimaryReasons (ExpectedLegacy "LTD-SRC-008") =
  ["pb authorization requires the complete exact snapshot-level grammar"]
expectedPrimaryReasons ExpectedUnregistered = ["no closed-grammar class matched"]
expectedPrimaryReasons _ = []

expectedRegistered :: ExpectedClass -> Bool
expectedRegistered sourceClass = case sourceClass of
  ExpectedLegacy _ -> True
  _ -> False

expectedSymlinkFacet, expectedShebangFacet, expectedForeignFacet :: ExpectedFacet -> Bool
expectedSymlinkFacet facet = case facet of
  ExpectedSymlink _ -> True
  _ -> False
expectedShebangFacet facet = case facet of
  ExpectedShebang _ -> True
  _ -> False
expectedForeignFacet facet = case facet of
  ExpectedForeign _ -> True
  _ -> False

expectedShebang :: ByteString -> Maybe Text
expectedShebang bytes
  | "#!" `ByteString.isPrefixOf` bytes =
      Just (decodeLenient (ByteString.takeWhile (not . lineEnd) bytes))
  | otherwise = Nothing

lineEnd :: Word8 -> Bool
lineEnd byte = byte == 10 || byte == 13

expectedForeignSignature :: ByteString -> Maybe Text
expectedForeignSignature bytes = match signatures
 where
  line = Text.toLower (expectedFirstSignificantLine bytes)
  signatures =
    [ ("from ", "python-from")
    , ("def ", "python-def")
    , ("set -e", "shell-set-e")
    , ("#!/", "shebang")
    , ("function ", "javascript-function")
    , ("const ", "javascript-const")
    , ("{\"", "json-object")
    , ("<?xml", "xml-document")
    , ("syntax =", "proto-schema")
    ]
  match values = case values of
    [] -> Nothing
    (prefix, label) : rest
      | prefix `Text.isPrefixOf` line -> Just label
      | otherwise -> match rest

expectedFirstSignificantLine :: ByteString -> Text
expectedFirstSignificantLine bytes = firstNonempty lines'
 where
  bounded = ByteString.take maximumSemanticBytes bytes
  lines' = map Text.strip (Text.lines (decodeLenient bounded))
  firstNonempty values = case values of
    [] -> ""
    value : rest | Text.null value -> firstNonempty rest
    value : _ -> value

expectedTextual :: ByteString -> Bool
expectedTextual bytes =
  not (ByteString.elem 0 bytes)
    && case TextEncoding.decodeUtf8' bytes of
      Left _ -> False
      Right _ -> True

decodeLenient :: ByteString -> Text
decodeLenient = TextEncoding.decodeUtf8With TextError.lenientDecode

renderExpectedClass :: ExpectedClass -> Text
renderExpectedClass value = case value of
  ExpectedHaskell -> "haskell"
  ExpectedDocumentation -> "documentation"
  ExpectedProject -> "project-declaration"
  ExpectedLegacy identifier -> "registered:" <> identifier
  ExpectedUnregistered -> "unregistered"

renderExpectedFacet :: ExpectedFacet -> Text
renderExpectedFacet value = case value of
  ExpectedExecutable -> "executable"
  ExpectedShebang detail -> "shebang=" <> detail
  ExpectedSymlink detail -> "symlink=" <> detail
  ExpectedBinary -> "binary"
  ExpectedForeign detail -> "foreign-signature=" <> detail

expectedClassCounts :: [ExpectedPath] -> [Text]
expectedClassCounts paths =
  map
    (decimal . expectedCount)
    [ (== ExpectedHaskell)
    , (== ExpectedDocumentation)
    , (== ExpectedProject)
    , (== ExpectedLegacy "LTD-SRC-008")
    , expectedRegistered
    , (== ExpectedUnregistered)
    ]
 where
  expectedCount predicate = length [() | item <- paths, predicate (expectedClass item)]

expectedUnregisteredFindings :: RawCommitment -> [ExpectedPath] -> [Finding]
expectedUnregisteredFindings commitment paths =
  [ Finding
      "SRC-UNREGISTERED"
      (wirePath (expectedEntry item))
      (Text.intercalate "; " (expectedReasons item) <> commitmentDetail commitment)
  | item <- paths
  , expectedClass item == ExpectedUnregistered
  ]

expectedPbFindings :: RawCommitment -> [Finding]
expectedPbFindings commitment = map (appendFindingCommitment commitment) canonicalPbFindings

canonicalPbFindings :: [Finding]
canonicalPbFindings =
  Finding
    "PB-GRAMMAR-DIAGNOSTIC-ONLY"
    "Amoebius.Validation.PbBootstrapGrammar.pbBootstrapGrammarDiagnostic"
    "caller-supplied pb bytes are diagnostic input and cannot establish source custody or Phase-50 runtime truth"
    : [ Finding
          "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
          (Text.unpack residue)
          "static source grammar cannot establish this runtime property; Phase 50 must observe the pb child from the source-bound Haskell supervisor"
      | residue <- canonicalPbResidues
      ]

canonicalPbResidues :: [Text]
canonicalPbResidues =
  [ "AuthenticatedPythonInterpreterResidue"
  , "PythonIsolationFlagsOrderResidue"
  , "AbsolutePythonDirectorySubjectResidue"
  , "StdlibImportStartupResidue"
  , "StandardLibraryNativeTransitiveSemanticsResidue"
  , "AmbientInterpreterEnvironmentResidue"
  , "NetworkProxyEnvironmentResidue"
  , "ChildToolDefaultSearchPathResidue"
  , "NetworkTransportAndCertificateResidue"
  , "SymlinkAndToctouResidue"
  , "AtomicArtifactPublicationResidue"
  , "ExecutableModeObservationResidue"
  , "GhcupManagedToolRuntimeResidue"
  , "CabalListBinPathObservationResidue"
  , "SourceAndBinaryPathIdentityResidue"
  , "WindowsGhcupRuntimeResidue"
  , "FakeAdapterObservationResidue"
  , "ConcreteAdapterEffectObservationResidue"
  , "UnchangedArgumentTailResidue"
  , "ExecReplacementResidue"
  , "HandoffExitPropagationResidue"
  ]
