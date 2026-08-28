{-# LANGUAGE OverloadedStrings #-}

module PbBootstrapGrammarOracle
  ( pbBootstrapFixtureBytes
  , pbBootstrapGrammarSelectorNames
  , runPbBootstrapGrammarOracle
  , runPbBootstrapGrammarSelectedOracle
  , runPbBootstrapGrammarSelectorOracle
  ) where

-- The subject exposes one function and only an always-refusing CheckResult.
-- This oracle owns its wire bytes, digest, observations, resource limits,
-- problem texts, and Phase-50 residue declarations.  It never imports a
-- production parser, model, proof, projection, canonical literal, or success
-- branch, and it never executes pb.

import Amoebius.Validation.PbBootstrapGrammar
  ( pbBootstrapGrammarDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , checkPassed
  )
import Control.Monad (unless)
import Data.Bits
  ( complement
  , rotateR
  , shiftL
  , shiftR
  , xor
  , (.&.)
  , (.|.)
  )
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (find)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word32, Word64, Word8)
import Numeric (showHex)
import System.Environment (getArgs)

runPbBootstrapGrammarOracle :: IO ()
runPbBootstrapGrammarOracle =
  finishDiagnostics
    "PbBootstrapGrammarOracle"
    ( selectorRegistryIntegrityProblems
        <> fixtureIntegrityProblems
        <> canonicalProblems
        <> inventoryProblems
        <> identityProblems
        <> resourceProblems
        <> grammarProblems
        <> opacityControlProblems
    )

-- This registry is intentionally literal and oracle-owned.  It must never be
-- generated from production CPP, Cabal flags, or a mutation driver: otherwise
-- the same omission could disappear from both the subject and its reported
-- coverage.  Several independent changed subjects are assigned to the same
-- complete canonical result because that one exact result retains every
-- observation and Phase-50 residue row; the selector identity remains unique.
pbBootstrapGrammarSelectorIntents :: [(String, String, String)]
pbBootstrapGrammarSelectorIntents =
  [ ("VALIDATION_PB_GRAMMAR_ABSOLUTE_DIRECTORY_SUBJECT_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ADAPTER_COUNT_BYPASS_MUTANT", "the sole concrete adapter construction is counted exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ADAPTER_EFFECT_OMISSION_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_AMBIENT_INTERPRETER_ENV_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_ARGUMENTS_COUNT_REFUSAL_BYPASS_MUTANT", "argv proof counts the bootstrap argument exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT", "argv proof refuses an absent bootstrap definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_HANDOFF_REFUSAL_BYPASS_MUTANT", "argv proof requires the exact final handoff expression", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_MAIN_ABSENT_REFUSAL_BYPASS_MUTANT", "argv proof refuses an absent main definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_MAIN_BODY_REFUSAL_BYPASS_MUTANT", "argv slicing remains an independently located proof", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_SYS_ARGV_COUNT_REFUSAL_BYPASS_MUTANT", "argv proof counts sys.argv exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_AST_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "AST nodes", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ATOMIC_ARTIFACT_PUBLICATION_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_AUTHENTICATED_INTERPRETER_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT", "binary proof requires one binary-text assignment", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT", "binary proof refuses an absent bootstrap definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_DECODE_REFUSAL_BYPASS_MUTANT", "binary decoding is exact before handoff", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_LOCATOR_REFUSAL_BYPASS_MUTANT", "binary bytes require the contained list-bin locator", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_ORDER_REFUSAL_BYPASS_MUTANT", "binary build must precede the locator", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_PATH_REFUSAL_BYPASS_MUTANT", "binary path derives only from stripped locator output", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINDING_BYPASS_MUTANT", "duplicate bindings retain scope and name", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CABAL_LIST_BIN_PATH_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CALL_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "call markers", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CALL_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CHILD_CALL_OMISSION_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CHILD_TOOL_SEARCH_PATH_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONCRETE_ADAPTER_EFFECT_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT", "binary proof refuses an absent bootstrap definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_END_REFUSAL_BYPASS_MUTANT", "argv proof requires the exact final handoff expression", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_BOOTSTRAP_TERMINATION_REFUSAL_BYPASS_MUTANT", "control flow refuses bootstrap termination before handoff", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_ABSENT_REFUSAL_BYPASS_MUTANT", "control flow refuses an absent handoff method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_BODY_REFUSAL_BYPASS_MUTANT", "a returning handoff cannot stand in for an exec request", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_COUNT_REFUSAL_BYPASS_MUTANT", "argv proof requires the exact final handoff expression", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_HANDOFF_REACHABILITY_REFUSAL_BYPASS_MUTANT", "control flow refuses bootstrap termination before handoff", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_MAIN_ABSENT_REFUSAL_BYPASS_MUTANT", "argv proof refuses an absent main definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_MAIN_END_REFUSAL_BYPASS_MUTANT", "argv slicing remains an independently located proof", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_MODULE_SAFETY_REFUSAL_BYPASS_MUTANT", "injection proof counts the module main call exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_MODULE_TERMINATION_REFUSAL_BYPASS_MUTANT", "control flow refuses module termination before the guard", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_UNREACHABLE_NODE_REFUSAL_BYPASS_MUTANT", "control flow refuses bootstrap termination before handoff", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "control-flow markers", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DEPTH_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "syntax depth", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_BYPASS_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIGEST_BYPASS_MUTANT", changedIdentityCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIRECT_EFFECT_BYPASS_MUTANT", "direct effects outside the adapter remain explicit", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DYNAMIC_IMPORT_BYPASS_MUTANT", "dynamic import calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EFFECT_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "effect markers", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EFFECT_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_BODY_REFUSAL_BYPASS_MUTANT", "existing-artifact equality remains fail-closed", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "ensure proof refuses an absent adapter method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_BODY_REFUSAL_BYPASS_MUTANT", "ambient environment copying remains outside the closed mapping", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_CAPTURE_BODY_REFUSAL_BYPASS_MUTANT", "capture requires the exact closed subprocess call", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_CAPTURE_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "environment proof refuses an absent capture method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "environment proof refuses an absent environment method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_RUN_BODY_REFUSAL_BYPASS_MUTANT", "run requires the exact closed subprocess call", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_RUN_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "environment proof refuses an absent run method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXACT_BYTE_COUNT_BYPASS_MUTANT", shortIdentityCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXACT_INVENTORY_BYPASS_MUTANT", emptyInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_MODE_OBSERVATION_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXEC_REPLACEMENT_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_FAKE_ADAPTER_OBSERVATION_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_GHCUP_TOOL_RUNTIME_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_HANDOFF_EXIT_PROPAGATION_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_HANDOFF_MAY_RETURN_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_HOOK_BYPASS_MUTANT", "hook calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_IMPORT_BYPASS_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_IMPORT_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_BOOTSTRAP_DEFINITION_REFUSAL_BYPASS_MUTANT", "injection proof refuses an absent bootstrap definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_BOOTSTRAP_SIGNATURE_REFUSAL_BYPASS_MUTANT", "injection proof requires the exact bootstrap signature", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_CONSTRUCTION_SCOPE_REFUSAL_BYPASS_MUTANT", "injection proof confines construction to main", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_MAIN_BODY_REFUSAL_BYPASS_MUTANT", "argv slicing remains an independently located proof", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_MAIN_CALL_REFUSAL_BYPASS_MUTANT", "injection proof counts the module main call exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_MAIN_DEFINITION_REFUSAL_BYPASS_MUTANT", "injection proof refuses an absent main definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_MAIN_GUARD_REFUSAL_BYPASS_MUTANT", "the injection guard literal remains exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_MAIN_SIGNATURE_REFUSAL_BYPASS_MUTANT", "injection proof requires an empty main signature", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ISOLATION_FLAGS_ORDER_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_INDENT_INCREASE_REFUSAL_BYPASS_MUTANT", "indentation may increase by only one level", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_INDENT_MULTIPLE_REFUSAL_BYPASS_MUTANT", "indentation requires a multiple of four spaces", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_STRING_CONTROL_REFUSAL_BYPASS_MUTANT", "string literals refuse control characters", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_STRING_ESCAPE_REFUSAL_BYPASS_MUTANT", "string literals refuse escapes", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_UNSUPPORTED_CHARACTER_REFUSAL_BYPASS_MUTANT", "unsupported lexical syntax has exact location and detail", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LEXICAL_UNTERMINATED_STRING_REFUSAL_BYPASS_MUTANT", "string literals require termination", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_BLANK_LINE_REFUSAL_BYPASS_MUTANT", "blank physical lines are outside the grammar", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_BOM_REFUSAL_BYPASS_MUTANT", "UTF-8 BOM is rejected by exact line discipline", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_CR_REFUSAL_BYPASS_MUTANT", "CR is rejected by exact line discipline", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_FINAL_LF_REFUSAL_BYPASS_MUTANT", "the source requires one final LF", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_NUL_REFUSAL_BYPASS_MUTANT", "NUL is rejected by exact line discipline", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_TAB_REFUSAL_BYPASS_MUTANT", "tabs are rejected by exact line discipline", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LINE_TRAILING_BLANK_REFUSAL_BYPASS_MUTANT", "trailing blank lines are rejected", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_MODE_BYPASS_MUTANT", executableModeCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_MODE_LIMIT_WIDEN_MUTANT", modeLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_MONKEYPATCH_BYPASS_MUTANT", "indexed monkeypatch targets retain their scope and subject", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_NESTED_IMPORT_BYPASS_MUTANT", "nested imports cannot acquire module authority", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_NETWORK_PROXY_ENV_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_NETWORK_TRANSPORT_CERTIFICATE_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_ARGUMENT_KEYWORD_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_ARGUMENT_POSITIONAL_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_ADD_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_AND_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_EQUAL_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_NOT_EQUAL_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_BINARY_PATH_JOIN_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_DOTTED_NAME_EXTENSION_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_ATTRIBUTE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_CALL_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_DICTIONARY_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_FALSE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_INDEX_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_INTEGER_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_LIST_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_NAME_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_PARENTHESIZED_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_STRING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_EXPRESSION_TRUE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_LEADING_SLICE_MUTANT", "closed grammar admits a leading slice independently", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_PLAIN_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_INDEX_STARTED_SLICE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_LIST_EMPTY_MUTANT", "closed grammar admits an empty list independently", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_LIST_NONEMPTY_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_EMPTY_TUPLE_MUTANT", "closed grammar admits an empty tuple independently", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_GROUPED_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_PARENTHESIZED_TUPLE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_ASSIGNMENT_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_CLASS_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_EXPRESSION_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_FROM_IMPORT_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_FUNCTION_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_IF_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_IMPORT_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_RAISE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_ALTERNATIVE_STATEMENT_RETURN_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_EXPRESSION_REFUSAL_BYPASS_MUTANT", "parser refuses a missing expression", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_KEYWORD_NAME_REFUSAL_BYPASS_MUTANT", "parser requires the from-import keyword", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_NAME_REFUSAL_BYPASS_MUTANT", "parser refusal has exact token location", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_EXPECTED_TOKEN_REFUSAL_BYPASS_MUTANT", "parser requires exact structural tokens", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_INVALID_ASSIGNMENT_REFUSAL_BYPASS_MUTANT", "parser refuses invalid assignment targets", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_NONE_REFUSAL_BYPASS_MUTANT", "None remains outside the closed grammar", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_TOP_INDENT_REFUSAL_BYPASS_MUTANT", "parser refuses top-level indentation", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PARSE_UNSUPPORTED_STATEMENT_REFUSAL_BYPASS_MUTANT", "unsupported statements remain outside the grammar", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PATH_BYPASS_MUTANT", differentPathCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PATH_LIMIT_WIDEN_MUTANT", pathLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHYSICAL_LINE_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "physical lines", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PIN_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT", "pin proof requires one exact module string assignment", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PIN_BUILD_TARGET_REFUSAL_BYPASS_MUTANT", "build-target pin is exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PIN_CABAL_VERSION_REFUSAL_BYPASS_MUTANT", "Cabal pin is exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PIN_GHCUP_VERSION_REFUSAL_BYPASS_MUTANT", "ghcup pin is exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PIN_GHC_VERSION_REFUSAL_BYPASS_MUTANT", "toolchain pins are derived from the AST", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_ARTIFACT_SET_REFUSAL_BYPASS_MUTANT", "platform branch literals remain a closed exact set", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_BRANCH_COUNT_REFUSAL_BYPASS_MUTANT", "platform selector requires exactly four top-level branches", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_BRANCH_SHAPE_REFUSAL_BYPASS_MUTANT", "platform branches require pure literal tuple returns", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_CONDITION_REFUSAL_BYPASS_MUTANT", "platform branch conditions require exact equalities", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "platform proof refuses an absent adapter method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_OBSERVATION_BODY_REFUSAL_BYPASS_MUTANT", "platform observation body is exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_SELECTOR_ABSENT_REFUSAL_BYPASS_MUTANT", "platform proof refuses an absent pure selector", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_TERMINAL_REFUSAL_BYPASS_MUTANT", "platform selector ends in the exact refusal", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_LIMIT_WIDEN_MUTANT", problemFloodCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_MARKER_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "problem markers", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_REFLECTION_BYPASS_MUTANT", "reflection calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOLUTION_BYPASS_MUTANT", "unresolved adapter methods retain caller and syntax", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RUNTIME_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SIGNATURE_BYPASS_MUTANT", "changed public signatures fail the exact signature set", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SKIP_CANONICAL_BYTES_MUTANT", changedIdentityCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SOURCE_BINARY_PATH_IDENTITY_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SOURCE_BYTE_LIMIT_WIDEN_MUTANT", overByteIdentityCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_STATIC_CLAIM_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_STDLIB_STARTUP_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_STDLIB_TRANSITIVE_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SUBJECT_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SYMLINK_TOCTOU_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOKEN_LIMIT_WIDEN_MUTANT", resourceOverCaseLabel "lexical tokens", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_ARTIFACT_PROVENANCE_REFUSAL_BYPASS_MUTANT", "toolchain artifact is selected from the observed platform", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_ASSIGNMENT_COUNT_REFUSAL_BYPASS_MUTANT", "toolchain proof requires one root assignment", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_BOOTSTRAP_ABSENT_REFUSAL_BYPASS_MUTANT", "binary proof refuses an absent bootstrap definition", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_BUILDDIR_REFUSAL_BYPASS_MUTANT", "build directory provenance remains below the toolchain", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_CHILD_CALLS_REFUSAL_BYPASS_MUTANT", "toolchain child calls are structurally exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_ENVIRONMENT_PROVENANCE_REFUSAL_BYPASS_MUTANT", "toolchain environment comes only from the adapter", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_EXECUTABLE_PATHS_REFUSAL_BYPASS_MUTANT", "toolchain executable paths are exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_GHCUP_RESULT_REFUSAL_BYPASS_MUTANT", "toolchain ghcup executable is the ensure result", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_GHCUP_TARGET_REFUSAL_BYPASS_MUTANT", "toolchain ghcup target is contained", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_PLATFORM_PROVENANCE_REFUSAL_BYPASS_MUTANT", "unresolved adapter methods retain caller and syntax", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_REPOSITORY_METHOD_ABSENT_REFUSAL_BYPASS_MUTANT", "toolchain proof refuses an absent repository-root method", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_REPOSITORY_SHAPE_REFUSAL_BYPASS_MUTANT", "toolchain repository root shape is exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_ROOT_PATH_REFUSAL_BYPASS_MUTANT", "toolchain root path is closed below the repository", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_ROOT_PROVENANCE_REFUSAL_BYPASS_MUTANT", "direct effects outside the adapter remain explicit", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_TOOLCHAIN_STORE_REFUSAL_BYPASS_MUTANT", "Cabal store provenance remains below the toolchain", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_UNCHANGED_ARGUMENT_TAIL_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_UTF8_BYPASS_MUTANT", "invalid UTF-8 has one exact private problem", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_WEAK_HANDOFF_PROVENANCE_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_WIDEN_INVENTORY_MUTANT", twoFileInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_WINDOWS_GHCUP_RUNTIME_RESIDUE_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  -- Atomic observation projections supplement the older compound retention
  -- challenges above; each changed subject is assigned to the complete
  -- canonical result that independently freezes the complete proof projection.
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_SOURCE_BYTES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_PHYSICAL_LINES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_AST_NODES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_LEXICAL_TOKENS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_SYNTAX_DEPTH_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_CALL_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_EFFECT_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_CONTROL_FLOW_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_PROBLEM_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_SOURCE_BYTES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_PATH_CHARACTERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_MODE_CHARACTERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_PHYSICAL_LINES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_AST_NODES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_LEXICAL_TOKENS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_SYNTAX_DEPTH_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_CALL_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_EFFECT_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_CONTROL_FLOW_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_PROBLEM_MARKERS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_PATH_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_MODE_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_BYTES_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_SHA256_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_EXPECTED_SHA256_OBSERVATION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  -- Preflight result rows are assigned to one exact semantic refusal that
  -- retains the complete independently authored preflight projection.
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_FILE_COUNT_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_LIMIT_INPUT_FILES_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_PATH_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_MODE_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_BYTES_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_EXPECTED_SHA256_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_PATH_CHARACTERS_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_MODE_CHARACTERS_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_BYTES_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_PATH_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_MODE_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_INPUT_SHA256_OBSERVATION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  -- Each structured proof member has its own production retention locus.
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_HASHLIB_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_OS_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_PLATFORM_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_SUBPROCESS_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_SYS_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_URLLIB_REQUEST_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_PATHLIB_PATH_MEMBER_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LINUX_AMD64_LABEL_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LINUX_ARM64_LABEL_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_DARWIN_ARM64_LABEL_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_WINDOWS_AMD64_LABEL_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_ARGV_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_BINARY_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_INJECTION_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_PHASE50_INVOCATION_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_ENSURE_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_ENVIRONMENT_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_EXECUTABLES_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_PLATFORM_LIMITATIONS_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_RUNTIME_BOUNDARY_CLAIM_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_SELECT_ARTIFACT_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_REPOSITORY_ROOT_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_PLATFORM_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENSURE_GHCUP_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENVIRONMENT_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_RUN_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_CAPTURE_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_HANDOFF_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_BOOTSTRAP_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_MAIN_ENTRY_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  -- Finding projection is independently addressable for every private problem
  -- constructor, plus the shared subject and detail mappings.
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_INVALID_UTF8_CODE_MAPPING_MUTANT", "invalid UTF-8 has one exact private problem", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_LINE_DISCIPLINE_CODE_MAPPING_MUTANT", "CR is rejected by exact line discipline", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_LEXICAL_CODE_MAPPING_MUTANT", "unsupported lexical syntax has exact location and detail", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_PARSE_CODE_MAPPING_MUTANT", "parser refusal has exact token location", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_UNSUPPORTED_IMPORT_CODE_MAPPING_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_NESTED_IMPORT_CODE_MAPPING_MUTANT", "nested imports cannot acquire module authority", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_BINDING_CONFLICT_CODE_MAPPING_MUTANT", "duplicate bindings retain scope and name", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_MONKEYPATCH_CODE_MAPPING_MUTANT", "indexed monkeypatch targets retain their scope and subject", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_DYNAMIC_IMPORT_CODE_MAPPING_MUTANT", "dynamic import calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_REFLECTION_CODE_MAPPING_MUTANT", "reflection calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_HOOK_CODE_MAPPING_MUTANT", "hook calls remain a distinct problem class", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_UNRESOLVED_CALL_CODE_MAPPING_MUTANT", "unresolved adapter methods retain caller and syntax", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_DIRECT_EFFECT_CODE_MAPPING_MUTANT", "direct effects outside the adapter remain explicit", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_ADAPTER_COUNT_CODE_MAPPING_MUTANT", "the sole concrete adapter construction is counted exactly", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_SIGNATURE_CODE_MAPPING_MUTANT", "changed public signatures fail the exact signature set", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_PIN_CODE_MAPPING_MUTANT", "toolchain pins are derived from the AST", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_ARGV_CODE_MAPPING_MUTANT", "argv slicing remains an independently located proof", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_INJECTION_CODE_MAPPING_MUTANT", "the injection guard literal remains exact", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_CONTROL_FLOW_CODE_MAPPING_MUTANT", "a returning handoff cannot stand in for an exec request", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_BINARY_CODE_MAPPING_MUTANT", "binary decoding is exact before handoff", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_GHCUP_ENSURE_CODE_MAPPING_MUTANT", "existing-artifact equality remains fail-closed", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_ENVIRONMENT_CODE_MAPPING_MUTANT", "ambient environment copying remains outside the closed mapping", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_TOOLCHAIN_CODE_MAPPING_MUTANT", "build directory provenance remains below the toolchain", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_PLATFORM_CODE_MAPPING_MUTANT", "platform branch literals remain a closed exact set", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_LIMIT_CODE_MAPPING_MUTANT", problemFloodCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_SUBJECT_MAPPING_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_DETAIL_MAPPING_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  -- Result assembly and all remaining shared finding projections are
  -- individually changed at their production loci.
  , ("VALIDATION_PB_GRAMMAR_CHECK_NAME_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_OBSERVATIONS_RETENTION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_FINDINGS_ORDER_MUTANT", emptyInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_SUCCESS_FINDINGS_ORDER_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_OBSERVATION_ORDER_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_IDENTITY_FINDINGS_RETENTION_DROP_MUTANT", changedIdentityCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_FINDINGS_RETENTION_DROP_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROBLEM_FINDINGS_ORDER_MUTANT", "unsupported import cannot widen the closed import universe", diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_CODE_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_SUBJECT_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_DIAGNOSTIC_ONLY_DETAIL_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_CODE_MAPPING_MUTANT", emptyInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_SUBJECT_MAPPING_MUTANT", emptyInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_FINDING_DETAIL_MAPPING_MUTANT", emptyInventoryCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_CODE_MAPPING_MUTANT", pathLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_NAME_MAPPING_MUTANT", pathLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_LIMIT_MAPPING_MUTANT", pathLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_FINDING_OBSERVED_MAPPING_MUTANT", pathLimitCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FINDINGS_RETENTION_DROP_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FINDINGS_ORDER_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FINDING_CODE_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FINDING_SUBJECT_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FINDING_DETAIL_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  -- Ordered structured projections and their closed wire-field renderers are
  -- changed independently of member retention.
  , ("VALIDATION_PB_GRAMMAR_PREFLIGHT_OBSERVATION_ORDER_MUTANT", "unsupported import cannot widen the closed import universe", emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RESOURCE_OBSERVATION_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_SUBJECT_OBSERVATION_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_MEMBER_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_CONTROL_FLOW_ENTRY_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LABEL_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_CLAIM_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_RUNTIME_RESIDUE_ORDER_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_IMPORT_MEMBER_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_PLATFORM_LABEL_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_STATIC_CLAIM_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PROOF_RUNTIME_RESIDUE_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_ROW_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_FIELD_SEPARATOR_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_NAME_FIELD_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_NODES_FIELD_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_EDGES_FIELD_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_HANDOFFS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CONTROL_FLOW_FALLTHROUGH_FIELD_MAPPING_MUTANT", canonicalCaseLabel, emptyInventoryFindingsControlLabel)
  -- Every wire field in the nine structured static claims is now changed at
  -- one production locus and observed by the complete canonical result.
  , ("VALIDATION_PB_GRAMMAR_ARGV_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_SOURCE_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_PARAMETER_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ARGV_EXECUTABLE_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_TARGET_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_GHCUP_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_COMPILER_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_CABAL_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_LOCATOR_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_BINARY_HANDOFF_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_FUNCTION_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_ADAPTER_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_ARGUMENTS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_CONSTRUCTION_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_INJECTION_GUARD_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_INTERPRETER_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FLAGS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_FLAGS_SEPARATOR_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_SUBJECT_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PHASE50_ARGUMENTS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_MATCHING_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_MISMATCHED_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENSURE_ABSENT_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_STARTS_EMPTY_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_EXACT_KEYS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_CONTAINED_KEYS_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_ENVIRONMENT_CHILD_MAPPING_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_ROOT_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_GHCUP_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_GHC_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_CABAL_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_EXECUTABLE_ARGV_ZERO_FIELD_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATIONS_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATION_ORDER_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_PLATFORM_LIMITATION_SEPARATOR_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_WINDOWS_PLATFORM_LIMITATION_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_OTHER_PLATFORM_LIMITATION_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RUNTIME_BOUNDARY_CLAIM_TAG_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_RUNTIME_BOUNDARY_MAPPING_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  , ("VALIDATION_PB_GRAMMAR_CLAIM_FIELD_SEPARATOR_MUTANT", canonicalCaseLabel, diagnosticNameControlLabel)
  ]

pbBootstrapGrammarSelectorNames :: [String]
pbBootstrapGrammarSelectorNames =
  [selector | (selector, _, _) <- pbBootstrapGrammarSelectorIntents]

runPbBootstrapGrammarSelectorOracle :: String -> IO ()
runPbBootstrapGrammarSelectorOracle selector =
  finishDiagnostics
    "PbBootstrapGrammarOracle selector"
    ( selectorRegistryIntegrityProblems
        <> selectorIndependentControlProblems
        <> case [target | (candidate, target, _) <- pbBootstrapGrammarSelectorIntents, candidate == selector] of
          [target] -> selectorTargetProblems target
          targets ->
            [ "selector intent is not exactly resolvable: selector="
                <> selector
                <> "; exact-target-count="
                <> show (length targets)
            ]
    )

runPbBootstrapGrammarSelectorControlOracle :: String -> IO ()
runPbBootstrapGrammarSelectorControlOracle selector =
  finishDiagnostics
    "PbBootstrapGrammarOracle selector control"
    ( selectorRegistryIntegrityProblems
        <> selectorIndependentControlProblems
        <> case [control | (candidate, _, control) <- pbBootstrapGrammarSelectorIntents, candidate == selector] of
          [target] -> selectorProductControlProblems target
          targets ->
            [ "selector product control is not exactly resolvable: selector="
                <> selector
                <> "; exact-control-count="
                <> show (length targets)
            ]
    )

runPbBootstrapGrammarSelectedOracle :: IO ()
runPbBootstrapGrammarSelectedOracle = do
  arguments <- getArgs
  case arguments of
    [selector] -> runPbBootstrapGrammarSelectorOracle selector
    ["--control", selector] -> runPbBootstrapGrammarSelectorControlOracle selector
    _ -> fail "PbBootstrapGrammarOracle selector runner requires SELECTOR or --control SELECTOR"

selectorRegistryIntegrityProblems :: [String]
selectorRegistryIntegrityProblems =
    [ "selector registry cardinality changed: expected=374; observed="
      <> show (length pbBootstrapGrammarSelectorIntents)
  | length pbBootstrapGrammarSelectorIntents /= 374
  ]
    <> ["duplicate selector identity: " <> value | value <- duplicates pbBootstrapGrammarSelectorNames]
    <> ["unknown exact-case target: " <> target | (_, target, _) <- pbBootstrapGrammarSelectorIntents, target `notElem` selectorExactCaseLabels]
    <> [ "unknown selector product-control target: " <> control
       | (_, _, control) <- pbBootstrapGrammarSelectorIntents
       , control `notElem` [diagnosticNameControlLabel, emptyInventoryFindingsControlLabel]
       ]

selectorIndependentControlProblems :: [String]
selectorIndependentControlProblems =
  concat
    [ expectEqual "selector control keeps oracle-local fixture size" 4770 (ByteString.length canonicalBytes)
    , expectEqual "selector control keeps oracle-local fixture SHA-256" expectedSha256 (sha256Hex canonicalBytes)
    , expectEqual "selector control keeps SHA-256 abc vector" "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" (sha256Hex "abc")
    ]

diagnosticNameControlLabel, emptyInventoryFindingsControlLabel :: String
diagnosticNameControlLabel = "diagnostic check name remains exact"
emptyInventoryFindingsControlLabel = "empty-inventory finding projection remains exact"

selectorProductControlProblems :: String -> [String]
selectorProductControlProblems target
  | target == diagnosticNameControlLabel =
      expectEqual
        target
        diagnosticName
        (checkName (pbBootstrapGrammarDiagnostic []))
  | target == emptyInventoryFindingsControlLabel =
      expectEqual
        target
        [ diagnosticOnlyFinding
        , preflightFinding
            "PB-GRAMMAR-INVENTORY-EXACT"
            "expected exactly one tracked pb file; observed 0"
        ]
        (checkFindings (pbBootstrapGrammarDiagnostic []))
  | otherwise = ["unknown selector product-control target at execution: " <> target]

duplicates :: Ord value => [value] -> [value]
duplicates = Set.toAscList . snd . foldl remember (Set.empty, Set.empty)
 where
  remember (seen, repeated) value
    | value `Set.member` seen = (seen, Set.insert value repeated)
    | otherwise = (Set.insert value seen, repeated)

canonicalCaseLabel, emptyInventoryCaseLabel, twoFileInventoryCaseLabel :: String
canonicalCaseLabel = "canonical source remains a fully retained refusal"
emptyInventoryCaseLabel = "empty inventory is an exact refusal before source traversal"
twoFileInventoryCaseLabel = "one file over the one-file bound refuses before complete traversal"

differentPathCaseLabel, executableModeCaseLabel, pathLimitCaseLabel, modeLimitCaseLabel :: String
differentPathCaseLabel = "the exact file under a different path cannot obtain the exception"
executableModeCaseLabel = "the exact file in executable mode cannot obtain the exception"
pathLimitCaseLabel = "one character over the path bound refuses before path rendering"
modeLimitCaseLabel = "one character over the six-character mode bound refuses before mode rendering"

shortIdentityCaseLabel, overByteIdentityCaseLabel, changedIdentityCaseLabel, problemFloodCaseLabel :: String
shortIdentityCaseLabel = "one byte under the exact byte count refuses before semantic parsing"
overByteIdentityCaseLabel = "one byte over the byte resource bound and exact size both remain visible"
changedIdentityCaseLabel = "a same-size changed byte is bound independently by digest and exact bytes"
problemFloodCaseLabel = "65 independent semantic problems collapse to the bounded traversal refusal"

resourceOverCaseLabel :: String -> String
resourceOverCaseLabel label = label <> " maximum-plus-one refuses in preflight"

selectorExactCaseLabels :: [String]
selectorExactCaseLabels =
  [ canonicalCaseLabel
  , emptyInventoryCaseLabel
  , twoFileInventoryCaseLabel
  , differentPathCaseLabel
  , executableModeCaseLabel
  , pathLimitCaseLabel
  , modeLimitCaseLabel
  , shortIdentityCaseLabel
  , overByteIdentityCaseLabel
  , changedIdentityCaseLabel
  , problemFloodCaseLabel
  ]
    <> map grammarLabel grammarCases
    <> map (resourceOverCaseLabel . boundaryLabel) resourceBoundaryFixtures

selectorTargetProblems :: String -> [String]
selectorTargetProblems target
  | target == canonicalCaseLabel = canonicalProblems
  | target == emptyInventoryCaseLabel =
      expectExact
        target
        (hardExpected []
          [preflightFinding "PB-GRAMMAR-INVENTORY-EXACT"
            "expected exactly one tracked pb file; observed 0"])
        (pbBootstrapGrammarDiagnostic [])
  | target == twoFileInventoryCaseLabel =
      expectExact
        target
        (hardExpected twoFileInventory
          [preflightFinding "PB-GRAMMAR-RESOURCE-LIMIT"
            "input-files exceeds the 1-entry bound; observed at least 2"])
        (pbBootstrapGrammarDiagnostic twoFileInventory)
  | target == differentPathCaseLabel =
      expectExact
        target
        (hardExpected [("pb/main.py", canonicalMode, canonicalBytes)]
          [preflightFinding "PB-GRAMMAR-PATH-EXACT"
            "expected pb/__main__.py; observed \"pb/main.py\""])
        (pbBootstrapGrammarDiagnostic [("pb/main.py", canonicalMode, canonicalBytes)])
  | target == executableModeCaseLabel =
      expectExact
        target
        (hardExpected [(canonicalPath, "100755", canonicalBytes)]
          [preflightFinding "PB-GRAMMAR-MODE-EXACT"
            "expected Git mode 100644; observed \"100755\""])
        (pbBootstrapGrammarDiagnostic [(canonicalPath, "100755", canonicalBytes)])
  | target == pathLimitCaseLabel =
      let pathOver = replicate 1025 'p'
       in expectExact
            target
            (hardExpected [(pathOver, canonicalMode, canonicalBytes)]
              [resourceFinding "path-characters" 1024 1025])
            (pbBootstrapGrammarDiagnostic [(pathOver, canonicalMode, canonicalBytes)])
  | target == modeLimitCaseLabel =
      expectExact
        target
        (hardExpected [(canonicalPath, "1006440", canonicalBytes)]
          [resourceFinding "mode-characters" 6 7])
        (pbBootstrapGrammarDiagnostic [(canonicalPath, "1006440", canonicalBytes)])
  | target == shortIdentityCaseLabel =
      expectExact
        target
        (hardExpected [(canonicalPath, canonicalMode, shortBytes)]
          [preflightFinding "PB-GRAMMAR-BYTE-COUNT-EXACT"
            "expected exactly 4770 bytes; observed 4769"])
        (runDiagnostic shortBytes)
  | target == overByteIdentityCaseLabel =
      expectExact
        target
        (hardExpected [(canonicalPath, canonicalMode, overByteBytes)]
          [ preflightFinding "PB-GRAMMAR-RESOURCE-LIMIT"
              "source-bytes exceeds the 4770 bound; observed 4771"
          , preflightFinding "PB-GRAMMAR-BYTE-COUNT-EXACT"
              "expected exactly 4770 bytes; observed 4771"
          ])
        (runDiagnostic overByteBytes)
  | target == changedIdentityCaseLabel =
      expectExact
        target
        (semanticExpected changedButLexicalBytes
          [problemFinding "PB-GRAMMAR-LEXICAL"
            "PbLexicalProblem \"pb/__main__.py\" 1 1 \"unsupported character #\""])
        (runDiagnostic changedButLexicalBytes)
  | target == problemFloodCaseLabel =
      expectExact
        target
        (semanticExpected problemFloodBytes
          [problemFinding "PB-GRAMMAR-PROBLEM-LIMIT"
            "PbProblemLimitExceeded 64 65"])
        (runDiagnostic problemFloodBytes)
  | Just grammarCase <- find ((== target) . grammarLabel) grammarCases =
      checkGrammarCase grammarCase
  | Just boundary <- find ((== target) . resourceOverCaseLabel . boundaryLabel) resourceBoundaryFixtures =
      expectExact
        target
        (hardExpected
          [(canonicalPath, canonicalMode, boundaryOverBytes boundary)]
          (boundaryOverFindings boundary))
        (runDiagnostic (boundaryOverBytes boundary))
  | otherwise = ["unknown exact-case target at execution: " <> target]

fixtureIntegrityProblems :: [String]
fixtureIntegrityProblems =
  concat
    [ expectEqual "local fixture byte count" 4770 (ByteString.length canonicalBytes)
    , expectEqual "local fixture SHA-256" expectedSha256 (sha256Hex canonicalBytes)
    , expectEqual
        "local fixture resource metrics"
        canonicalMetrics
        (measure canonicalBytes)
    , expectEqual
        "local SHA-256 empty vector"
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        (sha256Hex ByteString.empty)
    , expectEqual
        "local SHA-256 abc vector"
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        (sha256Hex "abc")
    , concatMap verifyBoundaryFixture resourceBoundaryFixtures
    , concatMap verifyGrammarFixture grammarCases
    , expectEqual
        "problem-boundary fixtures remain exact-size and independently literal"
        ((4770, 46, 64), (4770, 47, 65))
        ( ( ByteString.length problemBoundaryBytes
          , unsupportedImportCount problemBoundaryBytes
          , modeledMinimalProgramProblemCount problemBoundaryBytes
          )
        , ( ByteString.length problemFloodBytes
          , unsupportedImportCount problemFloodBytes
          , modeledMinimalProgramProblemCount problemFloodBytes
          )
        )
    ]

canonicalProblems :: [String]
canonicalProblems =
  expectExact
    "canonical source remains a fully retained refusal"
    canonicalExpectedResult
    (runDiagnostic canonicalBytes)

inventoryProblems :: [String]
inventoryProblems =
  concat
    [ expectExact
        "empty inventory is an exact refusal before source traversal"
        (hardExpected []
          [preflightFinding "PB-GRAMMAR-INVENTORY-EXACT"
            "expected exactly one tracked pb file; observed 0"])
        (pbBootstrapGrammarDiagnostic [])
    , expectExact
        "one file over the one-file bound refuses before complete traversal"
        (hardExpected twoFileInventory
          [preflightFinding "PB-GRAMMAR-RESOURCE-LIMIT"
            "input-files exceeds the 1-entry bound; observed at least 2"])
        (pbBootstrapGrammarDiagnostic twoFileInventory)
    , expectExact
        "the exact file under a different path cannot obtain the exception"
        (hardExpected [("pb/main.py", "100644", canonicalBytes)]
          [preflightFinding "PB-GRAMMAR-PATH-EXACT"
            "expected pb/__main__.py; observed \"pb/main.py\""])
        (pbBootstrapGrammarDiagnostic [("pb/main.py", "100644", canonicalBytes)])
    , expectExact
        "the exact file in executable mode cannot obtain the exception"
        (hardExpected [(canonicalPath, "100755", canonicalBytes)]
          [preflightFinding "PB-GRAMMAR-MODE-EXACT"
            "expected Git mode 100644; observed \"100755\""])
        (pbBootstrapGrammarDiagnostic [(canonicalPath, "100755", canonicalBytes)])
    , expectExact
        "the exact 1024-character path reaches the exact-path predicate"
        (hardExpected [(pathBoundary, canonicalMode, canonicalBytes)]
          [preflightFinding "PB-GRAMMAR-PATH-EXACT"
            ("expected pb/__main__.py; observed " <> Text.pack (show pathBoundary))])
        (pbBootstrapGrammarDiagnostic [(pathBoundary, canonicalMode, canonicalBytes)])
    , expectExact
        "one character over the path bound refuses before path rendering"
        (hardExpected [(pathOver, canonicalMode, canonicalBytes)]
          [resourceFinding "path-characters" 1024 1025])
        (pbBootstrapGrammarDiagnostic [(pathOver, canonicalMode, canonicalBytes)])
    , expectExact
        "one character over the six-character mode bound refuses before mode rendering"
        (hardExpected [(canonicalPath, "1006440", canonicalBytes)]
          [resourceFinding "mode-characters" 6 7])
        (pbBootstrapGrammarDiagnostic [(canonicalPath, "1006440", canonicalBytes)])
    ]
 where
  pathBoundary = replicate 1024 'p'
  pathOver = replicate 1025 'p'

identityProblems :: [String]
identityProblems =
  concat
    [ expectExact
        "one byte under the exact byte count refuses before semantic parsing"
        (hardExpected [(canonicalPath, canonicalMode, shortBytes)]
          [preflightFinding "PB-GRAMMAR-BYTE-COUNT-EXACT"
            "expected exactly 4770 bytes; observed 4769"])
        (runDiagnostic shortBytes)
    , expectExact
        "one byte over the byte resource bound and exact size both remain visible"
        (hardExpected [(canonicalPath, canonicalMode, overByteBytes)]
          [ preflightFinding "PB-GRAMMAR-RESOURCE-LIMIT"
              "source-bytes exceeds the 4770 bound; observed 4771"
          , preflightFinding "PB-GRAMMAR-BYTE-COUNT-EXACT"
              "expected exactly 4770 bytes; observed 4771"
          ])
        (runDiagnostic overByteBytes)
    , expectExact
        "a same-size changed byte is bound independently by digest and exact bytes"
          (semanticExpected changedButLexicalBytes
          [ problemFinding "PB-GRAMMAR-LEXICAL"
              "PbLexicalProblem \"pb/__main__.py\" 1 1 \"unsupported character #\""
          ])
        (runDiagnostic changedButLexicalBytes)
    ]

resourceProblems :: [String]
resourceProblems =
  concatMap checkResourceBoundary resourceBoundaryFixtures
    <> expectExact
      "64 independent semantic problems reach the exact traversal maximum"
      (semanticExpected problemBoundaryBytes
        ( [ problemFinding
              "PB-GRAMMAR-IMPORT"
              ("PbUnsupportedImport \"x" <> decimal index <> "\"")
          | index <- [0 .. 45]
          ]
            <> missingProgramProblems [] False
        ))
      (runDiagnostic problemBoundaryBytes)
    <> expectExact
      "65 independent semantic problems collapse to the bounded traversal refusal"
      (semanticExpected problemFloodBytes
        [problemFinding "PB-GRAMMAR-PROBLEM-LIMIT"
          "PbProblemLimitExceeded 64 65"])
      (runDiagnostic problemFloodBytes)

grammarProblems :: [String]
grammarProblems =
  concatMap checkGrammarCase grammarCases

opacityControlProblems :: [String]
opacityControlProblems =
  concat
    [ expectEqual
        "the public control returns the declared check name"
        "pb-bootstrap-grammar-diagnostic"
        (checkName (runDiagnostic canonicalBytes))
    , expectEqual
        "the public control can never become green"
        False
        (checkPassed (runDiagnostic canonicalBytes))
    ]

data GrammarCase = GrammarCase
  { grammarLabel :: String
  , grammarBytes :: ByteString
  , grammarProblemsExact :: [Finding]
  }

checkGrammarCase :: GrammarCase -> [String]
checkGrammarCase item =
  expectExact
    (grammarLabel item)
    (semanticExpected (grammarBytes item) (grammarProblemsExact item))
    (runDiagnostic (grammarBytes item))

grammarCases :: [GrammarCase]
grammarCases =
  [ grammar "invalid UTF-8 has one exact private problem"
      (replaceFirstByte 255 canonicalBytes)
      "PB-GRAMMAR-UTF8"
      "PbInvalidUtf8 \"pb/__main__.py\""
  , grammar "CR is rejected by exact line discipline"
      (replaceFirstByte 13 canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"CR and CRLF are forbidden\""
  , grammar "unsupported lexical syntax has exact location and detail"
      changedButLexicalBytes
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 1 1 \"unsupported character #\""
  , grammar "parser refusal has exact token location"
      (replaceSame "import hashlib" "import(hashlib" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 1 7 \"expected name\""
  , GrammarCase
      "closed grammar admits a leading slice independently"
      (replaceLine "    bootstrap(adapter, sys.argv[1:])" "    bootstrap(adapter, sys.argv[:])" canonicalBytes)
      [ problemFinding
          "PB-GRAMMAR-ARGV"
          "PbArgvProvenanceProblem \"main must pass sys.argv[1:] unchanged to the injected bootstrap seam\""
      , problemFinding
          "PB-GRAMMAR-INJECTION"
          "PbInjectionSeamProblem \"main alone must construct BootstrapAdapter and call bootstrap(adapter, sys.argv[1:])\""
      , problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"main must end with exact bootstrap(adapter, sys.argv[1:])\""
      ]
  , grammar
      "closed grammar admits an empty tuple independently"
      (replaceLine "GHCUP_VERSION = \"0.2.6.2\"" "GHCUP_VERSION = ()" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"GHCUP_VERSION exact string assignment count is 0\""
  , GrammarCase
      "closed grammar admits an empty list independently"
      (replaceLine "    adapter.handoff(binary, [binary] + arguments)" "    adapter.handoff(binary, [] + arguments)" canonicalBytes)
      [ problemFinding
          "PB-GRAMMAR-ARGV"
          "PbArgvProvenanceProblem \"bootstrap must hand off [binary] + arguments exactly\""
      , problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"bootstrap must end with exact adapter.handoff(binary, [binary] + arguments)\""
      , problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"bootstrap must contain exactly one handoff request and it must be the final reachable statement\""
      , problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"bootstrap handoff request is absent, duplicated, or unreachable\""
      ]
  , grammarWithAdditional "unsupported import cannot widen the closed import universe"
      (replaceSame "import os" "import xx" canonicalBytes)
      "PB-GRAMMAR-IMPORT"
      "PbUnsupportedImport \"xx\""
      [ problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:os\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"BootstrapAdapter.handoff\" \"os.execv\""
      ]
  , grammarWithAdditional "nested imports cannot acquire module authority"
      (replaceLine "    root = adapter.repository_root()" "    import os" canonicalBytes)
      "PB-GRAMMAR-NESTED-IMPORT"
      "PbNestedImport \"bootstrap\" \"os\""
      [ problemFinding "PB-GRAMMAR-BINDING-CONFLICT" "PbBindingConflict \"bootstrap\" \"os\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"root assignment count is 0\""
      ]
  , grammarWithAdditional "duplicate bindings retain scope and name"
      (replaceLine "    observed_platform = adapter.platform()" "    root = adapter.repository_root()" canonicalBytes)
      "PB-GRAMMAR-BINDING-CONFLICT"
      "PbBindingConflict \"bootstrap\" \"root\""
      [problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"root assignment count is 2\""]
  , grammarWithAdditional "indexed monkeypatch targets retain their scope and subject"
      (replaceLine "        environment[\"TMP\"] = str(temporary)" "        environment[\"PATH\"] = str(home)" canonicalBytes)
      "PB-GRAMMAR-MONKEYPATCH"
      "PbMonkeypatchAssignment \"BootstrapAdapter.environment\" \"environment[...]\""
      [ problemFinding
          "PB-GRAMMAR-ENVIRONMENT"
          "PbClosedEnvironmentProblem \"environment must start empty and expose only exact contained home/cache/temp/toolchain values\""
      ]
  , grammarWithAdditional "changed public signatures fail the exact signature set"
      (replaceSame "def main():" "def mian():" canonicalBytes)
      "PB-GRAMMAR-SIGNATURE"
      "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"<module>\" \"main\""
      , problemFinding "PB-GRAMMAR-ARGV" "PbArgvProvenanceProblem \"main function is absent\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main function is absent or duplicated\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"main function is absent\""
      ]
  , grammarWithAdditional "dynamic import calls remain a distinct problem class"
      (replaceLine "    root = adapter.repository_root()" "    root = __import__(\"os\")" canonicalBytes)
      "PB-GRAMMAR-DYNAMIC-IMPORT"
      "PbDynamicImport \"__import__\""
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"__import__\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"repository root must come only from BootstrapAdapter.repository_root\""
      ]
  , grammarWithAdditional "reflection calls remain a distinct problem class"
      (replaceLine "    root = adapter.repository_root()" "    root = eval(\"__file__\")" canonicalBytes)
      "PB-GRAMMAR-REFLECTION"
      "PbReflectionForbidden \"eval\""
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"eval\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"repository root must come only from BootstrapAdapter.repository_root\""
      ]
  , grammarWithAdditional "hook calls remain a distinct problem class"
      (replaceLine "    root = adapter.repository_root()" "    root = sys.meta_path.append(x)" canonicalBytes)
      "PB-GRAMMAR-HOOK"
      "PbHookForbidden \"sys.meta_path.append\""
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"sys.meta_path.append\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"repository root must come only from BootstrapAdapter.repository_root\""
      ]
  , grammarWithAdditional "direct effects outside the adapter remain explicit"
      (replaceLine "    root = adapter.repository_root()" "    root = platform.system()" canonicalBytes)
      "PB-GRAMMAR-DIRECT-EFFECT"
      "PbDirectEffect \"bootstrap\" \"platform.system\""
      [problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"repository root must come only from BootstrapAdapter.repository_root\""]
  , grammarWithAdditional "the sole concrete adapter construction is counted exactly"
      (replaceLine "    adapter = BootstrapAdapter()" "    adapter = object()" canonicalBytes)
      "PB-GRAMMAR-ADAPTER-COUNT"
      "PbAdapterConstructionCount 0"
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"main\" \"object\""
      , problemFinding "PB-GRAMMAR-ARGV" "PbArgvProvenanceProblem \"main must pass sys.argv[1:] unchanged to the injected bootstrap seam\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main alone must construct BootstrapAdapter and call bootstrap(adapter, sys.argv[1:])\""
      ]
  , grammarWithAdditional "unresolved adapter methods retain caller and syntax"
      (replaceLine "    observed_platform = adapter.platform()" "    observed_platform = adapter.mystery()" canonicalBytes)
      "PB-GRAMMAR-UNRESOLVED-CALL"
      "PbUnresolvedCall \"bootstrap\" \"adapter.mystery\""
      [problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"platform observation must come only through the injected adapter\""]
  , grammarWithAdditional "argv slicing remains an independently located proof"
      (replaceSame "sys.argv[1:]" "sys.argv[2:]" canonicalBytes)
      "PB-GRAMMAR-ARGV"
      "PbArgvProvenanceProblem \"main must pass sys.argv[1:] unchanged to the injected bootstrap seam\""
      [ problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main alone must construct BootstrapAdapter and call bootstrap(adapter, sys.argv[1:])\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"main must end with exact bootstrap(adapter, sys.argv[1:])\""
      ]
  , grammar "toolchain pins are derived from the AST"
      (replaceSame "GHC_VERSION = \"9.12.4\"" "GHC_VERSION = \"9.12.3\"" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"GHC_VERSION must be 9.12.4\""
  , grammar "binary decoding is exact before handoff"
      (replaceSame "decode(\"utf-8\")" "decode(\"utf-9\")" canonicalBytes)
      "PB-GRAMMAR-BINARY"
      "PbBinaryProvenanceProblem \"binary locator is not exact UTF-8\""
  , grammar "the injection guard literal remains exact"
      (replaceSame "__name__ == \"__main__\"" "__name__ == \"__maim__\"" canonicalBytes)
      "PB-GRAMMAR-INJECTION"
      "PbInjectionSeamProblem \"module must end in exact if __name__ == \\\"__main__\\\": main() guard\""
  , grammar "existing-artifact equality remains fail-closed"
      (replaceSame "if existing_digest == digest:" "if existing_digest != digest:" canonicalBytes)
      "PB-GRAMMAR-GHCUP-ENSURE"
      "PbGhcupEnsureProblem \"ensure_ghcup must return a matching existing artifact, fail closed on mismatch, and verify absence acquisition before write\""
  , grammar "ambient environment copying remains outside the closed mapping"
      (replaceLine "        temporary.mkdir(parents=True, exist_ok=True)" "        os.environ.copy()" canonicalBytes)
      "PB-GRAMMAR-ENVIRONMENT"
      "PbClosedEnvironmentProblem \"environment must start empty and expose only exact contained home/cache/temp/toolchain values\""
  , grammar "build directory provenance remains below the toolchain"
      (replaceLine "    builddir = toolchain / \"dist-newstyle\"" "    builddir = root / \"dist-newstyle\"" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"Cabal build directory must be below the exact adapter toolchain root\""
  , grammar "platform branch literals remain a closed exact set"
      (replaceSame "machine == \"x86_64\"" "machine == \"x86_63\"" canonicalBytes)
      "PB-GRAMMAR-PLATFORM"
      "PbPlatformProofProblem \"platform adapter URL/SHA/system/machine/executable set is not exact\""
  , grammar "a returning handoff cannot stand in for an exec request"
      (replaceLine "        os.execv(binary, arguments)" "        return binary" canonicalBytes)
      "PB-GRAMMAR-CONTROL-FLOW"
      "PbHandoffControlFlowProblem \"handoff must contain exactly one final os.execv request\""
  , GrammarCase
      "argv proof refuses an absent main definition"
      (replaceSame "def main():" "def mian():" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"<module>\" \"main\""
      , problemFinding "PB-GRAMMAR-ARGV" "PbArgvProvenanceProblem \"main function is absent\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main function is absent or duplicated\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"main function is absent\""
      ]
  , GrammarCase
      "argv proof refuses an absent bootstrap definition"
      (replaceSame "def bootstrap(adapter, arguments):" "def bootstrup(adapter, arguments):" canonicalBytes)
      absentBootstrapProblems
  , grammarWithAdditional
      "argv proof requires the exact final handoff expression"
      (replaceLine "    adapter.handoff(binary, [binary] + arguments)" "    adapter.handoff(binary, [binary] + binary)" canonicalBytes)
      "PB-GRAMMAR-ARGV"
      "PbArgvProvenanceProblem \"bootstrap must hand off [binary] + arguments exactly\""
      [ problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap must end with exact adapter.handoff(binary, [binary] + arguments)\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap must contain exactly one handoff request and it must be the final reachable statement\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap handoff request is absent, duplicated, or unreachable\""
      ]
  , grammarWithAdditional
      "argv proof counts sys.argv exactly"
      (replaceLine "    binary = binary_text.strip()" "    binary = sys.argv" canonicalBytes)
      "PB-GRAMMAR-ARGV"
      "PbArgvProvenanceProblem \"sys.argv occurrence count is 2\""
      [problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"binary path is not derived only from list-bin output\""]
  , grammarWithAdditional
      "argv proof counts the bootstrap argument exactly"
      (replaceLine "    binary = binary_text.strip()" "    binary = arguments" canonicalBytes)
      "PB-GRAMMAR-ARGV"
      "PbArgvProvenanceProblem \"bootstrap arguments occurrence count is 2\""
      [problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"binary path is not derived only from list-bin output\""]
  , GrammarCase
      "injection proof refuses an absent bootstrap definition"
      (replaceSame "def bootstrap(adapter, arguments):" "def bootstrup(adapter, arguments):" canonicalBytes)
      absentBootstrapProblems
  , GrammarCase
      "injection proof refuses an absent main definition"
      (replaceSame "def main():" "def mian():" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"<module>\" \"main\""
      , problemFinding "PB-GRAMMAR-ARGV" "PbArgvProvenanceProblem \"main function is absent\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main function is absent or duplicated\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"main function is absent\""
      ]
  , GrammarCase
      "injection proof requires the exact bootstrap signature"
      (replaceSame "def bootstrap(adapter, arguments):" "def bootstrap(adapter, argumentz):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"bootstrap signature must be exactly (adapter, arguments)\""
      ]
  , GrammarCase
      "injection proof requires an empty main signature"
      ( replaceBalanced
          "def main():\n"
          "def main(x):\n"
          "GHCUP_VERSION = \"0.2.6.2\""
          "GHCUP_VERSION = \"0.2.6.\""
          canonicalBytes
      )
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      , problemFinding "PB-GRAMMAR-PIN" "PbPinProblem \"GHCUP_VERSION must be 0.2.6.2\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main signature must be empty\""
      ]
  , grammarWithAdditional
      "injection proof confines construction to main"
      (replaceLine "    root = adapter.repository_root()" "    root = BootstrapAdapter()" canonicalBytes)
      "PB-GRAMMAR-ADAPTER-COUNT"
      "PbAdapterConstructionCount 2"
      [ problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"the sole concrete adapter construction must occur in main\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"repository root must come only from BootstrapAdapter.repository_root\""
      ]
  , GrammarCase
      "injection proof counts the module main call exactly"
      (replaceLine "BUILD_TARGET = \"exe:amoebius\"" "main()" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-PIN" "PbPinProblem \"BUILD_TARGET exact string assignment count is 0\""
      , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"main must be called exactly once by the module guard\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"module body before the exact main guard may contain only direct imports, literal constants, and the closed definitions\""
      ]
  , grammar "pin proof requires one exact module string assignment"
      (replaceSame "GHCUP_VERSION" "GHCUP_VERSIOM" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"GHCUP_VERSION exact string assignment count is 0\""
  , grammar "ghcup pin is exact"
      (replaceSame "0.2.6.2\"" "0.2.6.3\"" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"GHCUP_VERSION must be 0.2.6.2\""
  , grammar "Cabal pin is exact"
      (replaceSame "CABAL_VERSION = \"3.16.1.0\"" "CABAL_VERSION = \"3.16.1.1\"" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"CABAL_VERSION must be 3.16.1.0\""
  , grammar "build-target pin is exact"
      (replaceSame "BUILD_TARGET = \"exe:amoebius\"" "BUILD_TARGET = \"exe:amoebiux\"" canonicalBytes)
      "PB-GRAMMAR-PIN"
      "PbPinProblem \"BUILD_TARGET must be exe:amoebius\""
  , GrammarCase
      "binary proof refuses an absent bootstrap definition"
      (replaceSame "def bootstrap(adapter, arguments):" "def bootstrup(adapter, arguments):" canonicalBytes)
      absentBootstrapProblems
  , GrammarCase
      "binary proof requires one binary-text assignment"
      (replaceSame "binary_text = binary_bytes.decode" "binary_texx = binary_bytes.decode" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"binary_text.strip\""
      , problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"binary_text assignment count is 0\""
      ]
  , grammarWithAdditional
      "binary bytes require the contained list-bin locator"
      ( replaceLine
          "    binary_bytes = adapter.capture(root, [str(cabal), \"--store-dir=\" + str(store), \"list-bin\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
          "    binary_bytes = adapter.run(root, [str(cabal), \"--store-dir=\" + str(store), \"list-bin\", \"--builddir=\" + str(builddir), \"--with-compiler=\" + str(ghc), BUILD_TARGET], environment)"
          canonicalBytes
      )
      "PB-GRAMMAR-BINARY"
      "PbBinaryProvenanceProblem \"binary bytes do not come from contained cabal list-bin\""
      [problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"the four contained child calls, methods, and argv lists are not structurally exact or an additional child call is present\""]
  , GrammarCase
      "binary path derives only from stripped locator output"
      (replaceSame "binary_text.strip()" "binary_text.strix()" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"binary_text.strix\""
      , problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"binary path is not derived only from list-bin output\""
      ]
  , grammarWithAdditional
      "binary build must precede the locator"
      (replaceSame "\"build\"" "\"builx\"" canonicalBytes)
      "PB-GRAMMAR-BINARY"
      "PbBinaryProvenanceProblem \"one exact build must precede one exact list-bin\""
      [problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"the four contained child calls, methods, and argv lists are not structurally exact or an additional child call is present\""]
  , GrammarCase
      "ensure proof refuses an absent adapter method"
      (replaceSame "def ensure_ghcup(self, url, digest, target):" "def ensure_ghcap(self, url, digest, target):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.ensure_ghcup\""
      , problemFinding "PB-GRAMMAR-GHCUP-ENSURE" "PbGhcupEnsureProblem \"BootstrapAdapter.ensure_ghcup is absent\""
      ]
  , GrammarCase
      "environment proof refuses an absent environment method"
      (replaceSame "def environment(self, toolchain):" "def environmant(self, toolchain):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-MONKEYPATCH" "PbMonkeypatchAssignment \"BootstrapAdapter.environmant\" \"environment[...]\""
      , problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.environment\""
      , problemFinding "PB-GRAMMAR-ENVIRONMENT" "PbClosedEnvironmentProblem \"BootstrapAdapter.environment is absent\""
      ]
  , GrammarCase
      "environment proof refuses an absent run method"
      (replaceSame "def run(self, root, arguments, environment):" "def rum(self, root, arguments, environment):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.run\""
      , problemFinding "PB-GRAMMAR-ENVIRONMENT" "PbClosedEnvironmentProblem \"BootstrapAdapter.run is absent\""
      ]
  , GrammarCase
      "environment proof refuses an absent capture method"
      (replaceSame "def capture(self, root, arguments, environment):" "def captare(self, root, arguments, environment):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.capture\""
      , problemFinding "PB-GRAMMAR-ENVIRONMENT" "PbClosedEnvironmentProblem \"BootstrapAdapter.capture is absent\""
      ]
  , grammar "run requires the exact closed subprocess call"
      (replaceSame "check=True, shell=False)" "check=True, shell=True )" canonicalBytes)
      "PB-GRAMMAR-ENVIRONMENT"
      "PbClosedEnvironmentProblem \"run must invoke subprocess.run with the injected argv/environment, shell=False, and no ambient lookup\""
  , grammar "capture requires the exact closed subprocess call"
      (replaceSame "stdout=subprocess.PIPE" "stdout=subprocess.NONE" canonicalBytes)
      "PB-GRAMMAR-ENVIRONMENT"
      "PbClosedEnvironmentProblem \"capture must invoke exact shell=False subprocess.run and return only stdout\""
  , GrammarCase
      "toolchain proof refuses an absent repository-root method"
      (replaceSame "def repository_root(self):" "def repository_roat(self):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.repository_root\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"BootstrapAdapter.repository_root is absent\""
      ]
  , grammar "toolchain proof requires one root assignment"
      (replaceSame "    root = adapter.repository_root()" "    roat = adapter.repository_root()" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"root assignment count is 0\""
  , grammar "toolchain repository root shape is exact"
      (replaceSame "resolve().parents[1]" "resolve().parents[0]" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"repository root must be the absolute source-relative Path(__file__).resolve().parents[1]\""
  , grammar "toolchain artifact is selected from the observed platform"
      (replaceSame "select_artifact(observed_platform[0], observed_platform[1])" "select_artifact(observed_platform[1], observed_platform[1])" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"platform artifact must come from the pure selector fed by adapter.platform()\""
  , grammar "toolchain root path is closed below the repository"
      (replaceSame "root / \".build\"" "root / \".builx\"" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"toolchain root is not the closed adapter path below the absolute repository root\""
  , grammar "toolchain ghcup target is contained"
      (replaceSame "toolchain / \"bootstrap\"" "toolchain / \"bootstrup\"" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"ghcup target is not rooted in the contained toolchain with the adapter filename\""
  , GrammarCase
      "toolchain ghcup executable is the ensure result"
      (replaceLine "    ghcup = adapter.ensure_ghcup(artifact[0], artifact[1], ghcup_target)" "    ghcup = adapter.ensure_ghcap(artifact[0], artifact[1], ghcup_target)" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.ensure_ghcap\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"ghcup executable must be the verified ensure result\""
      ]
  , GrammarCase
      "toolchain environment comes only from the adapter"
      (replaceLine "    environment = adapter.environment(toolchain)" "    environment = adapter.environmant(toolchain)" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.environmant\""
      , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"child environment must be derived only from the contained toolchain\""
      ]
  , grammar "toolchain executable paths are exact"
      (replaceLine "    ghc = toolchain / \".ghcup\" / \"ghc\" / GHC_VERSION / \"bin\" / (\"ghc\" + artifact[4])" "    ghc = toolchain / \".ghcup\" / \"ghc\" / GHC_VERSION / \"bin\" / (\"ghx\" + artifact[4])" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"GHC/Cabal executables are not exact contained versioned paths\""
  , grammar "Cabal store provenance remains below the toolchain"
      (replaceSame "toolchain / \"cabal-store\"" "toolchain / \"cabal-storz\"" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"Cabal store must be below the exact adapter toolchain root\""
  , grammar "toolchain child calls are structurally exact"
      (replaceSame "\"--set\"" "\"--sea\"" canonicalBytes)
      "PB-GRAMMAR-TOOLCHAIN"
      "PbToolchainExecutableProblem \"the four contained child calls, methods, and argv lists are not structurally exact or an additional child call is present\""
  , GrammarCase
      "platform proof refuses an absent pure selector"
      (replaceSame "def select_artifact(system, machine):" "def select_artifect(system, machine):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"select_artifact\""
      , problemFinding "PB-GRAMMAR-PLATFORM" "PbPlatformProofProblem \"select_artifact is absent or duplicated\""
      ]
  , GrammarCase
      "platform proof refuses an absent adapter method"
      (replaceSame "def platform(self):" "def platforn(self):" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.platform\""
      , problemFinding "PB-GRAMMAR-PLATFORM" "PbPlatformProofProblem \"BootstrapAdapter.platform is absent\""
      ]
  , GrammarCase
      "platform observation body is exact"
      (replaceSame "return (platform.system(), platform.machine())" "return (platform.system(), platform.systemx())" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"BootstrapAdapter.platform\" \"platform.systemx\""
      , problemFinding "PB-GRAMMAR-PLATFORM" "PbPlatformProofProblem \"concrete platform observation must return only platform.system() and platform.machine()\""
      ]
  , grammar "platform selector ends in the exact refusal"
      (replaceSame "unsupported-platform" "unsupported-platforn" canonicalBytes)
      "PB-GRAMMAR-PLATFORM"
      "PbPlatformProofProblem \"pure platform selector must end in the exact unsupported-platform raise\""
  , GrammarCase
      "platform selector requires exactly four top-level branches"
      ( sequenceReplace
          [ ("    if system == \"Linux\" and machine == \"aarch64\":", "        if system == \"Linux\" and machine == \"aarch64\":")
          , ("        return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2\"", "            return (\"https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2\"")
          , ("\"linux-arm64\"", "\"lin\"")
          ]
          canonicalBytes
      )
      [ problemFinding "PB-GRAMMAR-PLATFORM" "PbPlatformProofProblem \"pure platform selector must contain exactly four branches\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"control-flow graph contains unreachable nodes in select_artifact: 3,4\""
      ]
  , grammar "platform branches require pure literal tuple returns"
      (sequenceReplace [("        return (", "        return ["), (", \"\")\n", ", \"\"]\n")] canonicalBytes)
      "PB-GRAMMAR-PLATFORM"
      "PbPlatformProofProblem \"platform branch is not an exact pure literal return\""
  , grammar "platform branch conditions require exact equalities"
      (replaceSame "system == \"Linux\"" "system != \"Linux\"" canonicalBytes)
      "PB-GRAMMAR-PLATFORM"
      "PbPlatformProofProblem \"platform branch condition is not exact pure system/machine equality\""
  , GrammarCase
      "control flow refuses an absent handoff method"
      ( replaceBalanced
          "def handoff(self, binary, arguments):"
          "def handoffx(self, binary, arguments):"
          "GHCUP_VERSION = \"0.2.6.2\""
          "GHCUP_VERSION = \"0.2.6.\""
          canonicalBytes
      )
      [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
      , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrap\" \"adapter.handoff\""
      , problemFinding "PB-GRAMMAR-PIN" "PbPinProblem \"GHCUP_VERSION must be 0.2.6.2\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"BootstrapAdapter.handoff is absent\""
      ]
  , GrammarCase
      "control flow refuses bootstrap termination before handoff"
      (replaceLine "    binary = binary_text.strip()" "    return binary" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"binary assignment count is 0\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap may not return or raise before its final handoff request\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap handoff request is absent, duplicated, or unreachable\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"control-flow graph contains unreachable nodes in bootstrap: 18\""
      ]
  , GrammarCase
      "control flow refuses module termination before the guard"
      (replaceLine "BUILD_TARGET = \"exe:amoebius\"" "raise RuntimeError(\"stop\")" canonicalBytes)
      [ problemFinding "PB-GRAMMAR-PIN" "PbPinProblem \"BUILD_TARGET exact string assignment count is 0\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"module body may not return or raise before the exact main guard\""
      , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"module body before the exact main guard may contain only direct imports, literal constants, and the closed definitions\""
      ]
  , grammar "UTF-8 BOM is rejected by exact line discipline"
      ( sequenceReplace
          [ ("import hashlib", ByteString.pack [0xef, 0xbb, 0xbf] <> "mport hashlib")
          , ("GHCUP_VERSION = \"0.2.6.2\"", "GHCUP_VERSION = \"0.2.6\"")
          ]
          canonicalBytes
      )
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"UTF-8 BOM is forbidden\""
  , grammar "tabs are rejected by exact line discipline"
      (replaceFirstByte 9 canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"tabs are forbidden\""
  , grammar "NUL is rejected by exact line discipline"
      (replaceFirstByte 0 canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"NUL is forbidden\""
  , grammar "the source requires one final LF"
      (replaceLastByte 32 canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"exact final LF is required\""
  , grammar "trailing blank lines are rejected"
      (replacePenultimateByte 10 canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"trailing blank lines are forbidden\""
  , grammar "blank physical lines are outside the grammar"
      (replaceLine "import os" "" canonicalBytes)
      "PB-GRAMMAR-LINE-DISCIPLINE"
      "PbLineDiscipline \"pb/__main__.py\" \"blank lines are outside the grammar\""
  , grammar "indentation requires a multiple of four spaces"
      (replaceLine "    if system == \"Linux\" and machine == \"x86_64\":" "  if system == \"Linux\" and machine == \"x86_64\":" canonicalBytes)
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 13 1 \"indentation must be a multiple of four spaces\""
  , grammar "indentation may increase by only one level"
      ( sequenceReplace
          [ ("    if system == \"Linux\" and machine == \"x86_64\":", "        if system == \"Linux\" and machine == \"x86_64\":")
          , ("\"linux-amd64\"", "\"linux-a\"")
          ]
          canonicalBytes
      )
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 13 1 \"indentation may increase by exactly four spaces\""
  , grammar "string literals require termination"
      (replaceSame "GHC_VERSION = \"9.12.4\"" "GHC_VERSION = \"9.12.4 " canonicalBytes)
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 9 15 \"unterminated string literal\""
  , grammar "string literals refuse escapes"
      (replaceSame "\"9.12.4\"" "\"9.12\\4\"" canonicalBytes)
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 9 20 \"string escapes are outside the grammar\""
  , grammar "string literals refuse control characters"
      (replaceOnce "\"9.12.4\"" (ByteString.pack [34, 31, 46, 49, 50, 46, 52, 34]) canonicalBytes)
      "PB-GRAMMAR-LEXICAL"
      "PbLexicalProblem \"pb/__main__.py\" 9 16 \"control character in string literal\""
  , grammar "parser refuses top-level indentation"
      ( sequenceReplace
          [ ("import hashlib", "    import hashlib")
          , ("\"linux-amd64\"", "\"linux-a\"")
          ]
          canonicalBytes
      )
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 1 1 \"unexpected top-level indentation\""
  , grammar "unsupported statements remain outside the grammar"
      (replaceLine "BUILD_TARGET = \"exe:amoebius\"" "pass" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 11 1 \"unsupported statement pass\""
  , grammar "parser refuses invalid assignment targets"
      (replaceLine "GHCUP_VERSION = \"0.2.6.2\"" "f() = \"0.2.6.2\"" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 8 5 \"invalid assignment target\""
  , grammar "None remains outside the closed grammar"
      (replaceLine "GHCUP_VERSION = \"0.2.6.2\"" "GHCUP_VERSION = None" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 8 17 \"None is outside the grammar\""
  , grammar "parser refuses a missing expression"
      (replaceLine "GHCUP_VERSION = \"0.2.6.2\"" "GHCUP_VERSION = )" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 8 17 \"expected expression\""
  , grammar "parser requires exact structural tokens"
      (replaceLine "import hashlib" "import x(" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 1 9 \"expected TokNewline\""
  , grammar "parser requires the from-import keyword"
      (replaceLine "from pathlib import Path" "from pathlib nope Path" canonicalBytes)
      "PB-GRAMMAR-PARSE"
      "PbParseProblem \"pb/__main__.py\" 7 14 \"expected keyword/name import\""
  ]

absentBootstrapProblems :: [Finding]
absentBootstrapProblems =
  [ problemFinding "PB-GRAMMAR-SIGNATURE" "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
  , problemFinding "PB-GRAMMAR-UNRESOLVED-CALL" "PbUnresolvedCall \"bootstrup\" \"adapter.repository_root\""
  , problemFinding "PB-GRAMMAR-ARGV" "PbArgvProvenanceProblem \"bootstrap function is absent\""
  , problemFinding "PB-GRAMMAR-BINARY" "PbBinaryProvenanceProblem \"bootstrap function is absent\""
  , problemFinding "PB-GRAMMAR-INJECTION" "PbInjectionSeamProblem \"bootstrap function is absent or duplicated\""
  , problemFinding "PB-GRAMMAR-TOOLCHAIN" "PbToolchainExecutableProblem \"bootstrap function is absent\""
  , problemFinding "PB-GRAMMAR-CONTROL-FLOW" "PbHandoffControlFlowProblem \"bootstrap function is absent\""
  ]

grammar :: String -> ByteString -> Text -> Text -> GrammarCase
grammar label bytes code detail =
  GrammarCase label bytes [problemFinding code detail]

grammarWithAdditional :: String -> ByteString -> Text -> Text -> [Finding] -> GrammarCase
grammarWithAdditional label bytes code detail additional =
  GrammarCase label bytes (problemFinding code detail : additional)

verifyGrammarFixture :: GrammarCase -> [String]
verifyGrammarFixture item =
  concat
    [ expectEqual
        (grammarLabel item <> " keeps the exact preflight byte count")
        4770
        (ByteString.length (grammarBytes item))
    , expectEqual
        (grammarLabel item <> " changes at least one local wire byte")
        False
        (grammarBytes item == canonicalBytes)
    ]

canonicalExpectedResult :: CheckResult
canonicalExpectedResult =
  CheckResult
    { checkName = diagnosticName
    , checkObservations = canonicalProofObservations
    , checkFindings = diagnosticOnlyFinding : phase50Findings
    }

canonicalProofObservations :: [Observation]
canonicalProofObservations =
  [ Observation "proof.subject.path" canonicalPathText
  , Observation "proof.subject.mode" canonicalMode
  , Observation "proof.subject.bytes" "4770"
  , Observation "proof.subject.sha256" expectedSha256
  , Observation "proof.expected.sha256" expectedSha256
  ]
    <> metricObservations canonicalMetrics
    <> [ Observation
          "proof.import-closure"
          "hashlib=hashlib,os=os,platform=platform,subprocess=subprocess,sys=sys,urllib=urllib.request,Path=pathlib.Path"
       , Observation "proof.resolved-call-count" "55"
       , Observation "proof.potential-effect-count" "36"
       , Observation "proof.control-flow" expectedControlFlow
       , Observation
          "proof.platform-labels"
          "linux-amd64,linux-arm64,darwin-arm64,windows-amd64"
       , Observation "proof.static-claims" expectedStaticClaims
       , Observation "proof.runtime-residue" (Text.intercalate "," residueNames)
       ]

expectedControlFlow :: Text
expectedControlFlow =
  Text.intercalate
    ";"
    [ "select_artifact|10|9|terminal|0"
    , "BootstrapAdapter.repository_root|2|1|terminal|0"
    , "BootstrapAdapter.platform|2|1|terminal|0"
    , "BootstrapAdapter.ensure_ghcup|18|17|terminal|0"
    , "BootstrapAdapter.environment|16|15|terminal|0"
    , "BootstrapAdapter.run|2|1|may-return|0"
    , "BootstrapAdapter.capture|2|1|terminal|0"
    , "BootstrapAdapter.handoff|2|1|may-return|1"
    , "bootstrap|19|18|may-return|1"
    , "main|3|2|may-return|0"
    ]

expectedStaticClaims :: Text
expectedStaticClaims =
  Text.intercalate
    "\n"
    [ "argv|sys.argv[1:]|arguments|binary"
    , "binary|exe:amoebius|0.2.6.2|9.12.4|3.16.1.0|contained cabal list-bin|os.execv through BootstrapAdapter.handoff"
    , "injection|bootstrap|adapter|arguments|main|if __name__ == \"__main__\": main()"
    , "phase50-invocation|<authenticated-absolute-python>|-I,-S,-B|/abs/repo/pb|<argv...>"
    , "ensure|true|true|true"
    , "environment|true|GHCUP_INSTALL_BASE_PREFIX,GHCUP_SKIP_UPDATE_CHECK,HOME,XDG_CACHE_HOME,TMPDIR,TEMP,TMP|GHCUP_INSTALL_BASE_PREFIX,HOME,XDG_CACHE_HOME,TMPDIR,TEMP,TMP|true"
    , "executables|Path(__file__).resolve().parents[1]/.build/toolchain/<closed-adapter>|verified adapter artifact under contained bootstrap root|contained ghcup GHC 9.12.4 path with adapter suffix|contained ghcup Cabal 3.16.1.0 path with adapter suffix|each subprocess argv[0] is str(ghcup) or str(cabal)"
    , "platform-limitations|WindowsAmd64RuntimeFidelityDeferredToPhase50,AllOtherPlatformsRefused"
    , "runtime-boundary|RuntimeTruthDeferredToPhase50"
    ]

residueNames :: [Text]
residueNames =
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

phase50Findings :: [Finding]
phase50Findings =
  [ Finding
      "PB-GRAMMAR-PHASE50-RUNTIME-RESIDUE"
      (Text.unpack residue)
      "static source grammar cannot establish this runtime property; Phase 50 must observe the pb child from the source-bound Haskell supervisor"
  | residue <- residueNames
  ]

diagnosticOnlyFinding :: Finding
diagnosticOnlyFinding =
  Finding
    "PB-GRAMMAR-DIAGNOSTIC-ONLY"
    diagnosticSubject
    "caller-supplied pb bytes are diagnostic input and cannot establish source custody or Phase-50 runtime truth"

preflightFinding :: Text -> Text -> Finding
preflightFinding code detail = Finding code diagnosticSubject detail

problemFinding :: Text -> Text -> Finding
problemFinding = preflightFinding

hardExpected :: [(FilePath, Text, ByteString)] -> [Finding] -> CheckResult
hardExpected inventory findings =
  CheckResult
    { checkName = diagnosticName
    , checkObservations = preflightObservations inventory
    , checkFindings = diagnosticOnlyFinding : findings
    }

semanticExpected :: ByteString -> [Finding] -> CheckResult
semanticExpected bytes problems =
  CheckResult
    { checkName = diagnosticName
    , checkObservations =
        preflightObservations [(canonicalPath, canonicalMode, bytes)]
    , checkFindings =
        [ diagnosticOnlyFinding
        , preflightFinding
            "PB-GRAMMAR-DIGEST-EXACT"
            ( "expected independently frozen SHA-256 "
                <> expectedSha256
                <> "; observed "
                <> sha256Hex bytes
            )
        , preflightFinding
            "PB-GRAMMAR-BYTES-EXACT"
            "the digest-bound subject differs from the private canonical byte declaration"
        ]
          <> problems
    }

preflightObservations :: [(FilePath, Text, ByteString)] -> [Observation]
preflightObservations inventory =
  [ Observation "input.file-count" (decimal (boundedLength 2 inventory))
  , Observation "limit.input-files" "1"
  , Observation "expected.path" canonicalPathText
  , Observation "expected.mode" canonicalMode
  , Observation "expected.bytes" "4770"
  , Observation "expected.sha256" expectedSha256
  ]
    <> case (boundedLength 2 inventory, take 1 inventory) of
      (1, [(path, mode, bytes)]) ->
        [ Observation "input.path-characters" (decimal (boundedLength 1025 path))
        , Observation "input.mode-characters" (decimal (Text.length mode))
        , Observation "input.bytes" (decimal (ByteString.length bytes))
        ]
          <> [Observation "input.path" (Text.pack path) | boundedLength 1025 path <= 1024]
          <> [Observation "input.mode" mode | Text.length mode <= 6]
          <> if ByteString.length bytes <= 4770
            then
              [Observation "input.sha256" (sha256Hex bytes)]
                <> metricObservations (measure bytes)
            else []
      _ -> []

data Metrics = Metrics
  { metricBytes :: Int
  , metricPhysicalLines :: Int
  , metricAstNodes :: Int
  , metricLexicalTokens :: Int
  , metricDepth :: Int
  , metricCalls :: Int
  , metricEffects :: Int
  , metricControlFlow :: Int
  , metricProblems :: Int
  }
  deriving (Eq, Show)

canonicalMetrics :: Metrics
canonicalMetrics = Metrics 4770 90 389 839 4 72 25 28 0

metricObservations :: Metrics -> [Observation]
metricObservations metrics =
  [ Observation "resource.source-bytes" (decimal (metricBytes metrics))
  , Observation "resource.physical-lines" (decimal (metricPhysicalLines metrics))
  , Observation "resource.ast-nodes" (decimal (metricAstNodes metrics))
  , Observation "resource.lexical-tokens" (decimal (metricLexicalTokens metrics))
  , Observation "resource.syntax-depth" (decimal (metricDepth metrics))
  , Observation "resource.call-markers" (decimal (metricCalls metrics))
  , Observation "resource.effect-markers" (decimal (metricEffects metrics))
  , Observation "resource.control-flow-markers" (decimal (metricControlFlow metrics))
  , Observation "resource.problem-markers" (decimal (metricProblems metrics))
  , Observation "limit.source-bytes" "4770"
  , Observation "limit.path-characters" "1024"
  , Observation "limit.mode-characters" "6"
  , Observation "limit.physical-lines" "128"
  , Observation "limit.ast-nodes" "512"
  , Observation "limit.lexical-tokens" "1024"
  , Observation "limit.syntax-depth" "16"
  , Observation "limit.call-markers" "128"
  , Observation "limit.effect-markers" "64"
  , Observation "limit.control-flow-markers" "32"
  , Observation "limit.problem-markers" "64"
  , Observation "limit.problems" "64"
  ]

data ResourceBoundary = ResourceBoundary
  { boundaryLabel :: String
  , boundaryExactBytes :: ByteString
  , boundaryExactMetrics :: Metrics
  , boundaryOverBytes :: ByteString
  , boundaryOverMetrics :: Metrics
  , boundaryOverFindings :: [Finding]
  }

resourceBoundaryFixtures :: [ResourceBoundary]
resourceBoundaryFixtures =
  [ ResourceBoundary
      "physical lines"
      astBoundaryBytes
      (Metrics 4770 128 128 128 0 0 0 0 0)
      astOverBytes
      (Metrics 4770 129 129 129 0 0 0 0 0)
      [resourceFinding "physical-lines" 128 129]
  , ResourceBoundary
      "AST nodes"
      astNodeBoundaryBytes
      (Metrics 4770 1 512 512 0 0 0 0 0)
      astNodeOverBytes
      (Metrics 4770 1 513 513 0 0 0 0 0)
      [resourceFinding "ast-nodes" 512 513]
  , ResourceBoundary
      "lexical tokens"
      tokenBoundaryBytes
      (Metrics 4770 1 1 1024 0 0 0 0 0)
      tokenOverBytes
      (Metrics 4770 1 1 1025 0 0 0 0 0)
      [resourceFinding "lexical-tokens" 1024 1025]
  , ResourceBoundary
      "syntax depth"
      depthBoundaryBytes
      (Metrics 4770 1 17 33 16 16 0 0 0)
      depthOverBytes
      (Metrics 4770 1 18 35 17 17 0 0 0)
      [resourceFinding "syntax-depth" 16 17]
  , ResourceBoundary
      "indentation depth"
      indentationBoundaryBytes
      (Metrics 4770 1 1 1 16 0 0 0 0)
      indentationOverBytes
      (Metrics 4770 1 1 1 17 0 0 0 0)
      [resourceFinding "syntax-depth" 16 17]
  , ResourceBoundary
      "call markers"
      callBoundaryBytes
      (Metrics 4770 1 257 513 2 128 0 0 0)
      callOverBytes
      (Metrics 4770 1 259 517 2 129 0 0 0)
      [resourceFinding "resolved-call-markers" 128 129]
  , ResourceBoundary
      "effect markers"
      effectBoundaryBytes
      (Metrics 4770 64 128 192 1 64 64 0 0)
      effectOverBytes
      (Metrics 4770 65 130 195 1 65 65 0 0)
      [resourceFinding "potential-effect-markers" 64 65]
  , ResourceBoundary
      "control-flow markers"
      controlBoundaryBytes
      (Metrics 4770 33 49 113 1 16 0 32 0)
      controlOverBytes
      (Metrics 4770 34 51 118 1 17 0 33 0)
      [resourceFinding "control-flow-markers" 32 33]
  , ResourceBoundary
      "problem markers"
      problemMarkerBoundaryBytes
      (Metrics 4770 1 1 65 0 0 0 0 64)
      problemMarkerOverBytes
      (Metrics 4770 1 1 66 0 0 0 0 65)
      [resourceFinding "problem-markers" 64 65]
  ]

verifyBoundaryFixture :: ResourceBoundary -> [String]
verifyBoundaryFixture boundary =
  concat
    [ expectEqual
        (boundaryLabel boundary <> " exact maximum fixture integrity")
        (boundaryExactMetrics boundary)
        (measure (boundaryExactBytes boundary))
    , expectEqual
        (boundaryLabel boundary <> " maximum-plus-one fixture integrity")
        (boundaryOverMetrics boundary)
        (measure (boundaryOverBytes boundary))
    , expectEqual
        (boundaryLabel boundary <> " exact-size controls")
        (4770, 4770)
        ( ByteString.length (boundaryExactBytes boundary)
        , ByteString.length (boundaryOverBytes boundary)
        )
    ]

checkResourceBoundary :: ResourceBoundary -> [String]
checkResourceBoundary boundary =
  expectExact
    (boundaryLabel boundary <> " exact maximum reaches bounded semantic refusal")
    (semanticExpected
      (boundaryExactBytes boundary)
      (boundaryExactProblems boundary))
    (runDiagnostic (boundaryExactBytes boundary))
    <> expectExact
      (boundaryLabel boundary <> " maximum-plus-one refuses in preflight")
      (hardExpected
        [(canonicalPath, canonicalMode, boundaryOverBytes boundary)]
        (boundaryOverFindings boundary))
      (runDiagnostic (boundaryOverBytes boundary))

boundaryExactProblems :: ResourceBoundary -> [Finding]
boundaryExactProblems boundary
  | boundaryLabel boundary == "problem markers" =
      [problemFinding
        "PB-GRAMMAR-LINE-DISCIPLINE"
        "PbLineDiscipline \"pb/__main__.py\" \"NUL is forbidden\""]
  | boundaryLabel boundary == "indentation depth" =
      [problemFinding
        "PB-GRAMMAR-LEXICAL"
        "PbLexicalProblem \"pb/__main__.py\" 1 1 \"indentation may increase by exactly four spaces\""]
  | boundaryLabel boundary == "AST nodes" =
      [problemFinding
        "PB-GRAMMAR-PARSE"
        "PbParseProblem \"pb/__main__.py\" 1 2 \"expected TokNewline\""]
  | boundaryLabel boundary == "lexical tokens" =
      [problemFinding
        "PB-GRAMMAR-PARSE"
        "PbParseProblem \"pb/__main__.py\" 1 3 \"expected TokNewline\""]
  | boundaryLabel boundary == "physical lines" =
      missingProgramProblems [] True
  | boundaryLabel boundary == "syntax depth" =
      missingProgramProblems [] False
  | boundaryLabel boundary == "call markers" =
      missingProgramProblems
        [problemFinding
          "PB-GRAMMAR-UNRESOLVED-CALL"
          "PbUnresolvedCall \"<module>\" \"a\""]
        False
  | boundaryLabel boundary == "effect markers" =
      missingProgramProblems
        [problemFinding
          "PB-GRAMMAR-UNRESOLVED-CALL"
          "PbUnresolvedCall \"<module>\" \"urlopen\""]
        True
  | boundaryLabel boundary == "control-flow markers" =
      missingProgramProblems [] True
  | otherwise =
      [problemFinding
        "PB-GRAMMAR-INTERNAL"
        ("unmodeled exact-boundary label " <> Text.pack (show (boundaryLabel boundary)))]

missingProgramProblems :: [Finding] -> Bool -> [Finding]
missingProgramProblems afterAdapter includeModuleBody =
  [ problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:hashlib\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:os\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:platform\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:subprocess\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:sys\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:urllib.request\""
  , problemFinding "PB-GRAMMAR-IMPORT" "PbUnsupportedImport \"missing:pathlib.Path\""
  , problemFinding
      "PB-GRAMMAR-SIGNATURE"
      "PbSignatureProblem \"top-level functions/classes or their signatures are not exact\""
  , problemFinding
      "PB-GRAMMAR-SIGNATURE"
      "PbSignatureProblem \"BootstrapAdapter method set or signatures are not exact\""
  , problemFinding "PB-GRAMMAR-ADAPTER-COUNT" "PbAdapterConstructionCount 0"
  ]
    <> afterAdapter
    <> [ problemFinding
          "PB-GRAMMAR-ARGV"
          "PbArgvProvenanceProblem \"main function is absent\""
       , problemFinding
          "PB-GRAMMAR-BINARY"
          "PbBinaryProvenanceProblem \"bootstrap function is absent\""
       , problemFinding
          "PB-GRAMMAR-INJECTION"
          "PbInjectionSeamProblem \"bootstrap function is absent or duplicated\""
       , problemFinding
          "PB-GRAMMAR-GHCUP-ENSURE"
          "PbGhcupEnsureProblem \"BootstrapAdapter.ensure_ghcup is absent\""
       , problemFinding
          "PB-GRAMMAR-ENVIRONMENT"
          "PbClosedEnvironmentProblem \"BootstrapAdapter.environment is absent\""
       , problemFinding
          "PB-GRAMMAR-TOOLCHAIN"
          "PbToolchainExecutableProblem \"bootstrap function is absent\""
       , problemFinding
          "PB-GRAMMAR-PLATFORM"
          "PbPlatformProofProblem \"select_artifact is absent or duplicated\""
       , problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"bootstrap function is absent\""
       ]
    <> [ problemFinding
          "PB-GRAMMAR-CONTROL-FLOW"
          "PbHandoffControlFlowProblem \"module body before the exact main guard may contain only direct imports, literal constants, and the closed definitions\""
       | includeModuleBody
       ]

resourceFinding :: Text -> Int -> Int -> Finding
resourceFinding name limit observed =
  preflightFinding
    "PB-GRAMMAR-RESOURCE-LIMIT"
    ( name
        <> " exceeds the "
        <> decimal limit
        <> " bound; observed "
        <> decimal observed
    )

astBoundaryBytes, astOverBytes :: ByteString
astBoundaryBytes = lineFixture 128
astOverBytes = lineFixture 129

lineFixture :: Int -> ByteString
lineFixture count =
  exactSize
    (ByteString8.concat (replicate (count - 1) "x\n") <> "x\n")

astNodeBoundaryBytes, astNodeOverBytes :: ByteString
astNodeBoundaryBytes = astNodeFixture 512
astNodeOverBytes = astNodeFixture 513

astNodeFixture :: Int -> ByteString
astNodeFixture count =
  exactSize ("x" <> ByteString8.replicate (count - 1) ',' <> "\n")

tokenBoundaryBytes, tokenOverBytes :: ByteString
tokenBoundaryBytes = exactSize (ByteString8.concat (replicate 1024 "x ") <> "\n")
tokenOverBytes = exactSize (ByteString8.concat (replicate 1025 "x ") <> "\n")

depthBoundaryBytes, depthOverBytes :: ByteString
depthBoundaryBytes = depthFixture 16
depthOverBytes = depthFixture 17

depthFixture :: Int -> ByteString
depthFixture count =
  exactSize
    ( ByteString8.replicate count '('
        <> "x"
        <> ByteString8.replicate count ')'
        <> "\n"
    )

indentationBoundaryBytes, indentationOverBytes :: ByteString
indentationBoundaryBytes = indentationFixture 16
indentationOverBytes = indentationFixture 17

indentationFixture :: Int -> ByteString
indentationFixture depth =
  exactSize (ByteString8.replicate (depth * 4) ' ' <> "x\n")

callBoundaryBytes, callOverBytes :: ByteString
callBoundaryBytes = callFixture 128
callOverBytes = callFixture 129

callFixture :: Int -> ByteString
callFixture count =
  exactSize
    ( "["
        <> ByteString8.intercalate "," (replicate count "a()")
        <> "]\n"
    )

effectBoundaryBytes, effectOverBytes :: ByteString
effectBoundaryBytes = effectFixture 64
effectOverBytes = effectFixture 65

effectFixture :: Int -> ByteString
effectFixture count =
  exactSize (ByteString8.concat (replicate count "urlopen()\n"))

controlBoundaryBytes, controlOverBytes :: ByteString
controlBoundaryBytes = controlFixture False
controlOverBytes = controlFixture True

controlFixture :: Bool -> ByteString
controlFixture over =
  exactSize
    ( "x\n"
        <> ByteString8.concat
          [ ByteString8.pack
              ("def f" <> show index <> "():\n    return x\n")
          | index <- [0 :: Int .. 15]
          ]
        <> if over then "def extra():\n" else ""
    )

problemMarkerBoundaryBytes, problemMarkerOverBytes :: ByteString
problemMarkerBoundaryBytes = exactSize (ByteString.replicate 64 0 <> "x\n")
problemMarkerOverBytes = exactSize (ByteString.replicate 65 0 <> "x\n")

problemBoundaryBytes, problemFloodBytes :: ByteString
problemBoundaryBytes = problemFixture 46
problemFloodBytes = problemFixture 47

problemFixture :: Int -> ByteString
problemFixture count =
  exactSize
    ( ByteString8.concat
        [ ByteString8.pack ("import x" <> show index <> "\n")
        | index <- [0 :: Int .. count - 1]
        ]
    )

unsupportedImportCount :: ByteString -> Int
unsupportedImportCount =
  length
    . filter (ByteString8.isPrefixOf "import x")
    . ByteString8.lines

-- This local minimal-program model has seven missing canonical imports, two
-- absent-signature problems, one missing adapter construction, and eight
-- independently typed downstream proof refusals in addition to its distinct
-- unsupported imports.  The oracle does not ask production to count them.
modeledMinimalProgramProblemCount :: ByteString -> Int
modeledMinimalProgramProblemCount bytes = unsupportedImportCount bytes + 18

exactSize :: ByteString -> ByteString
exactSize bytes
  | ByteString.length bytes > 4770 = ByteString.take 4770 bytes
  | otherwise = case ByteString.unsnoc bytes of
      Nothing -> ByteString8.replicate 4769 ' ' <> "\n"
      Just (prefix, finalByte)
        | finalByte == 10 ->
            prefix
              <> ByteString8.replicate (4770 - ByteString.length bytes) ' '
              <> "\n"
        | otherwise ->
            bytes
              <> ByteString8.replicate (4769 - ByteString.length bytes) ' '
              <> "\n"

measure :: ByteString -> Metrics
measure bytes =
  Metrics
    { metricBytes = ByteString.length bytes
    , metricPhysicalLines = countByte 10 bytes
    , metricAstNodes = astMarkers bytes
    , metricLexicalTokens = lexicalTokens bytes
    , metricDepth = max (maximumDepth bytes) (maximumIndentation bytes)
    , metricCalls = countByte 40 bytes
    , metricEffects = sum (map (`countSubstring` bytes) effectMarkers)
    , metricControlFlow = sum (map (`countSubstring` bytes) controlMarkers)
    , metricProblems =
        ByteString.foldl'
          (\count byte -> if byte == 0 || byte == 9 || byte == 13 || byte > 126 then count + 1 else count)
          0
          bytes
    }

countByte :: Word8 -> ByteString -> Int
countByte expected =
  ByteString.foldl'
    (\count observed -> if observed == expected then count + 1 else count)
    0

astMarkers :: ByteString -> Int
astMarkers bytes =
  countByte 10 bytes
    + sum [countByte marker bytes | marker <- [40, 91, 123, 61, 43, 47, 44]]

lexicalTokens :: ByteString -> Int
lexicalTokens = snd . ByteString.foldl' step (0 :: Int, 0 :: Int)
 where
  step (3, count) 34 = (0, count)
  step state@(3, _) _ = state
  step (1, count) byte
    | nameContinue byte = (1, count)
    | otherwise = start count byte
  step (2, count) byte
    | digit byte = (2, count)
    | otherwise = start count byte
  step (_, count) byte = start count byte
  start count byte
    | byte == 32 || byte == 10 || byte == 9 || byte == 13 = (0, count)
    | byte == 34 = (3, count + 1)
    | nameStart byte = (1, count + 1)
    | digit byte = (2, count + 1)
    | otherwise = (0, count + 1)
  nameStart byte =
    byte == 95
      || (byte >= 65 && byte <= 90)
      || (byte >= 97 && byte <= 122)
  nameContinue byte = nameStart byte || digit byte
  digit byte = byte >= 48 && byte <= 57

countSubstring :: ByteString -> ByteString -> Int
countSubstring needle = go 0
 where
  go count haystack
    | ByteString.null needle = count
    | otherwise =
        let (_, found) = ByteString.breakSubstring needle haystack
         in if ByteString.null found
              then count
              else go (count + 1) (ByteString.drop (ByteString.length needle) found)

effectMarkers :: [ByteString]
effectMarkers =
  [ ".is_file("
  , ".read_bytes("
  , ".mkdir("
  , "urlopen("
  , ".write_bytes("
  , ".chmod("
  , "subprocess.run("
  , "os.execv("
  , "platform.system("
  , "platform.machine("
  , ".repository_root("
  , ".platform("
  , ".ensure_ghcup("
  , ".environment("
  , ".run("
  , ".capture("
  , ".handoff("
  ]

controlMarkers :: [ByteString]
controlMarkers =
  [ "\ndef "
  , "\n    def "
  , "\nif "
  , "\n    if "
  , "\n        if "
  , "\nreturn "
  , "\n    return "
  , "\n        return "
  , "\nraise "
  , "\n    raise "
  , "\n        raise "
  , "\nclass "
  ]

maximumDepth :: ByteString -> Int
maximumDepth = snd . ByteString.foldl' step (0, 0)
 where
  step (depth, greatest) byte
    | byte `elem` [40, 91, 123] =
        let next = depth + 1 in (next, max greatest next)
    | byte `elem` [41, 93, 125] = (max 0 (depth - 1), greatest)
    | otherwise = (depth, greatest)

maximumIndentation :: ByteString -> Int
maximumIndentation bytes = greatest finalState
 where
  finalState = ByteString.foldl' step (True, 0 :: Int, 0 :: Int) bytes
  greatest (_, _, value) = value
  step (_, _, found) 10 = (True, 0, found)
  step (True, spaces, found) 32 = (True, spaces + 1, found)
  step (True, spaces, found) _ = (False, spaces, max found (spaces `div` 4))
  step state _ = state

replaceFirstByte :: Word8 -> ByteString -> ByteString
replaceFirstByte byte bytes =
  case ByteString.uncons bytes of
    Nothing -> ByteString.singleton byte
    Just (_, rest) -> ByteString.cons byte rest

replaceLastByte :: Word8 -> ByteString -> ByteString
replaceLastByte byte bytes =
  case ByteString.unsnoc bytes of
    Nothing -> ByteString.singleton byte
    Just (prefix, _) -> ByteString.snoc prefix byte

replacePenultimateByte :: Word8 -> ByteString -> ByteString
replacePenultimateByte byte bytes =
  case ByteString.unsnoc bytes of
    Nothing -> ByteString.singleton byte
    Just (prefix, finalByte) ->
      case ByteString.unsnoc prefix of
        Nothing -> ByteString.pack [byte, finalByte]
        Just (before, _) -> before <> ByteString.pack [byte, finalByte]

replaceSame :: ByteString -> ByteString -> ByteString -> ByteString
replaceSame old new bytes
  | ByteString.length old /= ByteString.length new = bytes
  | otherwise = replaceOnce old new bytes

replaceLine :: ByteString -> ByteString -> ByteString -> ByteString
replaceLine old new bytes
  | ByteString.length new > ByteString.length old = bytes
  | otherwise =
      replaceOnce
        (old <> "\n")
        (new <> ByteString8.replicate (ByteString.length old - ByteString.length new) ' ' <> "\n")
        bytes

replaceBalanced :: ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString
replaceBalanced growOld growNew shrinkOld shrinkNew bytes =
  replaceOnce shrinkOld shrinkNew (replaceOnce growOld growNew bytes)

sequenceReplace :: [(ByteString, ByteString)] -> ByteString -> ByteString
sequenceReplace replacements bytes =
  foldl (\current (old, new) -> replaceOnce old new current) bytes replacements

replaceOnce :: ByteString -> ByteString -> ByteString -> ByteString
replaceOnce old new bytes =
  let (before, found) = ByteString.breakSubstring old bytes
   in if ByteString.null found
        then bytes
        else before <> new <> ByteString.drop (ByteString.length old) found

runDiagnostic :: ByteString -> CheckResult
runDiagnostic bytes =
  pbBootstrapGrammarDiagnostic [(canonicalPath, canonicalMode, bytes)]

twoFileInventory :: [(FilePath, Text, ByteString)]
twoFileInventory =
  [ (canonicalPath, canonicalMode, canonicalBytes)
  , ("pb/helper.py", canonicalMode, "value = 1\n")
  ]

shortBytes, overByteBytes, changedButLexicalBytes :: ByteString
shortBytes = ByteString.take 4769 canonicalBytes
overByteBytes = canonicalBytes <> "#"
changedButLexicalBytes = replaceFirstByte 35 canonicalBytes

canonicalPath :: FilePath
canonicalPath = "pb/__main__.py"

canonicalPathText, canonicalMode, expectedSha256, diagnosticName :: Text
canonicalPathText = "pb/__main__.py"
canonicalMode = "100644"
expectedSha256 =
  "e210494d3ad4bcaad716daed5bb89cb5611107547e83eb018a6369e134cd5418"
diagnosticName = "pb-bootstrap-grammar-diagnostic"

diagnosticSubject :: FilePath
diagnosticSubject =
  "Amoebius.Validation.PbBootstrapGrammar.pbBootstrapGrammarDiagnostic"

boundedLength :: Int -> [value] -> Int
boundedLength limit = go 0
 where
  go count _ | count >= limit = count
  go count [] = count
  go count (_ : rest) = go (count + 1) rest

decimal :: Int -> Text
decimal = Text.pack . show

-- Independent, total SHA-256.  Safe indexing returns zero only for an invalid
-- internal schedule width; the empty/abc vectors and the independently frozen
-- 4,770-byte fixture make that fallback observable without a partial crash.
sha256Hex :: ByteString -> Text
sha256Hex input =
  Text.pack
    (concatMap wordHex (stateWords (foldl' compress initialHash (chunksOf64 (padSha256 input)))))

type HashState =
  (Word32, Word32, Word32, Word32, Word32, Word32, Word32, Word32)

initialHash :: HashState
initialHash =
  ( 0x6a09e667
  , 0xbb67ae85
  , 0x3c6ef372
  , 0xa54ff53a
  , 0x510e527f
  , 0x9b05688c
  , 0x1f83d9ab
  , 0x5be0cd19
  )

stateWords :: HashState -> [Word32]
stateWords (a, b, c, d, e, f, g, h) = [a, b, c, d, e, f, g, h]

sha256Constants :: [Word32]
sha256Constants =
  [ 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  , 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  , 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  , 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  , 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  , 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  , 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  , 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

padSha256 :: ByteString -> [Word8]
padSha256 input = bytes <> [0x80] <> replicate zeroCount 0 <> word64Bytes bitLength
 where
  bytes = ByteString.unpack input
  bitLength = fromIntegral (length bytes) * 8 :: Word64
  zeroCount = (56 - ((length bytes + 1) `mod` 64)) `mod` 64

word64Bytes :: Word64 -> [Word8]
word64Bytes value = [fromIntegral (value `shiftR` shift) | shift <- [56, 48 .. 0]]

chunksOf64 :: [Word8] -> [[Word8]]
chunksOf64 [] = []
chunksOf64 bytes = take 64 bytes : chunksOf64 (drop 64 bytes)

compress :: HashState -> [Word8] -> HashState
compress initial block = addState initial rounded
 where
  schedule = extendSchedule (map word32FromBytes (chunksOf4 block))
  rounded = foldl' roundStep initial (zip sha256Constants schedule)

roundStep :: HashState -> (Word32, Word32) -> HashState
roundStep (a, b, c, d, e, f, g, h) (constant, word) =
  let choice = (e .&. f) `xor` (complement e .&. g)
      majority = (a .&. b) `xor` (a .&. c) `xor` (b .&. c)
      upperA = rotateR a 2 `xor` rotateR a 13 `xor` rotateR a 22
      upperE = rotateR e 6 `xor` rotateR e 11 `xor` rotateR e 25
      temporaryOne = h + upperE + choice + constant + word
      temporaryTwo = upperA + majority
   in (temporaryOne + temporaryTwo, a, b, c, d + temporaryOne, e, f, g)

addState :: HashState -> HashState -> HashState
addState
  (a, b, c, d, e, f, g, h)
  (aa, bb, cc, dd, ee, ff, gg, hh) =
    (a + aa, b + bb, c + cc, d + dd, e + ee, f + ff, g + gg, h + hh)

chunksOf4 :: [Word8] -> [[Word8]]
chunksOf4 [] = []
chunksOf4 bytes = take 4 bytes : chunksOf4 (drop 4 bytes)

word32FromBytes :: [Word8] -> Word32
word32FromBytes [a, b, c, d] =
  fromIntegral a `shiftL` 24
    .|. fromIntegral b `shiftL` 16
    .|. fromIntegral c `shiftL` 8
    .|. fromIntegral d
word32FromBytes _ = 0

extendSchedule :: [Word32] -> [Word32]
extendSchedule initial = go initial 16
 where
  go wordsFound index
    | index >= 64 = take 64 wordsFound
    | otherwise =
        let smallZero value = rotateR value 7 `xor` rotateR value 18 `xor` shiftR value 3
            smallOne value = rotateR value 17 `xor` rotateR value 19 `xor` shiftR value 10
            next =
              smallOne (safeAt (index - 2) wordsFound)
                + safeAt (index - 7) wordsFound
                + smallZero (safeAt (index - 15) wordsFound)
                + safeAt (index - 16) wordsFound
         in go (wordsFound <> [next]) (index + 1)

safeAt :: Int -> [Word32] -> Word32
safeAt index = go index
 where
  go _ [] = 0
  go remaining (value : rest)
    | remaining < 0 = 0
    | remaining == 0 = value
    | otherwise = go (remaining - 1) rest

wordHex :: Word32 -> String
wordHex value = replicate (8 - length encoded) '0' <> encoded
 where
  encoded = showHex value ""

expectExact :: String -> CheckResult -> CheckResult -> [String]
expectExact label expected actual
  | expected == actual = []
  | otherwise =
      [ label
          <> ": expected exact CheckResult "
          <> show expected
          <> ", got "
          <> show actual
      ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", got " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics _ [] = pure ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (unlines ((name <> " component diagnostics failed:") : map ("  " <>) problems)))

-- Local wire declaration.  Its byte count and digest are checked above against
-- independent literals; no production value is imported or projected.
canonicalBytes :: ByteString
canonicalBytes =
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

pbBootstrapFixtureBytes :: ByteString
pbBootstrapFixtureBytes = canonicalBytes
