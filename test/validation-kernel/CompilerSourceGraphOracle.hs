{-# LANGUAGE OverloadedStrings #-}

module CompilerSourceGraphOracle
  ( compilerSourceGraphSelectorNames
  , runCompilerSourceGraphOracle
  , runCompilerSourceGraphSelectorOracle
  ) where

-- This oracle states primitive fixtures, object identities, inventory identity,
-- limits, ordered observations, and ordered findings independently. It imports
-- only the refusal-only facade and the common result vocabulary.

import Amoebius.Validation.CompilerSourceGraph
  ( compilerSourceGraphDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (group, sort)
import Data.Text (Text)
import Data.Text qualified as Text

type RawTuple = (FilePath, Text, Text, ByteString)

runCompilerSourceGraphOracle :: IO ()
runCompilerSourceGraphOracle = do
  caseFailures <- fmap concat (mapM runCase cases)
  let failures = intentFailures <> opacityInventoryFailures <> caseFailures
  unless (null failures) (fail (unlines ("CompilerSourceGraphOracle" : failures)))
  putStrLn
    "CompilerSourceGraphOracle: literal refusal diagnostics match; authenticated source/toolchain/elaboration/execution, semantic closure, qualification, and human promotion remain absent."

runCompilerSourceGraphSelectorOracle :: String -> IO ()
runCompilerSourceGraphSelectorOracle selector =
  case (selectorTargets selector, selectorCases selector) of
    ([target], [candidate]) -> do
      let controlFailures = intentFailures <> opacityInventoryFailures
      unless (null controlFailures) (failWith "unaffected-control" controlFailures)
      problems <- runCase candidate
      unless (null problems) (failWith ("assigned-locus:" <> target) problems)
    (targets, candidates) ->
      failWith "unresolvable-selector"
        [ "selector=" <> selector
        , "targets=" <> show targets
        , "exact-case-count=" <> show (length candidates)
        ]

failWith :: String -> [String] -> IO ()
failWith label problems =
  fail (unlines (("CompilerSourceGraphOracle " <> label <> ":") : map ("  " <>) problems))

runCase :: (String, Text, [RawTuple], CheckResult) -> IO [String]
runCase (label, claimedIdentity, entries, expected) = do
  observed <- compilerSourceGraphDiagnostic claimedIdentity entries
  pure
    [ label <> ": expected " <> show expected <> ", observed " <> show observed
    | observed /= expected
    ]

-- This executable registry states which exact full-result row must change for
-- every production selector.  Repository diagnostics separately reconcile
-- these names with the once-only source and Cabal inventories; the oracle does
-- not parse production source, Cabal, or Markdown to invent its expectations.
mutationIntent :: [(String, String)]
mutationIntent =
  [ ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_LIMIT_WIDEN_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_LIMIT_WIDEN_MUTANT", "blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_EMPTY_BYPASS_MUTANT", "empty Cabal inventory")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_LIMIT_WIDEN_MUTANT", "Cabal entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_MODE_BYPASS_MUTANT", "executable Cabal declaration")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DEPTH_LIMIT_WIDEN_MUTANT", "path depth maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_BYPASS_MUTANT", "duplicate path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_LIMIT_WIDEN_MUTANT", "entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_EMPTY_BYPASS_MUTANT", "empty Haskell inventory")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_LIMIT_WIDEN_MUTANT", "Haskell subject maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_MODE_BYPASS_MUTANT", "executable Haskell subject")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_HEX_WIDEN_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_LIMIT_WIDEN_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MATCH_BYPASS_MUTANT", "claimed inventory identity mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MIXED_FORMAT_BYPASS_MUTANT", "mixed object formats")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_GRAMMAR_WIDEN_MUTANT", "malformed mode")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_LIMIT_WIDEN_MUTANT", "mode byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_CONTENT_BYPASS_MUTANT", "object content mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_HEX_WIDEN_MUTANT", "malformed object alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_LIMIT_WIDEN_MUTANT", "object identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ORDER_BYPASS_MUTANT", "noncanonical entry order")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_ABSOLUTE_BYPASS_MUTANT", "absolute path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_BACKSLASH_BYPASS_MUTANT", "backslash path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_CHARACTER_BYPASS_MUTANT", "unsafe path character")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_DOT_BYPASS_MUTANT", "dot path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_BYPASS_MUTANT", "empty path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_SEGMENT_BYPASS_MUTANT", "empty path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_LIMIT_WIDEN_MUTANT", "path byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_NUL_BYPASS_MUTANT", "NUL path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_PARENT_BYPASS_MUTANT", "parent path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_CASE_BYPASS_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_BYPASS_MUTANT", "path prefix conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEGMENT_LIMIT_WIDEN_MUTANT", "path segment byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SOURCE_CUSTODY_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  ]

compilerSourceGraphSelectorNames :: [String]
compilerSourceGraphSelectorNames = map fst mutationIntent

selectorTargets :: String -> [String]
selectorTargets selector =
  [target | (candidate, target) <- mutationIntent, candidate == selector]

selectorCases :: String -> [(String, Text, [RawTuple], CheckResult)]
selectorCases selector =
  [ candidate
  | target <- selectorTargets selector
  , candidate@(label, _, _, _) <- cases
  , label == target
  ]

intentFailures :: [String]
intentFailures =
  [ "expected 41 mutation-intent rows, observed " <> show (length mutationIntent)
  | length mutationIntent /= 41
  ]
    <> ["duplicate mutation-intent selector " <> selector | selector <- duplicates (map fst mutationIntent)]
    <> [ "mutation-intent target must name exactly one case: " <> selector <> " -> " <> target
       | (selector, target) <- mutationIntent
       , length (filter (== target) caseLabels) /= 1
       ]
 where
  caseLabels = [label | (label, _, _, _) <- cases]

-- Each row is owned literally here and has one compile-negative client that
-- imports only that symbol from the public facade.  The constructor and type
-- share a spelling but remain distinct namespace attacks.
privateFacadeSymbolInventory :: [String]
privateFacadeSymbolInventory =
  [ "type AcquiredCompilerSourceGraph"
  , "pattern AcquiredCompilerSourceGraph"
  , "acquiredCompilerSnapshotIdentity"
  , "acquiredCompilerSourceCheck"
  , "analyzeAcquiredCompilerSourceGraph"
  , "rawCompilerSourceGraphDiagnostic"
  ]

packageHiddenModuleInventory :: [String]
packageHiddenModuleInventory =
  ["Amoebius.Validation.CompilerSourceGraph.Internal"]

opacityInventoryFailures :: [String]
opacityInventoryFailures =
  [ "expected 6 private facade symbol attacks, observed "
      <> show (length privateFacadeSymbolInventory)
  | length privateFacadeSymbolInventory /= 6
  ]
    <> [ "duplicate private facade symbol attack " <> symbol
       | symbol <- duplicates privateFacadeSymbolInventory
       ]
    <> [ "expected the one package-hidden implementation module, observed "
          <> show packageHiddenModuleInventory
       | packageHiddenModuleInventory
          /= ["Amoebius.Validation.CompilerSourceGraph.Internal"]
       ]

duplicates :: Ord value => [value] -> [value]
duplicates values =
  [ value
  | value : _ : _ <- group (sort values)
  ]

cases :: [(String, Text, [RawTuple], CheckResult)]
cases =
  [ consistentCase
  , refused
      "entry exact maximum reaches grammar"
      cleanIdentity
      entryMaximumEntries
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "identity byte maximum plus one"
      (Text.replicate 65 "a")
      cleanEntries
      (resource "IDENTITY-BYTE-LIMIT" "claimed-identity" 64 65)
  , refused
      "entry maximum plus one"
      cleanIdentity
      entryLimitEntries
      (resource "ENTRY-LIMIT" "inventory" 128 129)
  , refused
      "path byte exact maximum reaches grammar"
      cleanIdentity
      pathMaximumEntries
      (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
  , refused
      "path byte maximum plus one"
      cleanIdentity
      [(replicate 1022 'a' <> ".hs", "100644", aSha1, aBytes), cabalEntry]
      (resource "PATH-BYTE-LIMIT" "entry-1" 1024 1025)
  , refused
      "path depth exact maximum reaches grammar"
      cleanIdentity
      depthMaximumEntries
      (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
  , refused
      "path depth maximum plus one"
      cleanIdentity
      [(concat (replicate 64 "a/") <> "A.hs", "100644", aSha1, aBytes), cabalEntry]
      (resource "PATH-DEPTH-LIMIT" "entry-1" 64 65)
  , refused
      "path segment exact maximum reaches grammar"
      cleanIdentity
      segmentMaximumEntries
      (entryGrammar "MODE-MALFORMED" 1 "expected one of 100644, 100755, or 120000")
  , refused
      "path segment byte maximum plus one"
      cleanIdentity
      [(replicate 253 'a' <> ".hs", "100644", aSha1, aBytes), cabalEntry]
      (resource "PATH-SEGMENT-BYTE-LIMIT" "entry-1" 255 256)
  , refused
      "object identity exact maximum reaches grammar"
      cleanIdentity
      [aEntry, ("amoebius.cabal", "100644", cabalSha256, cabalBytes)]
      (rawFinding "OBJECT-FORMATS-MIXED" "inventory" "all Git object identities must use one storage format")
  , refused
      "mode byte maximum plus one"
      cleanIdentity
      [("A.hs", "100644x", aSha1, aBytes), cabalEntry]
      (resource "MODE-BYTE-LIMIT" "entry-1" 6 7)
  , refused
      "object identity byte maximum plus one"
      cleanIdentity
      [("A.hs", "100644", Text.replicate 65 "a", aBytes), cabalEntry]
      (resource "OBJECT-IDENTITY-BYTE-LIMIT" "entry-1" 64 65)
  , refused
      "blob byte exact maximum reaches grammar"
      cleanIdentity
      [("A:bad.hs", "100644", aSha1, ByteString.replicate 65536 97), cabalEntry]
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "blob byte maximum plus one"
      cleanIdentity
      [("A.hs", "100644", aSha1, ByteString.replicate 65537 97), cabalEntry]
      (resource "BLOB-BYTE-LIMIT" "entry-1" 65536 65537)
  , refused
      "aggregate blob byte exact maximum reaches grammar"
      cleanIdentity
      aggregateMaximumEntries
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "aggregate blob byte maximum plus one"
      cleanIdentity
      aggregateLimitEntries
      (resource "AGGREGATE-BLOB-BYTE-LIMIT" "inventory" 262144 262145)
  , refused
      "Haskell subject exact maximum reaches grammar"
      cleanIdentity
      haskellMaximumEntries
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "Haskell subject maximum plus one"
      cleanIdentity
      haskellLimitEntries
      (resource "HASKELL-SUBJECT-LIMIT" "inventory" 64 65)
  , refused
      "Cabal entry exact maximum reaches grammar"
      cleanIdentity
      cabalMaximumEntries
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "Cabal entry maximum plus one"
      cleanIdentity
      cabalLimitEntries
      (resource "CABAL-ENTRY-LIMIT" "inventory" 4 5)
  , refused "malformed identity alphabet" nonHexIdentity cleanEntries identityMalformed
  , refused "empty path" cleanIdentity [("", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-EMPTY" 1 "path must be nonempty")
  , refused "absolute path" cleanIdentity [("/A.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-ABSOLUTE" 1 "path must be relative")
  , refused "NUL path" cleanIdentity [("A\0.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-NUL" 1 "path must not contain NUL")
  , refused "backslash path" cleanIdentity [("A\\B.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-BACKSLASH" 1 "path must use POSIX separators")
  , refused "empty path segment" cleanIdentity [("A//B.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
  , refused "dot path segment" cleanIdentity [("./A.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-DOT-SEGMENT" 1 "dot segments are forbidden")
  , refused "parent path segment" cleanIdentity [("x/../A.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-PARENT-SEGMENT" 1 "parent segments are forbidden")
  , refused "unsafe path character" cleanIdentity [("A:bad.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused "non-ASCII decimal path character" cleanIdentity [("A\x0660.hs", "100644", aSha1, aBytes), cabalEntry] (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "duplicate path"
      cleanIdentity
      [aEntry, aEntry, cabalEntry]
      (rawFinding "PATH-DUPLICATE" "inventory" "duplicate path=A.hs")
  , refused
      "portable case collision"
      cleanIdentity
      [aEntry, ("a.hs", "100644", aSha1, aBytes), cabalEntry]
      (rawFinding "PATH-PORTABLE-CASE-COLLISION" "inventory" "A.hs collides with a.hs")
  , refused
      "path prefix conflict"
      cleanIdentity
      [("A", "100644", aSha1, aBytes), ("A/B.hs", "100644", aSha1, aBytes), cabalEntry]
      (rawFinding "PATH-PREFIX-CONFLICT" "inventory" "A conflicts with A/B.hs")
  , refused
      "noncanonical entry order"
      cleanIdentity
      [cabalEntry, aEntry]
      (rawFinding "ENTRY-ORDER-INVALID" "inventory" "paths must be in strict canonical ascending order")
  , refused
      "malformed mode"
      cleanIdentity
      [aEntry, ("README.md", "100664", aSha1, aBytes), cabalEntry]
      (entryGrammar "MODE-MALFORMED" 2 "expected one of 100644, 100755, or 120000")
  , refused
      "malformed object alphabet"
      cleanIdentity
      [("A.hs", "100644", Text.replicate 39 "a" <> "g", aBytes), cabalEntry]
      (entryGrammar "OBJECT-IDENTITY-MALFORMED" 1 "expected 40 or 64 lowercase hexadecimal characters")
  , refused
      "object content mismatch"
      cleanIdentity
      [("A.hs", "100644", fortyZeros, aBytes), cabalEntry]
      (entryGrammar "OBJECT-IDENTITY-MISMATCH" 1 ("expected=" <> aSha1 <> "; observed=" <> fortyZeros))
  , refused
      "mixed object formats"
      cleanIdentity
      [aEntry, ("amoebius.cabal", "100644", cabalSha256, cabalBytes)]
      (rawFinding "OBJECT-FORMATS-MIXED" "inventory" "all Git object identities must use one storage format")
  , refused
      "executable Haskell subject"
      cleanIdentity
      [("A.hs", "100755", aSha1, aBytes), cabalEntry]
      (entryGrammar "HASKELL-SUBJECT-MODE-REJECTED" 1 "tracked .hs compiler subjects must use mode 100644")
  , refused
      "executable Cabal declaration"
      cleanIdentity
      [aEntry, ("amoebius.cabal", "100755", cabalSha1, cabalBytes)]
      (entryGrammar "CABAL-ENTRY-MODE-REJECTED" 2 "tracked .cabal compiler declarations must use mode 100644")
  , refused
      "empty Haskell inventory"
      cleanIdentity
      [cabalEntry]
      (rawFinding "HASKELL-SUBJECT-INVENTORY-EMPTY" "inventory" "at least one exact .hs subject is required")
  , refused
      "empty Cabal inventory"
      cleanIdentity
      [aEntry]
      (rawFinding "CABAL-ENTRY-INVENTORY-EMPTY" "inventory" "at least one exact .cabal declaration is required")
  , refused
      "claimed inventory identity mismatch"
      sixtyFourZeros
      cleanEntries
      (rawFinding "IDENTITY-MISMATCH" "claimed-identity" ("expected=" <> cleanIdentity <> "; observed=" <> sixtyFourZeros))
  ]

consistentCase :: (String, Text, [RawTuple], CheckResult)
consistentCase =
  ( "internally consistent raw inventory at identity and mode maxima remains refusal-only"
  , cleanIdentity
  , cleanEntries
  , expectedResult "2" "21" cleanIdentity "1" "1" Nothing
  )

refused :: String -> Text -> [RawTuple] -> Finding -> (String, Text, [RawTuple], CheckResult)
refused label claimed entries problem =
  (label, claimed, entries, expectedResult "unavailable" "unavailable" "unavailable" "unavailable" "unavailable" (Just problem))

expectedResult
  :: Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Maybe Finding
  -> CheckResult
expectedResult entryCount aggregate identity haskellCount cabalCount problem =
  CheckResult
    { checkName = "compiler-source-graph-diagnostic"
    , checkObservations =
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
    , checkFindings = maybe [] pure problem <> mandatoryFindings
    }

mandatoryFindings :: [Finding]
mandatoryFindings =
  [ finding "COMPILER-GRAPH-DIAGNOSTIC-ONLY" "compiler-source-graph" "raw caller input can produce diagnostics only; it cannot mint compiler-source-graph evidence"
  , finding "COMPILER-GRAPH-SOURCE-CUSTODY-UNAVAILABLE" "compiler-source-graph" "the raw inventory has no authenticated immutable source-custody token"
  , finding "COMPILER-GRAPH-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE" "compiler-source-graph" "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is attached"
  , finding "COMPILER-GRAPH-ELABORATION-CUSTODY-UNAVAILABLE" "compiler-source-graph" "no authenticated elaborated multi-component configuration-run plan is attached"
  , finding "COMPILER-GRAPH-TOOLCHAIN-CUSTODY-UNAVAILABLE" "compiler-source-graph" "no authenticated compiler, libdir, package-database, dependency, or build-info identity is attached"
  , finding "COMPILER-GRAPH-EXECUTION-SUPERVISION-UNAVAILABLE" "compiler-source-graph" "the compiler was not invoked by a challenged source-bound Haskell supervisor with closed resource and filesystem custody"
  , finding "COMPILER-GRAPH-SEMANTIC-CLOSURE-UNAVAILABLE" "compiler-source-graph" "complete calls, control flow, effect, provenance, sink, and dynamic-loading facts are absent"
  , finding "COMPILER-GRAPH-ORACLE-QUALIFICATION-UNAVAILABLE" "compiler-source-graph" "the component diagnostic is not an independently qualified phase-gate observation"
  ]

resource :: Text -> FilePath -> Int -> Int -> Finding
resource suffix subject limit observed =
  rawFinding
    suffix
    subject
    ("limit=" <> Text.pack (show limit) <> "; observed-at-least=" <> Text.pack (show observed))

entryGrammar :: Text -> Int -> Text -> Finding
entryGrammar suffix ordinal = rawFinding suffix ("entry-" <> show ordinal)

rawFinding :: Text -> FilePath -> Text -> Finding
rawFinding suffix = finding ("COMPILER-GRAPH-RAW-" <> suffix)

identityMalformed :: Finding
identityMalformed =
  rawFinding
    "IDENTITY-MALFORMED"
    "claimed-identity"
    "expected exactly 64 lowercase hexadecimal characters"

aBytes, cabalBytes :: ByteString
aBytes = "module A where\n"
cabalBytes = "cabal\n"

aSha1, cabalSha1, cabalSha256, cleanIdentity :: Text
aSha1 = "d843c00b78275c5bbdfcde9920a811bb01038a2d"
cabalSha1 = "7e78804719a96edfb68084dff0d25472a32286fe"
cabalSha256 = "ec631aae7a13e755d9e886ff76a76b60b8c7f3f78bba9d9126925c58a242ce79"
cleanIdentity = "4d77bfa043d38d0dff0b1a27e0827712d4cb67823e7c1bb2c265a34982053b97"

fortyZeros, sixtyFourZeros, nonHexIdentity :: Text
fortyZeros = Text.replicate 40 "0"
sixtyFourZeros = Text.replicate 64 "0"
nonHexIdentity = Text.replicate 63 "a" <> "g"

aEntry, cabalEntry :: RawTuple
aEntry = ("A.hs", "100644", aSha1, aBytes)
cabalEntry = ("amoebius.cabal", "100644", cabalSha1, cabalBytes)

cleanEntries :: [RawTuple]
cleanEntries = [aEntry, cabalEntry]

entryLimitEntries :: [RawTuple]
entryLimitEntries =
  [ ("x" <> pad3 ordinal, "100644", aSha1, aBytes)
  | ordinal <- [0 .. 128]
  ]

entryMaximumEntries :: [RawTuple]
entryMaximumEntries =
  [("A:bad.hs", "100644", aSha1, aBytes), cabalEntry]
    <> [ ("x" <> pad3 ordinal, "100644", aSha1, aBytes)
       | ordinal <- [0 .. 125]
       ]

pathMaximumEntries :: [RawTuple]
pathMaximumEntries =
  [ (concat (replicate 4 (replicate 255 'a' <> "/")), "100644", aSha1, aBytes)
  , aEntry
  , cabalEntry
  ]

depthMaximumEntries :: [RawTuple]
depthMaximumEntries =
  [(concat (replicate 63 "a/"), "100644", aSha1, aBytes), aEntry, cabalEntry]

segmentMaximumEntries :: [RawTuple]
segmentMaximumEntries =
  [(replicate 255 'a', "x", aSha1, aBytes), aEntry, cabalEntry]

aggregateMaximumEntries :: [RawTuple]
aggregateMaximumEntries =
  [ ("A:bad.hs", "100644", aSha1, ByteString.replicate 65536 97)
  , ("B.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("C.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("amoebius.cabal", "100644", cabalSha1, ByteString.replicate 65536 97)
  ]

aggregateLimitEntries :: [RawTuple]
aggregateLimitEntries =
  [ ("A0.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("A1.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("A2.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("A3.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("A4.bin", "100644", aSha1, "x")
  ]

haskellLimitEntries :: [RawTuple]
haskellLimitEntries =
  [ ("H" <> pad3 ordinal <> ".hs", "100644", aSha1, aBytes)
  | ordinal <- [0 .. 64]
  ] <> [cabalEntry]

haskellMaximumEntries :: [RawTuple]
haskellMaximumEntries =
  [("A:bad.hs", "100644", aSha1, aBytes)]
    <> [ ("H" <> pad3 ordinal <> ".hs", "100644", aSha1, aBytes)
       | ordinal <- [1 .. 63]
       ]
    <> [cabalEntry]

cabalLimitEntries :: [RawTuple]
cabalLimitEntries =
  [aEntry]
    <> [ ("a" <> show ordinal <> ".cabal", "100644", cabalSha1, cabalBytes)
       | ordinal <- [0 :: Int .. 4]
       ]

cabalMaximumEntries :: [RawTuple]
cabalMaximumEntries =
  [("A:bad.cabal", "100644", cabalSha1, cabalBytes), aEntry]
    <> [ ("a" <> show ordinal <> ".cabal", "100644", cabalSha1, cabalBytes)
       | ordinal <- [1 :: Int .. 3]
       ]

pad3 :: Int -> String
pad3 value
  | value < 10 = "00" <> show value
  | value < 100 = "0" <> show value
  | otherwise = show value
