{-# LANGUAGE OverloadedStrings #-}

module CompilerSourceGraphOracle
  ( compilerSourceGraphSelectorNames
  , runCompilerSourceGraphOracle
  , runCompilerSourceGraphSelectorProductControlOracle
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
import Data.List (group, intercalate, sort)
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

runCompilerSourceGraphSelectorProductControlOracle :: String -> IO ()
runCompilerSourceGraphSelectorProductControlOracle selector =
  case selectorCases selector of
    [(_, claimedIdentity, entries, _)] -> do
      observed <- compilerSourceGraphDiagnostic claimedIdentity entries
      let productProblems
            | selector == "VALIDATION_COMPILER_GRAPH_RAW_CHECK_NAME_MAPPING_MUTANT" =
                [ "check-name selector disturbed the independent mandatory-refusal control"
                | checkFindings observed /= mandatoryFindings
                ]
            | otherwise =
                [ "selector disturbed the independent diagnostic-name control: "
                    <> show (checkName observed)
                | checkName observed /= "compiler-source-graph-diagnostic"
                ]
          problems = intentFailures <> opacityInventoryFailures <> productProblems
      unless (null problems) (failWith "product-control" problems)
    candidates ->
      failWith "product-control-unresolvable"
        [ "selector=" <> selector
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
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_BLOB_LIMIT_FINDING_CODE_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_BYTE_LIMIT_FINDING_CODE_MUTANT", "blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_LENGTH_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_SEPARATOR_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_TAG_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_EMPTY_FINDING_CODE_MUTANT", "empty Cabal inventory")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_LIMIT_FINDING_CODE_MUTANT", "Cabal entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_MODE_FINDING_CODE_MUTANT", "executable Cabal declaration")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_SUFFIX_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CHECK_NAME_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_LIMIT_FINDING_CODE_MUTANT", "entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_ORDER_FINDING_CODE_MUTANT", "noncanonical entry order")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_AGGREGATE_MAPPING_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_CABAL_COUNT_MAPPING_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_ENTRY_COUNT_MAPPING_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_HASKELL_COUNT_MAPPING_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_IDENTITY_MAPPING_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FAILURE_PROBLEM_RETENTION_DROP_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_EMPTY_FINDING_CODE_MUTANT", "empty Haskell inventory")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_LIMIT_FINDING_CODE_MUTANT", "Haskell subject maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_MODE_FINDING_CODE_MUTANT", "executable Haskell subject")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_SUFFIX_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BYTE_LIMIT_FINDING_CODE_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_DIGIT_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_LETTER_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MALFORMED_FINDING_CODE_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_FINDING_CODE_MUTANT", "claimed inventory identity mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MANDATORY_FINDING_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MIXED_FORMAT_FINDING_CODE_MUTANT", "mixed object formats")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_BYTE_LIMIT_FINDING_CODE_MUTANT", "mode byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_EXECUTABLE_ALTERNATIVE_MUTANT", "executable Haskell subject")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_MALFORMED_FINDING_CODE_MUTANT", "malformed mode")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_REGULAR_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_SYMLINK_ALTERNATIVE_MUTANT", "symbolic-link mode reaches identity comparison")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_DIGIT_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_IDENTITY_BYTE_LIMIT_FINDING_CODE_MUTANT", "object identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_LETTER_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MALFORMED_FINDING_CODE_MUTANT", "malformed object alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_FINDING_CODE_MUTANT", "object content mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_SHA1_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_SHA256_ALTERNATIVE_MUTANT", "object identity exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBSERVATION_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_ABSOLUTE_FINDING_CODE_MUTANT", "absolute path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_BACKSLASH_FINDING_CODE_MUTANT", "backslash path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_BYTE_LIMIT_FINDING_CODE_MUTANT", "path byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_CHARACTER_FINDING_CODE_MUTANT", "unsafe path character")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_DEPTH_LIMIT_FINDING_CODE_MUTANT", "path depth maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_DIGIT_ALTERNATIVE_MUTANT", "portable path digit reaches identity comparison")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_DOT_FINDING_CODE_MUTANT", "dot path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_DUPLICATE_FINDING_CODE_MUTANT", "duplicate path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_FINDING_CODE_MUTANT", "empty path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_SEGMENT_FINDING_CODE_MUTANT", "empty path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_LOWER_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_NUL_FINDING_CODE_MUTANT", "NUL path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_PARENT_FINDING_CODE_MUTANT", "parent path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_PUNCTUATION_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_SEGMENT_LIMIT_FINDING_CODE_MUTANT", "path segment byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_UPPER_ALTERNATIVE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_CASE_FINDING_CODE_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_FINDING_CODE_MUTANT", "path prefix conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_DETAIL_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_ORDER_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_RETENTION_DROP_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_SUBJECT_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_BLOB_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_DOMAIN_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_ENTRY_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_ENTRY_SEPARATOR_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_FIELD_SEPARATOR_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_LENGTH_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_MODE_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_OBJECT_IDENTITY_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_PATH_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA1_BLOB_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA256_BLOB_MAPPING_MUTANT", "object identity exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SOURCE_CUSTODY_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SOURCE_CUSTODY_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SOURCE_CUSTODY_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_DROP_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_NAME_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_VALUE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_CODE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_DETAIL_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_SUBJECT_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_ACCUMULATOR_PROJECTION_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_BLOB_LENGTH_PROJECTION_MUTANT", "aggregate blob byte exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_HASKELL_RESOURCE_ORDER_MUTANT", "aggregate resource precedes Haskell count resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_LIMIT_PROJECTION_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_OBSERVED_PROJECTION_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_PREDICATE_MUTANT", "aggregate blob byte exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_RECURSION_ROUTE_MUTANT", "aggregate blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_SATURATION_PROJECTION_MUTANT", "aggregate blob byte exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ALL_SAME_EMPTY_ALTERNATIVE_MUTANT", "empty inventory reaches the all-same alternative")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ALL_SAME_NONEMPTY_PREDICATE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_OBSERVED_PROJECTION_MUTANT", "entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_PREDICATE_MUTANT", "entry exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_WITHIN_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_WITHIN_RETENTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_GRAMMAR_ROUTE_DROP_MUTANT", "executable Cabal declaration")
  , ("VALIDATION_COMPILER_GRAPH_RAW_CABAL_RESOURCE_ROUTE_DROP_MUTANT", "Cabal entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DECIMAL_TEXT_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DEPTH_SEGMENT_RESOURCE_ORDER_MUTANT", "path depth resource precedes segment resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIGEST_CHUNK_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIGEST_CHUNK_RETENTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIGEST_INITIAL_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_PATH_PROJECTION_MUTANT", "duplicate path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_PORTABLE_GRAMMAR_ORDER_MUTANT", "duplicate grammar precedes portable-case grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_AGGREGATE_RESOURCE_ORDER_MUTANT", "entry resource precedes aggregate resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_BOUND_EXCEEDED_ROUTE_MUTANT", "entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_BOUND_WITHIN_ROUTE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_DUPLICATE_GRAMMAR_ORDER_MUTANT", "entry grammar precedes duplicate grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_SUBJECT_ORDINAL_PROJECTION_MUTANT", "empty path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXCEEDED_PROBLEM_ROUTE_DROP_MUTANT", "path byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_EXCEEDED_WITHIN_ROUTE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FIRST_JUST_NOTHING_ROUTE_DROP_MUTANT", "executable Cabal declaration")
  , ("VALIDATION_COMPILER_GRAPH_RAW_FIRST_JUST_VALUE_ROUTE_DROP_MUTANT", "unsafe path character")
  , ("VALIDATION_COMPILER_GRAPH_RAW_GROUP_HEAD_RETENTION_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_GROUP_KEY_PREDICATE_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_GROUP_RECURSION_ROUTE_MUTANT", "portable collision in a later key group")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_CABAL_RESOURCE_ORDER_MUTANT", "Haskell count resource precedes Cabal count resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BOUND_EXCEEDED_ROUTE_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BOUND_WITHIN_ROUTE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_GRAMMAR_ROUTE_DROP_MUTANT", "claimed inventory identity mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_EXPECTED_PROJECTION_MUTANT", "claimed inventory identity mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_OBSERVED_PROJECTION_MUTANT", "claimed inventory identity mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_INVENTORY_IDENTITY_GRAMMAR_ORDER_MUTANT", "inventory grammar precedes identity grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MIXED_INVENTORY_GRAMMAR_ORDER_MUTANT", "mixed-format grammar precedes inventory grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_OBJECT_GRAMMAR_ORDER_MUTANT", "mode grammar precedes object grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_MODE_OBJECT_RESOURCE_ORDER_MUTANT", "mode resource precedes object identity resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_BLOB_RESOURCE_ORDER_MUTANT", "object identity resource precedes blob resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_HASKELL_GRAMMAR_ORDER_MUTANT", "object grammar precedes Haskell-mode grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_EXPECTED_PROJECTION_MUTANT", "object content mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_OBSERVED_PROJECTION_MUTANT", "object content mismatch")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ORDER_MIXED_GRAMMAR_ORDER_MUTANT", "order grammar precedes mixed-format grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OR_ELSE_FIRST_ROUTE_DROP_MUTANT", "path byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_OR_ELSE_SECOND_ROUTE_DROP_MUTANT", "executable Haskell subject")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_BYTE_DEPTH_RESOURCE_ORDER_MUTANT", "path byte resource precedes path depth resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_MODE_GRAMMAR_ORDER_MUTANT", "path grammar precedes mode grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_FIRST_PROJECTION_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_PREFIX_GRAMMAR_ORDER_MUTANT", "portable-case grammar precedes prefix grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_SECOND_PROJECTION_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_FIRST_PROJECTION_MUTANT", "path prefix conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_ORDER_GRAMMAR_ORDER_MUTANT", "prefix grammar precedes order grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_SECOND_PROJECTION_MUTANT", "path prefix conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_FINDING_LIMIT_PROJECTION_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_FINDING_OBSERVED_PROJECTION_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_GRAMMAR_PRECEDENCE_MUTANT", "path byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SEGMENT_MODE_RESOURCE_ORDER_MUTANT", "path segment resource precedes mode resource")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_DOMAIN_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_FIELD_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_LENGTH_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA1_BLOB_CHUNK_ORDER_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA1_DIGEST_ROUTE_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA256_BLOB_CHUNK_ORDER_MUTANT", "object identity exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SHA256_DIGEST_ROUTE_MUTANT", "object identity exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SPLIT_HEAD_PROJECTION_MUTANT", "dot path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SPLIT_REST_PROJECTION_MUTANT", "parent path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SPLIT_SEPARATOR_PREDICATE_MUTANT", "empty path segment")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SPLIT_TERMINAL_PROJECTION_MUTANT", "path segment byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_AGGREGATE_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_CABAL_COUNT_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_ENTRY_COUNT_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_HASKELL_COUNT_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_IDENTITY_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_PROBLEM_ASSEMBLY_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TUPLE_BLOB_PROJECTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TUPLE_MODE_PROJECTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TUPLE_OBJECT_IDENTITY_PROJECTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_TUPLE_PATH_PROJECTION_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_ASCII_WIDTH_MUTANT", "malformed identity alphabet")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_BOUND_PREDICATE_MUTANT", "path byte exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_FOUR_BYTE_WIDTH_MUTANT", "four-byte UTF-8 exact path maximum")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_OBSERVED_PROJECTION_MUTANT", "identity byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_THREE_BYTE_WIDTH_MUTANT", "three-byte UTF-8 exact path maximum")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_TWO_BYTE_WIDTH_MUTANT", "two-byte UTF-8 exact path maximum")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BLOB_RESOURCE_PREDICATE_MUTANT", "blob byte exact maximum reaches grammar")
  , ("VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_RECURSION_ROUTE_MUTANT", "entry maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DIGEST_RENDER_MAPPING_MUTANT", "internally consistent raw inventory at identity and mode maxima remains refusal-only")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_GROUP_PREDICATE_MUTANT", "duplicate path")
  , ("VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_SELECTION_ORDER_MUTANT", "duplicate selection chooses the first sorted duplicate")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_GRAMMAR_TRAVERSAL_ORDER_MUTANT", "entry grammar traversal selects the first violation")
  , ("VALIDATION_COMPILER_GRAPH_RAW_ENTRY_RESOURCE_TRAVERSAL_ORDER_MUTANT", "entry resource traversal selects the first violation")
  , ("VALIDATION_COMPILER_GRAPH_RAW_HASKELL_CABAL_EMPTY_GRAMMAR_ORDER_MUTANT", "empty inventory reaches the all-same alternative")
  , ("VALIDATION_COMPILER_GRAPH_RAW_LIST_HEAD_VALUE_ROUTE_DROP_MUTANT", "blob byte maximum plus one")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PATH_SEGMENT_TRAVERSAL_ORDER_MUTANT", "path segment traversal selects the first violation")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_COLLISION_PREDICATE_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_COLLISION_SELECTION_ORDER_MUTANT", "portable selection chooses the first collision group")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_MEMBER_SELECTION_ORDER_MUTANT", "portable case collision")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_PREDICATE_MUTANT", "path prefix conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_PREFIX_SELECTION_ORDER_MUTANT", "prefix selection chooses the first conflict")
  , ("VALIDATION_COMPILER_GRAPH_RAW_UTF8_RECURSION_ROUTE_MUTANT", "identity byte maximum plus one")
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
  [ "expected 275 mutation-intent rows, observed " <> show (length mutationIntent)
  | length mutationIntent /= 275
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
      "portable path digit reaches identity comparison"
      sixtyFourZeros
      [("A1.hs", "100644", aSha1, aBytes), cabalEntry]
      ( rawFinding
          "IDENTITY-MISMATCH"
          "claimed-identity"
          "expected=1da2d4e73b6dcbfdf9bfa5a4b7972326a98d6e8ecce5d7129dcd22cf1b8b9b84; observed=0000000000000000000000000000000000000000000000000000000000000000"
      )
  , refused
      "symbolic-link mode reaches identity comparison"
      sixtyFourZeros
      [ aEntry
      , ("README.md", "120000", "1de565933b05f74c75ff9a6520af5f9f8a5a2f1d", "target")
      , cabalEntry
      ]
      ( rawFinding
          "IDENTITY-MISMATCH"
          "claimed-identity"
          "expected=ad8811583c7b1b73744d45564a90e21ea10a0fedbc2991a164e1a05717936b7f; observed=0000000000000000000000000000000000000000000000000000000000000000"
      )
  , refused
      "entry resource precedes aggregate resource"
      cleanIdentity
      entryAggregateResourceEntries
      (resource "BLOB-BYTE-LIMIT" "entry-1" 65536 65537)
  , refused
      "aggregate resource precedes Haskell count resource"
      cleanIdentity
      aggregateHaskellResourceEntries
      (resource "AGGREGATE-BLOB-BYTE-LIMIT" "inventory" 262144 262145)
  , refused
      "Haskell count resource precedes Cabal count resource"
      cleanIdentity
      haskellCabalResourceEntries
      (resource "HASKELL-SUBJECT-LIMIT" "inventory" 64 65)
  , refused
      "path byte resource precedes path depth resource"
      cleanIdentity
      pathByteDepthResourceEntries
      (resource "PATH-BYTE-LIMIT" "entry-1" 1024 1025)
  , refused
      "path depth resource precedes segment resource"
      cleanIdentity
      depthSegmentResourceEntries
      (resource "PATH-DEPTH-LIMIT" "entry-1" 64 65)
  , refused
      "path segment resource precedes mode resource"
      cleanIdentity
      segmentModeResourceEntries
      (resource "PATH-SEGMENT-BYTE-LIMIT" "entry-1" 255 256)
  , refused
      "mode resource precedes object identity resource"
      cleanIdentity
      modeObjectResourceEntries
      (resource "MODE-BYTE-LIMIT" "entry-2" 6 7)
  , refused
      "object identity resource precedes blob resource"
      cleanIdentity
      objectBlobResourceEntries
      (resource "OBJECT-IDENTITY-BYTE-LIMIT" "entry-1" 64 65)
  , refused
      "entry grammar precedes duplicate grammar"
      cleanIdentity
      [("A:bad.hs", "100644", aSha1, aBytes), ("A:bad.hs", "100644", aSha1, aBytes), cabalEntry]
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "duplicate grammar precedes portable-case grammar"
      cleanIdentity
      [aEntry, aEntry, ("a.hs", "100644", aSha1, aBytes), cabalEntry]
      (rawFinding "PATH-DUPLICATE" "inventory" "duplicate path=A.hs")
  , refused
      "portable-case grammar precedes prefix grammar"
      cleanIdentity
      [aEntry, ("A.hs/B", "100644", aSha1, aBytes), ("a.hs", "100644", aSha1, aBytes), cabalEntry]
      (rawFinding "PATH-PORTABLE-CASE-COLLISION" "inventory" "A.hs collides with a.hs")
  , refused
      "prefix grammar precedes order grammar"
      cleanIdentity
      [("A/B.hs", "100644", aSha1, aBytes), ("A", "100644", aSha1, aBytes), cabalEntry]
      (rawFinding "PATH-PREFIX-CONFLICT" "inventory" "A conflicts with A/B.hs")
  , refused
      "order grammar precedes mixed-format grammar"
      cleanIdentity
      [("amoebius.cabal", "100644", cabalSha256, cabalBytes), aEntry]
      (rawFinding "ENTRY-ORDER-INVALID" "inventory" "paths must be in strict canonical ascending order")
  , refused
      "mixed-format grammar precedes inventory grammar"
      cleanIdentity
      [("README.md", "100644", aSha1, aBytes), ("amoebius.cabal", "100644", cabalSha256, cabalBytes)]
      (rawFinding "OBJECT-FORMATS-MIXED" "inventory" "all Git object identities must use one storage format")
  , refused
      "inventory grammar precedes identity grammar"
      sixtyFourZeros
      [cabalEntry]
      (rawFinding "HASKELL-SUBJECT-INVENTORY-EMPTY" "inventory" "at least one exact .hs subject is required")
  , refused
      "path grammar precedes mode grammar"
      cleanIdentity
      [("A:bad.hs", "x", aSha1, aBytes), cabalEntry]
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "mode grammar precedes object grammar"
      cleanIdentity
      [aEntry, ("README.md", "100664", Text.replicate 39 "a" <> "g", aBytes), cabalEntry]
      (entryGrammar "MODE-MALFORMED" 2 "expected one of 100644, 100755, or 120000")
  , refused
      "object grammar precedes Haskell-mode grammar"
      cleanIdentity
      [("A.hs", "100755", Text.replicate 39 "a" <> "g", aBytes), cabalEntry]
      (entryGrammar "OBJECT-IDENTITY-MALFORMED" 1 "expected 40 or 64 lowercase hexadecimal characters")
  , refused
      "empty inventory reaches the all-same alternative"
      cleanIdentity
      []
      (rawFinding "HASKELL-SUBJECT-INVENTORY-EMPTY" "inventory" "at least one exact .hs subject is required")
  , refused
      "portable collision in a later key group"
      cleanIdentity
      [ aEntry
      , ("B.hs", "100644", aSha1, aBytes)
      , cabalEntry
      , ("b.hs", "100644", aSha1, aBytes)
      ]
      (rawFinding "PATH-PORTABLE-CASE-COLLISION" "inventory" "B.hs collides with b.hs")
  , refused
      "entry resource traversal selects the first violation"
      cleanIdentity
      entryResourceTraversalEntries
      (resource "MODE-BYTE-LIMIT" "entry-1" 6 7)
  , refused
      "path segment traversal selects the first violation"
      cleanIdentity
      pathSegmentTraversalEntries
      (resource "PATH-SEGMENT-BYTE-LIMIT" "entry-1" 255 258)
  , refused
      "entry grammar traversal selects the first violation"
      cleanIdentity
      entryGrammarTraversalEntries
      (entryGrammar "PATH-CHARACTER-UNSAFE" 1 "path contains a character outside the portable compiler-input alphabet")
  , refused
      "duplicate selection chooses the first sorted duplicate"
      cleanIdentity
      duplicateSelectionEntries
      (rawFinding "PATH-DUPLICATE" "inventory" "duplicate path=A.hs")
  , refused
      "portable selection chooses the first collision group"
      cleanIdentity
      portableSelectionEntries
      (rawFinding "PATH-PORTABLE-CASE-COLLISION" "inventory" "A.hs collides with a.hs")
  , refused
      "prefix selection chooses the first conflict"
      cleanIdentity
      prefixSelectionEntries
      (rawFinding "PATH-PREFIX-CONFLICT" "inventory" "A conflicts with A/X.hs")
  , refused
      "two-byte UTF-8 exact path maximum"
      cleanIdentity
      [(utf8BoundaryPath '\x07ff' 2, "100644", aSha1, aBytes), aEntry, cabalEntry]
      (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
  , refused
      "three-byte UTF-8 exact path maximum"
      cleanIdentity
      [(utf8BoundaryPath '\x0800' 3, "100644", aSha1, aBytes), aEntry, cabalEntry]
      (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
  , refused
      "four-byte UTF-8 exact path maximum"
      cleanIdentity
      [(utf8BoundaryPath '\x10000' 4, "100644", aSha1, aBytes), aEntry, cabalEntry]
      (entryGrammar "PATH-EMPTY-SEGMENT" 1 "path segments must be nonempty")
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

entryAggregateResourceEntries :: [RawTuple]
entryAggregateResourceEntries =
  [ ("A.hs", "100644", aSha1, ByteString.replicate 65537 97)
  , ("B.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("C.bin", "100644", aSha1, ByteString.replicate 65536 97)
  , ("amoebius.cabal", "100644", cabalSha1, ByteString.replicate 65536 97)
  ]

aggregateHaskellResourceEntries :: [RawTuple]
aggregateHaskellResourceEntries =
  [ ("H" <> pad3 ordinal <> ".hs", "100644", aSha1, ByteString.replicate 4033 97)
  | ordinal <- [0 .. 64]
  ] <> [cabalEntry]

haskellCabalResourceEntries :: [RawTuple]
haskellCabalResourceEntries =
  [ ("H" <> pad3 ordinal <> ".hs", "100644", aSha1, aBytes)
  | ordinal <- [0 .. 64]
  ]
    <> [ ("a" <> show ordinal <> ".cabal", "100644", cabalSha1, cabalBytes)
       | ordinal <- [0 :: Int .. 4]
       ]

pathByteDepthResourceEntries :: [RawTuple]
pathByteDepthResourceEntries =
  [ (intercalate "/" (replicate 65 (replicate 16 'a')), "100644", aSha1, aBytes)
  , aEntry
  , cabalEntry
  ]

depthSegmentResourceEntries :: [RawTuple]
depthSegmentResourceEntries =
  [ (intercalate "/" (replicate 256 'a' : replicate 64 "a"), "100644", aSha1, aBytes)
  , aEntry
  , cabalEntry
  ]

segmentModeResourceEntries :: [RawTuple]
segmentModeResourceEntries =
  [(replicate 256 'a', "100644x", aSha1, aBytes), aEntry, cabalEntry]

modeObjectResourceEntries :: [RawTuple]
modeObjectResourceEntries =
  [aEntry, ("README.md", "100644x", Text.replicate 65 "a", aBytes), cabalEntry]

objectBlobResourceEntries :: [RawTuple]
objectBlobResourceEntries =
  [ ("A.hs", "100644", Text.replicate 65 "a", ByteString.replicate 65537 97)
  , cabalEntry
  ]

entryResourceTraversalEntries :: [RawTuple]
entryResourceTraversalEntries =
  [ ("A.hs", "100644x", aSha1, aBytes)
  , ("B.hs", "100644", Text.replicate 65 "a", aBytes)
  , cabalEntry
  ]

pathSegmentTraversalEntries :: [RawTuple]
pathSegmentTraversalEntries =
  [ (replicate 254 'a' <> ['\x10000'] <> "/" <> replicate 256 'b', "100644", aSha1, aBytes)
  , aEntry
  , cabalEntry
  ]

entryGrammarTraversalEntries :: [RawTuple]
entryGrammarTraversalEntries =
  [ ("A:bad.hs", "100644", aSha1, aBytes)
  , ("B.hs", "100664", aSha1, aBytes)
  , cabalEntry
  ]

duplicateSelectionEntries :: [RawTuple]
duplicateSelectionEntries =
  [ aEntry
  , aEntry
  , ("B.hs", "100644", aSha1, aBytes)
  , ("B.hs", "100644", aSha1, aBytes)
  , cabalEntry
  ]

portableSelectionEntries :: [RawTuple]
portableSelectionEntries =
  [ aEntry
  , ("B.hs", "100644", aSha1, aBytes)
  , ("a.hs", "100644", aSha1, aBytes)
  , ("b.hs", "100644", aSha1, aBytes)
  , cabalEntry
  ]

prefixSelectionEntries :: [RawTuple]
prefixSelectionEntries =
  [ ("A", "100644", aSha1, aBytes)
  , ("A/X.hs", "100644", aSha1, aBytes)
  , ("B", "100644", aSha1, aBytes)
  , ("B/X.hs", "100644", aSha1, aBytes)
  , cabalEntry
  ]

utf8BoundaryPath :: Char -> Int -> FilePath
utf8BoundaryPath character encodedWidth =
  intercalate
    "/"
    ((character : replicate (255 - encodedWidth) 'a') : replicate 3 (replicate 255 'a'))
    <> "/"

pad3 :: Int -> String
pad3 value
  | value < 10 = "00" <> show value
  | value < 100 = "0" <> show value
  | otherwise = show value
