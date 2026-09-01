{-# LANGUAGE OverloadedStrings #-}

module SourceConsumerGraphOracle
  ( runSourceConsumerGraphOracle
  , runSourceConsumerGraphSelectorControlOracle
  , runSourceConsumerGraphSelectorOracle
  , sourceConsumerGraphSelectorIntents
  , sourceConsumerGraphSelectorNames
  ) where

-- Independently authored primitive wire rows and exact CheckResult values.
-- No source snapshot, closure, graph, role, subject, effect, problem, or
-- production fixture declaration is imported.
import Amoebius.Validation.SourceConsumerGraph
  ( sourceConsumerGraphDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , checkPassed
  )
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

type EntryWire = (FilePath, Text, Text, Text)
type EffectWire = (FilePath, Text, Text, Text, Text, Text)

data ExactCase = ExactCase String [String]

runSourceConsumerGraphOracle :: IO ()
runSourceConsumerGraphOracle =
  finishDiagnostics
    "SourceConsumerGraphOracle"
    ( sourceConsumerGraphSelectorRegistryProblems sourceConsumerGraphSelectorExactCases
        <> canonicalProblems
        <> identityProblems
        <> inventoryProblems
        <> roleProblems
        <> effectProblems
        <> resourceProblems
        <> opacityControlProblems
    )

runSourceConsumerGraphSelectorOracle :: String -> IO ()
runSourceConsumerGraphSelectorOracle selector =
  finishDiagnostics
    "SourceConsumerGraphOracle selector"
    ( sourceConsumerGraphSelectorRegistryProblems sourceConsumerGraphSelectorExactCases
        <> case selectorExactCases selector of
          [candidate] -> exactCaseProblems candidate
          candidates ->
            [ "selector intent is not exactly resolvable: selector="
                <> selector
                <> "; exact-case-count="
                <> show (length candidates)
            ]
        <> exactCaseProblems selectorUnaffectedControl
    )

runSourceConsumerGraphSelectorControlOracle :: IO ()
runSourceConsumerGraphSelectorControlOracle =
  finishDiagnostics
    "SourceConsumerGraphOracle selector control"
    ( sourceConsumerGraphSelectorRegistryProblems sourceConsumerGraphSelectorExactCases
        <> exactCaseProblems selectorUnaffectedControl
    )

sourceConsumerGraphSelectorNames :: [String]
sourceConsumerGraphSelectorNames = map fst sourceConsumerGraphSelectorIntents

selectorExactCases :: String -> [ExactCase]
selectorExactCases selector =
  [ candidate
  | target <- [label | (candidateSelector, label) <- sourceConsumerGraphSelectorIntents, candidateSelector == selector]
  , candidate@(ExactCase label _) <- sourceConsumerGraphSelectorExactCases
  , label == target
  ]

exactCaseProblems :: ExactCase -> [String]
exactCaseProblems (ExactCase _ problems) = problems

selectorUnaffectedControl :: ExactCase
selectorUnaffectedControl =
  ExactCase
    "public refusal remains unaffected"
    ( expectEqual
        "public refusal remains unaffected"
        False
        (checkPassed (diagnostic canonicalIdentity effectInventory [dynamicEffect]))
    )

sourceConsumerGraphSelectorRegistryProblems :: [ExactCase] -> [String]
sourceConsumerGraphSelectorRegistryProblems exactCases =
  concat
    [ expectEqual "literal selector registry cardinality" 476 (length sourceConsumerGraphSelectorIntents)
    , expectEqual "literal selector registry unique cardinality" 476 (Set.size selectorSet)
    , ["literal selector registry contains duplicate selector: " <> selector | selector <- duplicateValues selectors]
    , ["literal target declaration contains duplicate label: " <> label | label <- duplicateValues sourceConsumerGraphSelectorTargetLabels]
    , ["exact-case declaration contains duplicate label: " <> label | label <- duplicateValues exactLabels]
    , ["selector intent references unknown target: " <> selector <> " -> " <> label | (selector, label) <- sourceConsumerGraphSelectorIntents, Set.notMember label targetSet]
    , ["selector intent target lacks exactly one exact case: " <> selector <> " -> " <> label | (selector, label) <- sourceConsumerGraphSelectorIntents, length (filter (== label) exactLabels) /= 1]
    , ["declared exact target is unreferenced: " <> label | label <- sourceConsumerGraphSelectorTargetLabels, Set.notMember label referencedTargetSet]
    , ["exact case is not independently declared as a target: " <> label | label <- exactLabels, Set.notMember label targetSet]
    , ["declared target lacks exactly one exact case: " <> label | label <- sourceConsumerGraphSelectorTargetLabels, length (filter (== label) exactLabels) /= 1]
    ]
 where
  selectors = map fst sourceConsumerGraphSelectorIntents
  selectorSet = Set.fromList selectors
  targetSet = Set.fromList sourceConsumerGraphSelectorTargetLabels
  referencedTargetSet = Set.fromList (map snd sourceConsumerGraphSelectorIntents)
  exactLabels = [label | ExactCase label _ <- exactCases]

duplicateValues :: Ord value => [value] -> [value]
duplicateValues values =
  Set.toList
    (snd (foldl remember (Set.empty, Set.empty) values))
 where
  remember (seen, duplicates) value
    | Set.member value seen = (seen, Set.insert value duplicates)
    | otherwise = (Set.insert value seen, duplicates)

sourceConsumerGraphSelectorIntents :: [(String, String)]
sourceConsumerGraphSelectorIntents =
  [ ("VALIDATION_SOURCE_CONSUMER_ABSOLUTE_PATH_BYPASS_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_BUILD_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_ROOT_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_AMOEBIUS_ROOT_PATH_ALTERNATIVE_DROP_MUTANT", "exact amoebius root effect")
  , ("VALIDATION_SOURCE_CONSUMER_AUDIT_EFFECT_ORDER_MUTANT", "two effect problems retain order")
  , ("VALIDATION_SOURCE_CONSUMER_AUTHORIZED_CONSUMER_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_CONSUMERS_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_CONSUMER_SEPARATOR_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_LIMIT_WIDEN_MUTANT", "33 bindings bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_COUNT_PREDICATE_BYPASS_MUTANT", "33 bindings bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_LOOKUP_MATCH_DROP_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_PREFIX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_ROLE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_SEPARATOR_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_BINDING_ROLE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_BUILD_TOOL_CONSUMER_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PACKAGE_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_BUILD_CONSUMER_DROP_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_CONSUMERS_DROP_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROLE_BYPASS_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROOT_CONSUMER_DROP_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROOT_PATH_ALTERNATIVE_DROP_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_SOURCE_CONSUMER_DROP_MUTANT", "exact cabal-project root effect")
  , ("VALIDATION_SOURCE_CONSUMER_CALLS_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CALLS_RESOLVED_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CALLS_RESOLVED_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CARDINALITY_PROBLEM_ORDER_MUTANT", "two cardinality refusals retain order")
  , ("VALIDATION_SOURCE_CONSUMER_CARDINALITY_PROBLEM_ROUTE_BYPASS_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CLASSIFIED_BINDING_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CLASSIFIED_PROBLEM_ORDER_MUTANT", "two semantic problems retain order")
  , ("VALIDATION_SOURCE_CONSUMER_CLASSIFIED_SUBJECT_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CLASS_TAG_BYPASS_MUTANT", "unknown class exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CLASS_TAG_CODE_MAPPING_MUTANT", "unknown class exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CLASS_TAG_DETAIL_MAPPING_MUTANT", "unknown class exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CLASS_TAG_SUBJECT_MAPPING_MUTANT", "unknown class exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_INDEX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_PREFIX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_PARSE_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_PARSE_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_CODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_EXECUTION_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_EXECUTION_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDING_COUNT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECT_COUNT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_COUNT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_COUNT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_OBSERVATION_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_VALUE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONDITIONAL_PREPROCESSING_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONDITIONAL_PREPROCESSING_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONTAINER_CONTEXT_BUILDER_CONSUMER_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_BYPASS_MUTANT", "executable content exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_CODE_MAPPING_MUTANT", "executable content exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_DETAIL_MAPPING_MUTANT", "executable content exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_SUBJECT_MAPPING_MUTANT", "executable content exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_COPYING_STEM_ALTERNATIVE_DROP_MUTANT", "COPYING stem refusal")
  , ("VALIDATION_SOURCE_CONSUMER_CPP_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LOCAL_CAPTURE_RESIDUE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DECIMAL_SERIALIZER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_CODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_DETAIL_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_SUBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_CODE_MAPPING_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_DETAIL_MAPPING_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_SUBJECT_MAPPING_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DIRECT_PROBLEM_BINDING_PATH_MAPPING_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_BUILDER_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_BINDING_COUNT_ALTERNATIVE_DROP_MUTANT", "33 bindings bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_BINDING_ROLE_CONJUNCT_BYPASS_MUTANT", "documentation use against non-documentation role")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_CLASS_ALTERNATIVE_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_CONSUMERS_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_BINDING_CONJUNCT_BYPASS_MUTANT", "wrong documentation reader binding")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_MODULE_CONJUNCT_BYPASS_MUTANT", "wrong documentation reader module")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_PATH_CONJUNCT_BYPASS_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_ROLE_BYPASS_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_STRUCTURE_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_SUFFIX_BYPASS_MUTANT", "non-Markdown exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_USE_ALTERNATIVE_DROP_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_USE_USE_RENDER_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_DOTDOT_PATH_SEGMENT_BYPASS_MUTANT", "dotdot segment exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DOT_PATH_SEGMENT_BYPASS_MUTANT", "dot segment exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DUPLICATE_BYPASS_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DUPLICATE_CODE_MAPPING_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DUPLICATE_DETAIL_MAPPING_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DUPLICATE_SUBJECT_MAPPING_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_ALTERNATIVE_DROP_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_CODE_MAPPING_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_DETAIL_MAPPING_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_DETAIL_VALUE_MAPPING_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_SUBJECT_MAPPING_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_TOOL_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EDITOR_CONFIGURATION_ROLE_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EDITOR_TOOL_CONSUMER_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_BYPASS_MUTANT", "empty binding-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_CODE_MAPPING_MUTANT", "empty binding-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_DETAIL_MAPPING_MUTANT", "empty binding-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_SUBJECT_MAPPING_MUTANT", "empty binding-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_LIMIT_WIDEN_MUTANT", "65 effects bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_CARDINALITY_PREDICATE_BYPASS_MUTANT", "65 effects bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_BYPASS_MUTANT", "empty module-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_CODE_MAPPING_MUTANT", "empty module-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_DETAIL_MAPPING_MUTANT", "empty module-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_SUBJECT_MAPPING_MUTANT", "empty module-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_PATH_BYPASS_MUTANT", "unsafe effect-module path refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_BINDING_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_DROP_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_INDEX_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_KEY_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_MODULE_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_MODULE_PATH_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_PREFIX_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_FIVE_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_FOUR_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_ONE_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_THREE_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_TWO_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_TARGET_TAG_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_TARGET_VALUE_MAPPING_MUTANT", "256 three-byte UTF-8 field bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_USE_TAG_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_VALUE_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_PREFLIGHT_PROBLEM_ORDER_MUTANT", "target problem composition order")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_PREFLIGHT_ROUTE_BYPASS_MUTANT", "unknown target tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_CODE_MAPPING_MUTANT", "missing exact target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_DETAIL_MAPPING_MUTANT", "missing exact target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_PATH_BYPASS_MUTANT", "unsafe exact-target path refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_SUBJECT_MAPPING_MUTANT", "missing exact target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_BYPASS_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_CODE_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_DETAIL_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_SUBJECT_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_BYPASS_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_CODE_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_DETAIL_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_SUBJECT_MAPPING_MUTANT", "empty inventory exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EMPTY_PATH_SEGMENT_BYPASS_MUTANT", "empty segment exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_CLASS_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_INDEX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_MODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_OBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_PREFIX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_ONE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_THREE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_TWO_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_PREFLIGHT_PROBLEM_ORDER_MUTANT", "three field problems retain order")
  , ("VALIDATION_SOURCE_CONSUMER_ENTRY_PREFLIGHT_ROUTE_BYPASS_MUTANT", "unknown class exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_ALTERNATIVE_DROP_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_BYPASS_MUTANT", "missing exact target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_CODE_MAPPING_MUTANT", "unsafe exact-target path refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_DETAIL_MAPPING_MUTANT", "unsafe exact-target path refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_SUBJECT_MAPPING_MUTANT", "unsafe exact-target path refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_TAG_CONJUNCT_BYPASS_MUTANT", "unsafe dynamic target remains non-path")
  , ("VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_VALUE_PRESENT_CONJUNCT_BYPASS_MUTANT", "empty exact target value refusal")
  , ("VALIDATION_SOURCE_CONSUMER_EXECUTABLE_MODE_ALTERNATIVE_DROP_MUTANT", "other executable mode accepted")
  , ("VALIDATION_SOURCE_CONSUMER_EXTERNAL_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EXTERNAL_EFFECTS_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_EXTERNAL_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_FACADE_DIRECT_BEHAVIORAL_EFFECT_BYPASS_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_FACADE_DYNAMIC_TARGET_BYPASS_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_FACADE_ROLE_BEHAVIORAL_AUTHORIZATION_MUTANT", "documentation use against non-documentation role")
  , ("VALIDATION_SOURCE_CONSUMER_FIELD_LIMIT_WIDEN_MUTANT", "257 ASCII field bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_FIELD_PREDICATE_BYPASS_MUTANT", "257 ASCII field bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_FIELD_PROBLEM_ORDER_MUTANT", "three field problems retain order")
  , ("VALIDATION_SOURCE_CONSUMER_FIELD_PROBLEM_ROUTE_BYPASS_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_FILESYSTEM_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_FILESYSTEM_EFFECTS_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_FILESYSTEM_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_FINDING_LIMIT_NARROW_MUTANT", "32 problems and 46 findings exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CLIENT_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CONTRACT_ROLE_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITIGNORE_CLIENT_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITIGNORE_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITIGNORE_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GITIGNORE_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GIT_CLIENT_CONSUMER_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_GOVERNANCE_DOCUMENTATION_CONSUMER_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_GOVERNANCE_DOCUMENTATION_ROLE_RENDER_MAPPING_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_GOVERNANCE_HUMAN_CONSUMER_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_GOVERNANCE_SOURCE_CONSUMER_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_GRAPH_PROBLEM_ORDER_MUTANT", "two effect problems retain order")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_CLASS_ALTERNATIVE_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_COUNT_TAG_DROP_MUTANT", "33 Haskell subjects bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_LIMIT_WIDEN_MUTANT", "33 Haskell subjects bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_COUNT_PREDICATE_BYPASS_MUTANT", "33 Haskell subjects bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_BYPASS_MUTANT", "executable Haskell exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_CODE_MAPPING_MUTANT", "executable Haskell exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_DETAIL_MAPPING_MUTANT", "symlink Haskell exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_SUBJECT_MAPPING_MUTANT", "executable Haskell exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_HASKELL_PRESENCE_TAG_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_HUMAN_READER_CONSUMER_RENDER_MAPPING_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_IMPORTS_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_IMPORTS_RENAMED_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_IMPORTS_RENAMED_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_INDIRECT_CALLS_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_INDIRECT_CALLS_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_INDIRECT_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_LIMIT_WIDEN_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_CARDINALITY_PREDICATE_BYPASS_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_COMPARATOR_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_CODE_MAPPING_MUTANT", "reverse order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_DETAIL_MAPPING_MUTANT", "reverse order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_SUBJECT_MAPPING_MUTANT", "reverse order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_INVENTORY_PATH_BYPASS_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_CASE_NORMALIZATION_DROP_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_EXACT_MATCH_ALTERNATIVE_DROP_MUTANT", "legal exact-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_LAST_SEGMENT_DROP_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_BYPASS_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_CODE_MAPPING_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_DETAIL_MAPPING_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_SUBJECT_MAPPING_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LEGAL_SUFFIX_MATCH_ALTERNATIVE_DROP_MUTANT", "legal suffix refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LICENCE_STEM_ALTERNATIVE_DROP_MUTANT", "nested lowercase legal-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LICENSE_STEM_ALTERNATIVE_DROP_MUTANT", "legal exact-name refusal")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_VALUE_MUTANT", "32 bindings exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_VALUE_MUTANT", "64 effects exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_VALUE_MUTANT", "256 ASCII field bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_VALUE_MUTANT", "32 problems and 46 findings exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_VALUE_MUTANT", "32 Haskell subjects exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_VALUE_MUTANT", "64 inventory rows exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_OBSERVATION_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_VALUE_MUTANT", "1024 path bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_VALUE_MUTANT", "64 path segments exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_VALUE_MUTANT", "32 problems and 46 findings exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_VALUE_MUTANT", "218 observations exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_VALUE_MUTANT", "255 segment bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_MODE_TAG_BYPASS_MUTANT", "unknown mode exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_MODE_TAG_CODE_MAPPING_MUTANT", "unknown mode exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_MODE_TAG_DETAIL_MAPPING_MUTANT", "unknown mode exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_MODE_TAG_SUBJECT_MAPPING_MUTANT", "unknown mode exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_NOTICE_STEM_ALTERNATIVE_DROP_MUTANT", "legal suffix refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT", "mixed object alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_HEX_LETTER_ALTERNATIVE_DROP_MUTANT", "mixed object alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_ID_ALPHABET_BYPASS_MUTANT", "uppercase object exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_ID_CODE_MAPPING_MUTANT", "short object exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_ID_DETAIL_MAPPING_MUTANT", "short object exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_ID_SUBJECT_MAPPING_MUTANT", "short object exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_ID_WIDTH_BYPASS_MUTANT", "short object exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_SHA1_WIDTH_ALTERNATIVE_DROP_MUTANT", "mixed object alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_OBJECT_SHA256_WIDTH_ALTERNATIVE_DROP_MUTANT", "64-byte object accepted")
  , ("VALIDATION_SOURCE_CONSUMER_OBSERVATION_LIMIT_ROUTE_BYPASS_MUTANT", "219 observations bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OBSERVATION_LIMIT_WIDEN_MUTANT", "219 observations bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ORDER_BYPASS_MUTANT", "reverse order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_OTHER_CLASS_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_BINDING_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_MODULE_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_MODULE_PATH_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_BINDING_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_MODULE_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_SEPARATOR_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_TARGET_MAPPING_MUTANT", "256 four-byte UTF-8 field bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_USE_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_DOCUMENTATION_CLASS_DROP_MUTANT", "governance binding exact result")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_DOCUMENTATION_USE_DROP_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_DYNAMIC_TARGET_DROP_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_EXACT_TARGET_DROP_MUTANT", "missing exact target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_HASKELL_CLASS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_OTHER_CLASS_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_PRODUCT_USE_DROP_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_PROJECT_CLASS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_ROOT_USE_DROP_MUTANT", "wrong root reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_SOURCE_USE_DROP_MUTANT", "wrong source reader path")
  , ("VALIDATION_SOURCE_CONSUMER_PARSE_UNRESOLVED_TARGET_DROP_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_ALPHABET_BYPASS_MUTANT", "nonportable path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_BYTE_PREDICATE_BYPASS_MUTANT", "1025 path bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_DEPTH_PREDICATE_BYPASS_MUTANT", "65 path segments bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_DEPTH_LIMIT_WIDEN_MUTANT", "65 path segments bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_DIGIT_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_DOT_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_HYPHEN_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_LIMIT_WIDEN_MUTANT", "1025 path bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_LOWER_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_SHAPE_PROBLEM_ORDER_MUTANT", "path depth and segment refusals retain order")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_SHAPE_ROUTE_BYPASS_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_SEGMENT_PREDICATE_BYPASS_MUTANT", "256 segment bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PATH_UPPER_ALTERNATIVE_DROP_MUTANT", "complete portable path alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_PERMANENT_FINDING_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_POSIX_PATH_CODE_MAPPING_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_POSIX_PATH_DETAIL_MAPPING_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_POSIX_PATH_SUBJECT_MAPPING_MUTANT", "absolute path exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_DROP_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_KEY_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_VALUE_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECT_COUNT_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_COUNT_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_DROP_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_KEY_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_VALUE_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_OBSERVATION_ORDER_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_DROP_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_KEY_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_VALUE_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_WIDTH_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_BUILD_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_CONSUMERS_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_ROLE_BYPASS_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_SOURCE_CONSUMER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROBLEM_LIMIT_ROUTE_BYPASS_MUTANT", "33 problems bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PROBLEM_LIMIT_WIDEN_MUTANT", "33 problems bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PRODUCT_SINKS_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PRODUCT_SINKS_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PRODUCT_USE_ALTERNATIVE_DROP_MUTANT", "direct behaviour refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PROJECT_BINDING_COUNT_ALTERNATIVE_DROP_MUTANT", "33 project bindings bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_PROJECT_CLASS_ALTERNATIVE_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROVENANCE_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROVENANCE_FLOWS_FACT_IDENTITY_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_PROVENANCE_FLOWS_FACT_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_BINDING_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_MODULE_NAME_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_MODULE_PATH_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_TARGET_TAG_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_TARGET_VALUE_MAPPING_MUTANT", "256 two-byte UTF-8 field bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_USE_TAG_MAPPING_MUTANT", "exact documentation effect")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_CLASS_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_MODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_OBJECT_MAPPING_MUTANT", "64-byte object accepted")
  , ("VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_REGULAR_MODE_ALTERNATIVE_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_REPOSITORY_ROOT_LOCATOR_CONSUMER_RENDER_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_REQUIRED_FACT_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_CODE_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_LIMIT_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_NAME_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_OBSERVED_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESOURCE_SUBJECT_MAPPING_MUTANT", "65 inventory rows bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_FINDING_ORDER_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_NAME_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_OBSERVATION_CARRIER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_OBSERVATION_ORDER_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_PERMANENT_CARRIER_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_RESULT_PROBLEM_CARRIER_DROP_MUTANT", "dynamic target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_BYPASS_MUTANT", "non-Markdown exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_CODE_MAPPING_MUTANT", "non-Markdown exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_DETAIL_MAPPING_MUTANT", "non-Markdown exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_SUBJECT_MAPPING_MUTANT", "non-Markdown exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_ROOT_READER_BINDING_CONJUNCT_BYPASS_MUTANT", "wrong root reader binding")
  , ("VALIDATION_SOURCE_CONSUMER_ROOT_READER_MODULE_CONJUNCT_BYPASS_MUTANT", "wrong root reader module")
  , ("VALIDATION_SOURCE_CONSUMER_ROOT_READER_PATH_CONJUNCT_BYPASS_MUTANT", "wrong root reader path")
  , ("VALIDATION_SOURCE_CONSUMER_ROOT_SENTINEL_USE_USE_RENDER_MAPPING_MUTANT", "wrong root reader path")
  , ("VALIDATION_SOURCE_CONSUMER_ROOT_USE_ALTERNATIVE_DROP_MUTANT", "exact amoebius root effect")
  , ("VALIDATION_SOURCE_CONSUMER_SEGMENT_LIMIT_WIDEN_MUTANT", "256 segment bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SINKS_FACT_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_ALPHABET_BYPASS_MUTANT", "uppercase snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT", "mixed snapshot alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_HEX_LETTER_ALTERNATIVE_DROP_MUTANT", "mixed snapshot alphabet accepted")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_CODE_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_DETAIL_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_SUBJECT_MAPPING_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SNAPSHOT_WIDTH_BYPASS_MUTANT", "short snapshot exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_BOUNDARY_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT", "exact source-boundary effect")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_BOUNDARY_USE_USE_RENDER_MAPPING_MUTANT", "wrong source reader path")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_CODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_DETAIL_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_SUBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_READER_BINDING_CONJUNCT_BYPASS_MUTANT", "wrong source reader binding")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_READER_MODULE_CONJUNCT_BYPASS_MUTANT", "wrong source reader module")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_READER_PATH_CONJUNCT_BYPASS_MUTANT", "wrong source reader path")
  , ("VALIDATION_SOURCE_CONSUMER_SOURCE_USE_ALTERNATIVE_DROP_MUTANT", "exact source-boundary effect")
  , ("VALIDATION_SOURCE_CONSUMER_STRUCTURAL_PROBLEM_ORDER_MUTANT", "duplicate and order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_STRUCTURAL_PROBLEM_ROUTE_BYPASS_MUTANT", "reverse order exact refusal")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_MODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_DROP_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_KEY_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_MODE_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_OBJECT_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_PREFIX_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_SEPARATOR_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_VALUE_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SUBJECT_PATH_MAPPING_MUTANT", "canonical complete diagnostic")
  , ("VALIDATION_SOURCE_CONSUMER_SYMLINK_MODE_ALTERNATIVE_DROP_MUTANT", "other symlink mode accepted")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_PROBLEM_ORDER_MUTANT", "target problem composition order")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_TAG_BYPASS_MUTANT", "unknown target tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_TAG_CODE_MAPPING_MUTANT", "unknown target tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_TAG_DETAIL_MAPPING_MUTANT", "unknown target tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_TAG_SUBJECT_MAPPING_MUTANT", "unknown target tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_BYPASS_MUTANT", "empty target-value refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_CODE_MAPPING_MUTANT", "empty target-value refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_DETAIL_MAPPING_MUTANT", "empty target-value refusal")
  , ("VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_SUBJECT_MAPPING_MUTANT", "empty target-value refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_BYPASS_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_CODE_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_DETAIL_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_SUBJECT_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_PROBLEM_BINDING_PATH_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_PROBLEM_USE_MAPPING_MUTANT", "wrong documentation reader path")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_CODE_MAPPING_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_DETAIL_MAPPING_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_SUBJECT_MAPPING_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_ALTERNATIVE_DROP_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_BYPASS_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_DETAIL_VALUE_MAPPING_MUTANT", "unresolved target refusal")
  , ("VALIDATION_SOURCE_CONSUMER_USE_TAG_BYPASS_MUTANT", "unknown use tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_USE_TAG_CODE_MAPPING_MUTANT", "unknown use tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_USE_TAG_DETAIL_MAPPING_MUTANT", "unknown use tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_USE_TAG_SUBJECT_MAPPING_MUTANT", "unknown use tag refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UTF8_ASCII_WIDTH_MUTANT", "256 ASCII field bytes exact maximum")
  , ("VALIDATION_SOURCE_CONSUMER_UTF8_FOUR_BYTE_WIDTH_MUTANT", "257 four-byte UTF-8 field bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UTF8_THREE_BYTE_WIDTH_MUTANT", "257 three-byte UTF-8 field bytes bounded refusal")
  , ("VALIDATION_SOURCE_CONSUMER_UTF8_TWO_BYTE_WIDTH_MUTANT", "257 two-byte UTF-8 field bytes bounded refusal")
  ]

sourceConsumerGraphSelectorTargetLabels :: [String]
sourceConsumerGraphSelectorTargetLabels =
  [ "canonical complete diagnostic"
  , "short snapshot exact refusal"
  , "mixed snapshot alphabet accepted"
  , "uppercase snapshot exact refusal"
  , "unknown class exact refusal"
  , "unknown mode exact refusal"
  , "short object exact refusal"
  , "uppercase object exact refusal"
  , "mixed object alphabet accepted"
  , "64-byte object accepted"
  , "empty inventory exact refusal"
  , "duplicate and order exact refusal"
  , "reverse order exact refusal"
  , "absolute path exact refusal"
  , "empty segment exact refusal"
  , "dot segment exact refusal"
  , "dotdot segment exact refusal"
  , "nonportable path exact refusal"
  , "complete portable path alphabet accepted"
  , "other executable mode accepted"
  , "other symlink mode accepted"
  , "executable Haskell exact refusal"
  , "symlink Haskell exact refusal"
  , "governance binding exact result"
  , "legal exact-name refusal"
  , "COPYING stem refusal"
  , "legal suffix refusal"
  , "nested lowercase legal-name refusal"
  , "non-Markdown exact refusal"
  , "executable content exact refusal"
  , "exact documentation effect"
  , "exact source-boundary effect"
  , "exact amoebius root effect"
  , "exact cabal-project root effect"
  , "wrong documentation reader path"
  , "wrong documentation reader module"
  , "wrong documentation reader binding"
  , "wrong source reader path"
  , "wrong source reader module"
  , "wrong source reader binding"
  , "wrong root reader path"
  , "wrong root reader module"
  , "wrong root reader binding"
  , "documentation use against non-documentation role"
  , "missing exact target refusal"
  , "dynamic target refusal"
  , "unresolved target refusal"
  , "direct behaviour refusal"
  , "unknown target tag refusal"
  , "unknown use tag refusal"
  , "empty module-name refusal"
  , "empty binding-name refusal"
  , "empty target-value refusal"
  , "unsafe effect-module path refusal"
  , "unsafe exact-target path refusal"
  , "unsafe dynamic target remains non-path"
  , "empty exact target value refusal"
  , "target problem composition order"
  , "two semantic problems retain order"
  , "two effect problems retain order"
  , "64 inventory rows exact maximum"
  , "65 inventory rows bounded refusal"
  , "64 effects exact maximum"
  , "65 effects bounded refusal"
  , "32 bindings exact maximum"
  , "33 bindings bounded refusal"
  , "33 project bindings bounded refusal"
  , "32 Haskell subjects exact maximum"
  , "33 Haskell subjects bounded refusal"
  , "1024 path bytes exact maximum"
  , "1025 path bytes bounded refusal"
  , "64 path segments exact maximum"
  , "65 path segments bounded refusal"
  , "255 segment bytes exact maximum"
  , "256 segment bytes bounded refusal"
  , "256 ASCII field bytes exact maximum"
  , "257 ASCII field bytes bounded refusal"
  , "256 two-byte UTF-8 field bytes exact maximum"
  , "257 two-byte UTF-8 field bytes bounded refusal"
  , "256 three-byte UTF-8 field bytes exact maximum"
  , "257 three-byte UTF-8 field bytes bounded refusal"
  , "256 four-byte UTF-8 field bytes exact maximum"
  , "257 four-byte UTF-8 field bytes bounded refusal"
  , "32 problems and 46 findings exact maximum"
  , "33 problems bounded refusal"
  , "218 observations exact maximum"
  , "219 observations bounded refusal"
  , "two cardinality refusals retain order"
  , "three field problems retain order"
  , "path depth and segment refusals retain order"
  ]

sourceConsumerGraphSelectorExactCases :: [ExactCase]
sourceConsumerGraphSelectorExactCases =
  [ namedExact
      "canonical complete diagnostic"
      (completeExpected canonicalIdentityExpected 10 0 8 2 canonicalEntryObservations [] canonicalBindingObservations canonicalSubjectObservations [])
      (diagnostic canonicalIdentity canonicalInventory [])
  , namedPreflight "short snapshot exact refusal" 3 10 0 "abc" canonicalInventory []
      [localFinding "SRC-CONSUMER-SNAPSHOT-IDENTITY" "snapshot-identity" "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"]
  , namedExact
      "mixed snapshot alphabet accepted"
      (completeExpected mixedIdentityExpected 10 0 8 2 canonicalEntryObservations [] canonicalBindingObservations canonicalSubjectObservations [])
      (diagnostic mixedIdentity canonicalInventory [])
  , namedPreflight "uppercase snapshot exact refusal" 64 10 0 uppercaseIdentity canonicalInventory []
      [localFinding "SRC-CONSUMER-SNAPSHOT-IDENTITY" "snapshot-identity" "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"]
  , namedPreflight "unknown class exact refusal" 64 1 0 canonicalIdentity [entry "src/A.hs" "invented" regular objectA] []
      [localFinding "SRC-CONSUMER-CLASS-TAG" "src/A.hs" "class tag must be haskell, documentation, project-declaration, or other"]
  , namedPreflight "unknown mode exact refusal" 64 1 0 canonicalIdentity [entry "src/A.hs" "haskell" "100600" objectA] []
      [localFinding "SRC-CONSUMER-MODE-TAG" "src/A.hs" "Git mode must be exactly 100644, 100755, or 120000"]
  , namedPreflight "short object exact refusal" 64 1 0 canonicalIdentity [entry "src/A.hs" "haskell" regular "abc"] []
      [localFinding "SRC-CONSUMER-OBJECT-ID" "src/A.hs" "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"]
  , namedPreflight "uppercase object exact refusal" 64 1 0 canonicalIdentity [entry "src/A.hs" "haskell" regular uppercaseObject] []
      [localFinding "SRC-CONSUMER-OBJECT-ID" "src/A.hs" "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"]
  , acceptedSingleHaskell "mixed object alphabet accepted" mixedObject mixedObjectExpected
  , acceptedSingleHaskell "64-byte object accepted" object64 object64Expected
  , namedPreflight "empty inventory exact refusal" 64 0 0 canonicalIdentity [] []
      [ localFinding "SRC-CONSUMER-EMPTY-INVENTORY" "inventory" "tracked inventory must be nonempty"
      , localFinding "SRC-CONSUMER-EMPTY-HASKELL" "inventory" "compiler residue cannot close over an empty Haskell subject inventory"
      ]
  , namedPreflight "duplicate and order exact refusal" 64 2 0 canonicalIdentity duplicateInventory []
      [ localFinding "SRC-CONSUMER-DUPLICATE" "src/A.hs" "tracked inventory path occurs more than once"
      , localFinding "SRC-CONSUMER-INVENTORY-ORDER" "inventory" "tracked inventory paths must be strictly increasing before semantic analysis"
      ]
  , namedPreflight "reverse order exact refusal" 64 2 0 canonicalIdentity reverseInventory []
      [localFinding "SRC-CONSUMER-INVENTORY-ORDER" "inventory" "tracked inventory paths must be strictly increasing before semantic analysis"]
  , pathRefusalCase "absolute path exact refusal" "/src/A.hs"
  , pathRefusalCase "empty segment exact refusal" "src//A.hs"
  , pathRefusalCase "dot segment exact refusal" "src/./A.hs"
  , pathRefusalCase "dotdot segment exact refusal" "src/../A.hs"
  , pathRefusalCase "nonportable path exact refusal" "src/A B.hs"
  , acceptedOtherCase "complete portable path alphabet accepted" portableAlphabetPath regular portableAlphabetPath
  , acceptedOtherCase "other executable mode accepted" "a-other" executable "a-other"
  , acceptedOtherCase "other symlink mode accepted" "a-other" symlinkMode "a-other"
  , haskellModeCase "executable Haskell exact refusal" executable "100755"
  , haskellModeCase "symlink Haskell exact refusal" symlinkMode "120000"
  , ExactCase "governance binding exact result" (exactSingleBinding "governance binding exact result" governanceEntry governanceEntryObservation governanceBindingObservation)
  , legalRefusalCase "legal exact-name refusal" "LICENSE"
  , legalRefusalCase "COPYING stem refusal" "COPYING"
  , legalRefusalCase "legal suffix refusal" "NOTICE.extra.md"
  , legalRefusalCase "nested lowercase legal-name refusal" "docs/licence.md"
  , roleUnboundCase "non-Markdown exact refusal" "README.txt" "documentation"
  , contentModeCase "executable content exact refusal"
  , exactEffectCase "exact documentation effect" documentationEffect documentationEffectObservation []
  , exactEffectCase "exact source-boundary effect" sourceBoundaryEffect sourceBoundaryEffectObservation []
  , exactEffectCase "exact amoebius root effect" rootEffect rootEffectObservation []
  , exactCabalProjectRootEffectCase
  , wrongDocumentationReaderCase "wrong documentation reader path" "src/Wrong.hs" "Amoebius.Validation.Documentation" "readDocument"
  , wrongDocumentationReaderCase "wrong documentation reader module" "src/validation-kernel/Amoebius/Validation/Documentation.hs" "Wrong" "readDocument"
  , wrongDocumentationReaderCase "wrong documentation reader binding" "src/validation-kernel/Amoebius/Validation/Documentation.hs" "Amoebius.Validation.Documentation" "wrong"
  , wrongSourceReaderCase "wrong source reader path" "src/Wrong.hs" "Amoebius.Validation.SourceClosure.Internal" "classifyEntry"
  , wrongSourceReaderCase "wrong source reader module" "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs" "Wrong" "classifyEntry"
  , wrongSourceReaderCase "wrong source reader binding" "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs" "Amoebius.Validation.SourceClosure.Internal" "wrong"
  , wrongRootReaderCase "wrong root reader path" "src/Wrong.hs" "Amoebius.Validation.Dispatch" "discoverRepositoryRoot"
  , wrongRootReaderCase "wrong root reader module" "src/validation-kernel/Amoebius/Validation/Dispatch.hs" "Wrong" "discoverRepositoryRoot"
  , wrongRootReaderCase "wrong root reader binding" "src/validation-kernel/Amoebius/Validation/Dispatch.hs" "Amoebius.Validation.Dispatch" "wrong"
  , documentationRoleMismatchCase
  , exactEffectCase "missing exact target refusal" missingEffect missingEffectObservation
      [localFinding "SRC-CONSUMER-EFFECT-TARGET" "missing.md" "resolved effect target has no admitted non-source content binding"]
  , exactEffectCase "dynamic target refusal" dynamicEffect dynamicEffectObservation
      [localFinding "SRC-CONSUMER-DYNAMIC-TARGET" "src/A.hs" "dynamic effect target may alias tracked content: computed-path"]
  , exactEffectCase "unresolved target refusal" unresolvedEffect unresolvedEffectObservation
      [localFinding "SRC-CONSUMER-UNRESOLVED-EFFECT" "src/A.hs" "compiler effect target did not resolve: renamer-gap"]
  , exactEffectCase "direct behaviour refusal" directEffect directEffectObservation
      [localFinding "SRC-CONSUMER-DIRECT-BEHAVIOUR" "src/A.hs" "resolved consumer A.read treats README.md as product behaviour"]
  , targetPreflightCase "unknown target tag refusal" "invented" "README.md" "documentation-structure"
      [localFinding "SRC-CONSUMER-TARGET-TAG" "src/A.hs" "effect target tag must be exact, dynamic, or unresolved"]
  , targetPreflightCase "unknown use tag refusal" "exact" "README.md" "invented-use"
      [localFinding "SRC-CONSUMER-USE-TAG" "src/A.hs" "effect use tag is outside the closed diagnostic vocabulary"]
  , identityPreflightCase "empty module-name refusal" "" "read"
      [localFinding "SRC-CONSUMER-EFFECT-MODULE" "src/A.hs" "effect module name must be nonempty"]
  , identityPreflightCase "empty binding-name refusal" "A" ""
      [localFinding "SRC-CONSUMER-EFFECT-MODULE" "src/A.hs" "effect binding name must be nonempty"]
  , targetPreflightCase "empty target-value refusal" "dynamic" "" "documentation-structure"
      [localFinding "SRC-CONSUMER-TARGET-VALUE" "src/A.hs" "effect target value must be nonempty"]
  , unsafeEffectModuleCase
  , unsafeExactTargetCase
  , unsafeDynamicTargetCase
  , targetPreflightCase "empty exact target value refusal" "exact" "" "documentation-structure"
      [localFinding "SRC-CONSUMER-TARGET-VALUE" "src/A.hs" "effect target value must be nonempty"]
  , targetPreflightCase "target problem composition order" "invented" "" "documentation-structure"
      [ localFinding "SRC-CONSUMER-TARGET-TAG" "src/A.hs" "effect target tag must be exact, dynamic, or unresolved"
      , localFinding "SRC-CONSUMER-TARGET-VALUE" "src/A.hs" "effect target value must be nonempty"
      ]
  , twoSemanticProblemsCase
  , twoEffectProblemsCase
  , namedExact "64 inventory rows exact maximum" (completeExpected canonicalIdentityExpected 64 0 0 32 inventoryEntryObservations64 [] [] haskellObservations32 []) (diagnostic canonicalIdentity inventory64 [])
  , namedPreflight "65 inventory rows bounded refusal" 64 65 0 canonicalIdentity inventory65 [] [resourceFinding "inventory-entries" 64 65]
  , namedExact "64 effects exact maximum" (completeExpected canonicalIdentityExpected 3 64 2 1 effectEntryObservations effectObservations64 effectBindingObservations effectSubjectObservations []) (diagnostic canonicalIdentity effectInventory effects64)
  , namedPreflight "65 effects bounded refusal" 64 3 65 canonicalIdentity effectInventory effects65 [resourceFinding "resolved-effects" 64 65]
  , namedExact "32 bindings exact maximum" (completeExpected canonicalIdentityExpected 33 0 32 1 bindingEntryObservations32 [] bindingObservations32 oneControlSubject []) (diagnostic canonicalIdentity bindingInventory32 [])
  , namedPreflight "33 bindings bounded refusal" 64 34 0 canonicalIdentity bindingInventory33 [] [resourceFinding "content-bindings" 32 33]
  , namedPreflight "33 project bindings bounded refusal" 64 34 0 canonicalIdentity projectBindingInventory33 [] [resourceFinding "content-bindings" 32 33]
  , namedExact "32 Haskell subjects exact maximum" (completeExpected canonicalIdentityExpected 32 0 0 32 haskellEntryObservations32 [] [] haskellObservations32 []) (diagnostic canonicalIdentity haskellInventory32 [])
  , namedPreflight "33 Haskell subjects bounded refusal" 64 33 0 canonicalIdentity haskellInventory33 [] [resourceFinding "haskell-subjects" 32 33]
  , pathBoundaryCase "1024 path bytes exact maximum" path1024 path1024Expected
  , namedPreflight "1025 path bytes bounded refusal" 64 2 0 canonicalIdentity (boundedOtherInventory path1025) [] [resourceFinding "inventory-path-bytes" 1024 1025]
  , pathBoundaryCase "64 path segments exact maximum" depth64 depth64Expected
  , namedPreflight "65 path segments bounded refusal" 64 2 0 canonicalIdentity (boundedOtherInventory depth65) [] [resourceFinding "inventory-path-depth" 64 65]
  , pathBoundaryCase "255 segment bytes exact maximum" segment255 segment255Expected
  , namedPreflight "256 segment bytes bounded refusal" 64 2 0 canonicalIdentity (boundedOtherInventory segment256) [] [resourceFinding "inventory-path-segment-bytes" 255 256]
  , fieldBoundaryCase "256 ASCII field bytes exact maximum" field256 field256Expected
  , namedPreflight "257 ASCII field bytes bounded refusal" 64 3 1 canonicalIdentity effectInventory [fieldEffect field257] [resourceFinding "effect-target-value-bytes" 256 257]
  , fieldBoundaryCase "256 two-byte UTF-8 field bytes exact maximum" fieldTwoByte256 fieldTwoByte256Expected
  , namedPreflight "257 two-byte UTF-8 field bytes bounded refusal" 64 3 1 canonicalIdentity effectInventory [fieldEffect fieldTwoByte257] [resourceFinding "effect-target-value-bytes" 256 257]
  , fieldBoundaryCase "256 three-byte UTF-8 field bytes exact maximum" fieldThreeByte256 fieldThreeByte256Expected
  , namedPreflight "257 three-byte UTF-8 field bytes bounded refusal" 64 3 1 canonicalIdentity effectInventory [fieldEffect fieldThreeByte257] [resourceFinding "effect-target-value-bytes" 256 257]
  , fieldBoundaryCase "256 four-byte UTF-8 field bytes exact maximum" fieldFourByte256 fieldFourByte256Expected
  , namedPreflight "257 four-byte UTF-8 field bytes bounded refusal" 64 3 1 canonicalIdentity effectInventory [fieldEffect fieldFourByte257] [resourceFinding "effect-target-value-bytes" 256 257]
  , namedExact "32 problems and 46 findings exact maximum" (preflightExpected 64 11 0 invalidFindings32) (diagnostic canonicalIdentity invalidRows32 [])
  , namedExact "33 problems bounded refusal" (preflightExpected 64 11 0 [resourceFinding "diagnostic-problems" 32 33]) (diagnostic canonicalIdentity invalidRows33 [])
  , namedExact "218 observations exact maximum" (CheckResult diagnosticName observationBoundaryExpected permanentFindings) (diagnostic canonicalIdentity observationInventory observationEffects62)
  , namedExact "219 observations bounded refusal" (preflightExpected 64 64 63 [resourceFinding "result-observations" 218 219]) (diagnostic canonicalIdentity observationInventory observationEffects63)
  , namedPreflight "two cardinality refusals retain order" 64 65 65 canonicalIdentity inventory65 effects65 [resourceFinding "inventory-entries" 64 65, resourceFinding "resolved-effects" 64 65]
  , namedPreflight "three field problems retain order" 64 1 0 canonicalIdentity [entry "src/A.hs" "invented" "100600" "abc"] [] (invalidTriple "src/A.hs")
  , pathShapeOrderCase
  ]

namedExact :: String -> CheckResult -> CheckResult -> ExactCase
namedExact label expected actual = ExactCase label (expectExact label expected actual)

namedPreflight :: String -> Int -> Int -> Int -> Text -> [EntryWire] -> [EffectWire] -> [Finding] -> ExactCase
namedPreflight label identityCharacters inventoryCount effectCount identity inventory effects problems =
  namedExact label (preflightExpected identityCharacters inventoryCount effectCount problems) (diagnostic identity inventory effects)

acceptedSingleHaskell :: String -> Text -> Text -> ExactCase
acceptedSingleHaskell label objectId expectedObjectId =
  namedExact
    label
    ( completeExpected
        canonicalIdentityExpected
        1
        0
        0
        1
        [entryObservation 0 ("src/A.hs", "haskell", "100644", expectedObjectId)]
        []
        []
        [Observation "source-consumer.haskell.src/A.hs" ("100644\t" <> expectedObjectId)]
        []
    )
    (diagnostic canonicalIdentity [entry "src/A.hs" "haskell" regular objectId] [])

pathRefusalCase :: String -> FilePath -> ExactCase
pathRefusalCase label path =
  namedPreflight
    label
    64
    1
    0
    canonicalIdentity
    [entry path "haskell" regular objectA]
    []
    [ localFinding
        "SRC-CONSUMER-POSIX-PATH"
        "inventory-path"
        "path must be a nonempty safe relative POSIX path"
    ]

acceptedOtherCase :: String -> FilePath -> Text -> FilePath -> ExactCase
acceptedOtherCase label path mode expectedPath =
  namedExact
    label
    ( completeExpected
        canonicalIdentityExpected
        2
        0
        0
        1
        [ entryObservation 0 (expectedPath, "other", mode, objectAExpected)
        , controlEntryObservationAt1
        ]
        []
        []
        oneControlSubject
        []
    )
    (diagnostic canonicalIdentity [entry path "other" mode objectA, controlEntry] [])

haskellModeCase :: String -> Text -> Text -> ExactCase
haskellModeCase label mode expectedMode =
  namedExact
    label
    ( completeExpected
        canonicalIdentityExpected
        1
        0
        0
        1
        [entryObservation 0 ("src/A.hs", "haskell", expectedMode, objectAExpected)]
        []
        []
        [Observation "source-consumer.haskell.src/A.hs" (expectedMode <> "\t" <> objectAExpected)]
        [ localFinding
            "SRC-CONSUMER-HASKELL-MODE"
            "src/A.hs"
            "every Haskell compiler subject must be a regular non-executable blob"
        ]
    )
    (diagnostic canonicalIdentity [entry "src/A.hs" "haskell" mode objectA] [])

legalRefusalCase :: String -> FilePath -> ExactCase
legalRefusalCase label path =
  ExactCase
    label
    ( exactRoleRefusal
        label
        (entry path "documentation" regular objectA)
        (entryObservation 0 (path, "documentation", "100644", objectAExpected))
        ( localFinding
            "SRC-CONSUMER-LEGAL-NAME"
            path
            "LICENSE, LICENCE, COPYING, and NOTICE stems have no machine-owned semantic role"
        )
    )

roleUnboundCase :: String -> FilePath -> Text -> ExactCase
roleUnboundCase label path classTag =
  ExactCase
    label
    ( exactRoleRefusal
        label
        (entry path classTag regular objectA)
        (entryObservation 0 (path, classTag, "100644", objectAExpected))
        ( localFinding
            "SRC-CONSUMER-ROLE-UNBOUND"
            path
            "no exact closed content role exists for this admitted class and path"
        )
    )

contentModeCase :: String -> ExactCase
contentModeCase label =
  ExactCase
    label
    ( exactRoleRefusal
        label
        (entry "README.md" "documentation" executable objectA)
        (entryObservation 0 ("README.md", "documentation", "100755", objectAExpected))
        ( localFinding
            "SRC-CONSUMER-CONTENT-MODE"
            "README.md"
            "admitted non-source content must be a regular non-executable blob"
        )
    )

exactEffectCase :: String -> EffectWire -> Observation -> [Finding] -> ExactCase
exactEffectCase label observedEffect expectedEffect problems =
  ExactCase label (exactEffect label observedEffect expectedEffect problems)

exactCabalProjectRootEffectCase :: ExactCase
exactCabalProjectRootEffectCase =
  namedExact
    "exact cabal-project root effect"
    ( completeExpected
        canonicalIdentityExpected
        2
        1
        1
        1
        [ entryObservation 0 ("cabal.project", "project-declaration", "100644", objectAExpected)
        , controlEntryObservationAt1
        ]
        [cabalProjectRootEffectObservation]
        [ binding
            "cabal.project"
            "CabalProjectDescription"
            "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool"
        ]
        oneControlSubject
        []
    )
    ( diagnostic
        canonicalIdentity
        [entry "cabal.project" "project-declaration" regular objectA, controlEntry]
        [cabalProjectRootEffect]
    )

wrongDocumentationReaderCase :: String -> FilePath -> Text -> Text -> ExactCase
wrongDocumentationReaderCase label modulePath moduleName bindingName =
  exactEffectCase label observed (effectObservation 0 observed)
    [unauthorized modulePath (moduleName <> "." <> bindingName) "README.md" "StructuralDocumentationInspection"]
 where
  observed = effect modulePath moduleName bindingName "exact" "README.md" "documentation-structure"

wrongSourceReaderCase :: String -> FilePath -> Text -> Text -> ExactCase
wrongSourceReaderCase label modulePath moduleName bindingName =
  exactEffectCase label observed (effectObservation 0 observed)
    [unauthorized modulePath (moduleName <> "." <> bindingName) "README.md" "SourceBoundaryStructureInspection"]
 where
  observed = effect modulePath moduleName bindingName "exact" "README.md" "source-boundary-structure"

wrongRootReaderCase :: String -> FilePath -> Text -> Text -> ExactCase
wrongRootReaderCase label modulePath moduleName bindingName =
  exactEffectCase label observed (effectObservation 0 observed)
    [unauthorized modulePath (moduleName <> "." <> bindingName) "amoebius.cabal" "RepositoryRootSentinel"]
 where
  observed = effect modulePath moduleName bindingName "exact" "amoebius.cabal" "repository-root-sentinel"

documentationRoleMismatchCase :: ExactCase
documentationRoleMismatchCase =
  exactEffectCase
    "documentation use against non-documentation role"
    observed
    (effectObservation 0 observed)
    [ unauthorized
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        "Amoebius.Validation.Documentation.readDocument"
        "amoebius.cabal"
        "StructuralDocumentationInspection"
    ]
 where
  observed =
    effect
      "src/validation-kernel/Amoebius/Validation/Documentation.hs"
      "Amoebius.Validation.Documentation"
      "readDocument"
      "exact"
      "amoebius.cabal"
      "documentation-structure"

targetPreflightCase :: String -> Text -> Text -> Text -> [Finding] -> ExactCase
targetPreflightCase label targetTag targetValue useTag problems =
  namedPreflight
    label
    64
    3
    1
    canonicalIdentity
    effectInventory
    [effect "src/A.hs" "A" "read" targetTag targetValue useTag]
    problems

identityPreflightCase :: String -> Text -> Text -> [Finding] -> ExactCase
identityPreflightCase label moduleName bindingName problems =
  namedPreflight
    label
    64
    3
    1
    canonicalIdentity
    effectInventory
    [effect "src/A.hs" moduleName bindingName "exact" "README.md" "documentation-structure"]
    problems

unsafeEffectModuleCase :: ExactCase
unsafeEffectModuleCase =
  namedPreflight
    "unsafe effect-module path refusal"
    64
    3
    1
    canonicalIdentity
    effectInventory
    [effect "/src/A.hs" "A" "read" "dynamic" "computed-path" "documentation-structure"]
    [localFinding "SRC-CONSUMER-POSIX-PATH" "effect-module-path" "path must be a nonempty safe relative POSIX path"]

unsafeExactTargetCase :: ExactCase
unsafeExactTargetCase =
  namedPreflight
    "unsafe exact-target path refusal"
    64
    3
    1
    canonicalIdentity
    effectInventory
    [effect "src/A.hs" "A" "read" "exact" "../README.md" "documentation-structure"]
    [localFinding "SRC-CONSUMER-POSIX-PATH" "effect-target-path" "exact effect target must be a safe relative POSIX path"]

unsafeDynamicTargetCase :: ExactCase
unsafeDynamicTargetCase =
  exactEffectCase
    "unsafe dynamic target remains non-path"
    observed
    (effectObservation 0 observed)
    [ localFinding
        "SRC-CONSUMER-DYNAMIC-TARGET"
        "src/A.hs"
        "dynamic effect target may alias tracked content: ../computed"
    ]
 where
  observed = effect "src/A.hs" "A" "read" "dynamic" "../computed" "documentation-structure"

twoSemanticProblemsCase :: ExactCase
twoSemanticProblemsCase =
  namedExact
    "two semantic problems retain order"
    ( completeExpected
        canonicalIdentityExpected
        3
        0
        0
        1
        [ entryObservation 0 ("LICENSE.md", "documentation", "100644", objectAExpected)
        , entryObservation 1 ("README.txt", "documentation", "100644", objectAExpected)
        , entryObservation 2 ("zz/Control.hs", "haskell", "100644", objectBExpected)
        ]
        []
        []
        oneControlSubject
        [ localFinding "SRC-CONSUMER-LEGAL-NAME" "LICENSE.md" "LICENSE, LICENCE, COPYING, and NOTICE stems have no machine-owned semantic role"
        , localFinding "SRC-CONSUMER-ROLE-UNBOUND" "README.txt" "no exact closed content role exists for this admitted class and path"
        ]
    )
    ( diagnostic
        canonicalIdentity
        [ entry "LICENSE.md" "documentation" regular objectA
        , entry "README.txt" "documentation" regular objectA
        , controlEntry
        ]
        []
    )

twoEffectProblemsCase :: ExactCase
twoEffectProblemsCase =
  namedExact
    "two effect problems retain order"
    ( completeExpected
        canonicalIdentityExpected
        3
        2
        2
        1
        effectEntryObservations
        [dynamicEffectObservation, unresolvedEffectObservation]
        effectBindingObservations
        effectSubjectObservations
        [ localFinding "SRC-CONSUMER-DYNAMIC-TARGET" "src/A.hs" "dynamic effect target may alias tracked content: computed-path"
        , localFinding "SRC-CONSUMER-UNRESOLVED-EFFECT" "src/A.hs" "compiler effect target did not resolve: renamer-gap"
        ]
    )
    (diagnostic canonicalIdentity effectInventory [dynamicEffect, unresolvedEffect])

pathBoundaryCase :: String -> FilePath -> FilePath -> ExactCase
pathBoundaryCase label path expectedPath =
  namedExact
    label
    ( completeExpected
        canonicalIdentityExpected
        2
        0
        0
        1
        [entryObservation 0 (expectedPath, "other", "100644", objectAExpected), controlEntryObservationAt1]
        []
        []
        oneControlSubject
        []
    )
    (diagnostic canonicalIdentity (boundedOtherInventory path) [])

fieldBoundaryCase :: String -> Text -> Text -> ExactCase
fieldBoundaryCase label value expectedValue =
  namedExact
    label
    ( completeExpected
        canonicalIdentityExpected
        3
        1
        2
        1
        effectEntryObservations
        [effectObservation 0 ("src/A.hs", "A", "read", "dynamic", expectedValue, "documentation-structure")]
        effectBindingObservations
        effectSubjectObservations
        [ localFinding
            "SRC-CONSUMER-DYNAMIC-TARGET"
            "src/A.hs"
            ("dynamic effect target may alias tracked content: " <> expectedValue)
        ]
    )
    (diagnostic canonicalIdentity effectInventory [fieldEffect value])

pathShapeOrderCase :: ExactCase
pathShapeOrderCase =
  namedPreflight
    "path depth and segment refusals retain order"
    64
    2
    0
    canonicalIdentity
    (boundedOtherInventory pathDepthAndSegment)
    []
    [ resourceFinding "inventory-path-depth" 64 65
    , resourceFinding "inventory-path-segment-bytes" 255 256
    ]
 where
  pathDepthAndSegment = intercalateSlash (Text.unpack (Text.replicate 256 "s") : replicate 64 "a")

canonicalProblems :: [String]
canonicalProblems =
  expectExact
    "the complete local role universe remains an exact permanent refusal"
    ( completeExpected
        canonicalIdentityExpected
        10
        0
        8
        2
        canonicalEntryObservations
        []
        canonicalBindingObservations
        canonicalSubjectObservations
        []
    )
    (diagnostic canonicalIdentity canonicalInventory [])
    <> expectEqual
      "an empty caller effect list never closes permanent residue"
      False
      (checkPassed (diagnostic canonicalIdentity canonicalInventory []))

identityProblems :: [String]
identityProblems =
  concat
    [ exactPreflight
        "short snapshot identity"
        3 10 0
        "abc"
        canonicalInventory
        []
        [ localFinding "SRC-CONSUMER-SNAPSHOT-IDENTITY" "snapshot-identity"
            "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"
        ]
    , exactPreflight
        "uppercase snapshot identity"
        64 10 0
        uppercaseIdentity
        canonicalInventory
        []
        [ localFinding "SRC-CONSUMER-SNAPSHOT-IDENTITY" "snapshot-identity"
            "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"
        ]
    , exactPreflight
        "unknown class tag"
        64 1 0
        canonicalIdentity
        [entry "src/A.hs" "invented" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-CLASS-TAG" "src/A.hs"
            "class tag must be haskell, documentation, project-declaration, or other"
        ]
    , exactPreflight
        "unknown Git mode"
        64 1 0
        canonicalIdentity
        [entry "src/A.hs" "haskell" "100600" objectA]
        []
        [ localFinding "SRC-CONSUMER-MODE-TAG" "src/A.hs"
            "Git mode must be exactly 100644, 100755, or 120000"
        ]
    , exactPreflight
        "malformed object id"
        64 1 0
        canonicalIdentity
        [entry "src/A.hs" "haskell" regular "abc"]
        []
        [ localFinding "SRC-CONSUMER-OBJECT-ID" "src/A.hs"
            "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
        ]
    , exactPreflight
        "non-lowercase object id"
        64 1 0
        canonicalIdentity
        [entry "src/A.hs" "haskell" regular uppercaseObject]
        []
        [ localFinding "SRC-CONSUMER-OBJECT-ID" "src/A.hs"
            "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
        ]
    , expectExact
        "a 64-character lowercase object id is admitted and bound literally"
        ( completeExpected canonicalIdentityExpected 1 0 0 1
            [entryObservation 0 ("src/A.hs", "haskell", "100644", object64Expected)]
            [] [] [Observation "source-consumer.haskell.src/A.hs" ("100644\t" <> object64Expected)] []
        )
        (diagnostic canonicalIdentity [entry "src/A.hs" "haskell" regular object64] [])
    ]

inventoryProblems :: [String]
inventoryProblems =
  concat
    [ exactPreflight
        "empty tracked inventory"
        64 0 0
        canonicalIdentity
        []
        []
        [ localFinding "SRC-CONSUMER-EMPTY-INVENTORY" "inventory"
            "tracked inventory must be nonempty"
        , localFinding "SRC-CONSUMER-EMPTY-HASKELL" "inventory"
            "compiler residue cannot close over an empty Haskell subject inventory"
        ]
    , exactPreflight
        "nonempty inventory without Haskell"
        64 1 0
        canonicalIdentity
        [entry "README.md" "documentation" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-EMPTY-HASKELL" "inventory"
            "compiler residue cannot close over an empty Haskell subject inventory"
        ]
    , exactPreflight
        "duplicate path and order"
        64 2 0
        canonicalIdentity
        [ entry "src/A.hs" "haskell" regular objectA
        , entry "src/A.hs" "haskell" regular objectB
        ]
        []
        [ localFinding "SRC-CONSUMER-DUPLICATE" "src/A.hs"
            "tracked inventory path occurs more than once"
        , localFinding "SRC-CONSUMER-INVENTORY-ORDER" "inventory"
            "tracked inventory paths must be strictly increasing before semantic analysis"
        ]
    , exactPreflight
        "reverse inventory order"
        64 2 0
        canonicalIdentity
        [ entry "src/B.hs" "haskell" regular objectB
        , entry "src/A.hs" "haskell" regular objectA
        ]
        []
        [ localFinding "SRC-CONSUMER-INVENTORY-ORDER" "inventory"
            "tracked inventory paths must be strictly increasing before semantic analysis"
        ]
    , exactPreflight
        "absolute POSIX path"
        64 1 0
        canonicalIdentity
        [entry "/src/A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "backslash-shaped path"
        64 1 0
        canonicalIdentity
        [entry "src\\A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "colon-shaped path"
        64 1 0
        canonicalIdentity
        [entry "src:A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "empty path"
        64 1 0
        canonicalIdentity
        [entry "" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "empty interior path segment"
        64 1 0
        canonicalIdentity
        [entry "src//A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "current-directory path segment"
        64 1 0
        canonicalIdentity
        [entry "src/./A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "parent-directory path segment"
        64 1 0
        canonicalIdentity
        [entry "src/../A.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , exactPreflight
        "non-portable path character"
        64 1 0
        canonicalIdentity
        [entry "src/A B.hs" "haskell" regular objectA]
        []
        [ localFinding "SRC-CONSUMER-POSIX-PATH" "inventory-path"
            "path must be a nonempty safe relative POSIX path"
        ]
    , expectExact
        "executable Haskell subject binds the exact rejected mode"
        ( completeExpected
            canonicalIdentityExpected
            1 0 0 1
            [entryObservation 0 ("src/A.hs", "haskell", "100755", objectAExpected)]
            []
            []
            [Observation "source-consumer.haskell.src/A.hs" ("100755\t" <> objectAExpected)]
            [localFinding "SRC-CONSUMER-HASKELL-MODE" "src/A.hs"
              "every Haskell compiler subject must be a regular non-executable blob"]
        )
        (diagnostic canonicalIdentity [entry "src/A.hs" "haskell" executable objectA] [])
    , expectExact
        "symlink-mode Haskell subject binds the exact rejected mode"
        ( completeExpected
            canonicalIdentityExpected
            1 0 0 1
            [entryObservation 0 ("src/A.hs", "haskell", "120000", objectAExpected)]
            []
            []
            [Observation "source-consumer.haskell.src/A.hs" ("120000\t" <> objectAExpected)]
            [localFinding "SRC-CONSUMER-HASKELL-MODE" "src/A.hs"
              "every Haskell compiler subject must be a regular non-executable blob"]
        )
        (diagnostic canonicalIdentity [entry "src/A.hs" "haskell" symlinkMode objectA] [])
    ]

roleProblems :: [String]
roleProblems =
  concat
    [ exactSingleBinding "governance Markdown"
        (entry "README.md" "documentation" regular objectA)
        (entryObservation 0 ("README.md", "documentation", "100644", objectAExpected))
        (binding "README.md" "GovernanceDocumentation" "HumanReader,HaskellSourceBoundaryStructureChecker,HaskellDocumentationStructureChecker")
    , exactSingleBinding "root Cabal package"
        (entry "amoebius.cabal" "project-declaration" regular objectA)
        (entryObservation 0 ("amoebius.cabal", "project-declaration", "100644", objectAExpected))
        (binding "amoebius.cabal" "CabalPackageDescription" "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool")
    , exactSingleBinding "probe Cabal package"
        (entry "probe/probe.cabal" "project-declaration" regular objectA)
        (entryObservation 0 ("probe/probe.cabal", "project-declaration", "100644", objectAExpected))
        (binding "probe/probe.cabal" "CabalPackageDescription" "HaskellSourceBoundaryStructureChecker,CabalBuildTool")
    , exactSingleBinding "cabal.project"
        (entry "cabal.project" "project-declaration" regular objectA)
        (entryObservation 0 ("cabal.project", "project-declaration", "100644", objectAExpected))
        (binding "cabal.project" "CabalProjectDescription" "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool")
    , exactSingleBinding ".gitignore"
        (entry ".gitignore" "project-declaration" regular objectA)
        (entryObservation 0 (".gitignore", "project-declaration", "100644", objectAExpected))
        (binding ".gitignore" "GitIgnoreContract" "HaskellSourceBoundaryStructureChecker,GitClient")
    , exactSingleBinding ".dockerignore"
        (entry ".dockerignore" "project-declaration" regular objectA)
        (entryObservation 0 (".dockerignore", "project-declaration", "100644", objectAExpected))
        (binding ".dockerignore" "DockerIgnoreContract" "HaskellSourceBoundaryStructureChecker,ContainerContextBuilder")
    , exactSingleBinding ".gitattributes"
        (entry ".gitattributes" "project-declaration" regular objectA)
        (entryObservation 0 (".gitattributes", "project-declaration", "100644", objectAExpected))
        (binding ".gitattributes" "GitAttributesContract" "HaskellSourceBoundaryStructureChecker,GitClient")
    , exactSingleBinding ".editorconfig"
        (entry ".editorconfig" "project-declaration" regular objectA)
        (entryObservation 0 (".editorconfig", "project-declaration", "100644", objectAExpected))
        (binding ".editorconfig" "EditorConfiguration" "HaskellSourceBoundaryStructureChecker,EditorTool")
    , exactRoleRefusal "LICENSE.md lexical prose"
        (entry "LICENSE.md" "documentation" regular objectA)
        (entryObservation 0 ("LICENSE.md", "documentation", "100644", objectAExpected))
        (localFinding "SRC-CONSUMER-LEGAL-NAME" "LICENSE.md"
          "LICENSE, LICENCE, COPYING, and NOTICE stems have no machine-owned semantic role")
    , exactRoleRefusal "NOTICE suffix lexical prose"
        (entry "NOTICE.extra.md" "documentation" regular objectA)
        (entryObservation 0 ("NOTICE.extra.md", "documentation", "100644", objectAExpected))
        (localFinding "SRC-CONSUMER-LEGAL-NAME" "NOTICE.extra.md"
          "LICENSE, LICENCE, COPYING, and NOTICE stems have no machine-owned semantic role")
    , exactRoleRefusal "non-Markdown documentation"
        (entry "README.txt" "documentation" regular objectA)
        (entryObservation 0 ("README.txt", "documentation", "100644", objectAExpected))
        (localFinding "SRC-CONSUMER-ROLE-UNBOUND" "README.txt"
          "no exact closed content role exists for this admitted class and path")
    , exactRoleRefusal "unknown project declaration"
        (entry "stack.yaml" "project-declaration" regular objectA)
        (entryObservation 0 ("stack.yaml", "project-declaration", "100644", objectAExpected))
        (localFinding "SRC-CONSUMER-ROLE-UNBOUND" "stack.yaml"
          "no exact closed content role exists for this admitted class and path")
    , exactRoleRefusal "executable admitted content"
        (entry "README.md" "documentation" executable objectA)
        (entryObservation 0 ("README.md", "documentation", "100755", objectAExpected))
        (localFinding "SRC-CONSUMER-CONTENT-MODE" "README.md"
          "admitted non-source content must be a regular non-executable blob")
    ]

exactSingleBinding :: String -> EntryWire -> Observation -> Observation -> [String]
exactSingleBinding label content expectedContent expectedBinding =
  expectExact
    label
    ( completeExpected canonicalIdentityExpected 2 0 1 1
        [expectedContent, controlEntryObservationAt1]
        []
        [expectedBinding]
        oneControlSubject
        []
    )
    (diagnostic canonicalIdentity inventory [])
 where
  inventory = [content, controlEntry]

exactRoleRefusal :: String -> EntryWire -> Observation -> Finding -> [String]
exactRoleRefusal label content expectedContent problem =
  expectExact
    label
    ( completeExpected canonicalIdentityExpected 2 0 0 1
        [expectedContent, controlEntryObservationAt1] [] [] oneControlSubject [problem]
    )
    (diagnostic canonicalIdentity [content, controlEntry] [])

-- Remaining exact effect/resource fixtures and local expectation declarations
-- follow below.

effectProblems :: [String]
effectProblems =
  concat
    [ exactEffect "exact documentation reader" documentationEffect
        (effectObservation 0 ("src/validation-kernel/Amoebius/Validation/Documentation.hs", "Amoebius.Validation.Documentation", "readDocument", "exact", "README.md", "documentation-structure")) []
    , exactEffect
        "wrong documentation reader"
        (effect "src/Wrong.hs" "Wrong" "readDocument" "exact" "README.md" "documentation-structure")
        (effectObservation 0 ("src/Wrong.hs", "Wrong", "readDocument", "exact", "README.md", "documentation-structure"))
        [unauthorized "src/Wrong.hs" "Wrong.readDocument" "README.md" "StructuralDocumentationInspection"]
    , exactEffect "exact source-boundary reader" sourceBoundaryEffect
        (effectObservation 0 ("src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs", "Amoebius.Validation.SourceClosure.Internal", "classifyEntry", "exact", "README.md", "source-boundary-structure")) []
    , exactEffect
        "wrong source-boundary reader"
        (effect "src/Wrong.hs" "Wrong" "classifyEntry" "exact" "README.md" "source-boundary-structure")
        (effectObservation 0 ("src/Wrong.hs", "Wrong", "classifyEntry", "exact", "README.md", "source-boundary-structure"))
        [unauthorized "src/Wrong.hs" "Wrong.classifyEntry" "README.md" "SourceBoundaryStructureInspection"]
    , exactEffect "exact repository-root reader" rootEffect
        (effectObservation 0 ("src/validation-kernel/Amoebius/Validation/Dispatch.hs", "Amoebius.Validation.Dispatch", "discoverRepositoryRoot", "exact", "amoebius.cabal", "repository-root-sentinel")) []
    , exactEffect
        "wrong repository-root reader"
        (effect "src/Wrong.hs" "Wrong" "discoverRepositoryRoot" "exact" "amoebius.cabal" "repository-root-sentinel")
        (effectObservation 0 ("src/Wrong.hs", "Wrong", "discoverRepositoryRoot", "exact", "amoebius.cabal", "repository-root-sentinel"))
        [unauthorized "src/Wrong.hs" "Wrong.discoverRepositoryRoot" "amoebius.cabal" "RepositoryRootSentinel"]
    , exactEffect
        "missing exact target"
        (effect "src/A.hs" "A" "read" "exact" "missing.md" "documentation-structure")
        (effectObservation 0 ("src/A.hs", "A", "read", "exact", "missing.md", "documentation-structure"))
        [localFinding "SRC-CONSUMER-EFFECT-TARGET" "missing.md"
          "resolved effect target has no admitted non-source content binding"]
    , exactEffect
        "dynamic target"
        (effect "src/A.hs" "A" "read" "dynamic" "computed-path" "documentation-structure")
        (effectObservation 0 ("src/A.hs", "A", "read", "dynamic", "computed-path", "documentation-structure"))
        [localFinding "SRC-CONSUMER-DYNAMIC-TARGET" "src/A.hs"
          "dynamic effect target may alias tracked content: computed-path"]
    , exactEffect
        "unresolved target"
        (effect "src/A.hs" "A" "read" "unresolved" "renamer-gap" "documentation-structure")
        (effectObservation 0 ("src/A.hs", "A", "read", "unresolved", "renamer-gap", "documentation-structure"))
        [localFinding "SRC-CONSUMER-UNRESOLVED-EFFECT" "src/A.hs"
          "compiler effect target did not resolve: renamer-gap"]
    , exactEffect
        "direct product behavior"
        (effect "src/A.hs" "A" "read" "exact" "README.md" "product-behaviour")
        (effectObservation 0 ("src/A.hs", "A", "read", "exact", "README.md", "product-behaviour"))
        [localFinding "SRC-CONSUMER-DIRECT-BEHAVIOUR" "src/A.hs"
          "resolved consumer A.read treats README.md as product behaviour"]
    , exactPreflight
        "unknown effect target tag"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "A" "read" "invented" "README.md" "documentation-structure"]
        [localFinding "SRC-CONSUMER-TARGET-TAG" "src/A.hs"
          "effect target tag must be exact, dynamic, or unresolved"]
    , exactPreflight
        "unknown effect use tag"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "A" "read" "exact" "README.md" "invented-use"]
        [localFinding "SRC-CONSUMER-USE-TAG" "src/A.hs"
          "effect use tag is outside the closed diagnostic vocabulary"]
    , exactPreflight
        "empty effect module name"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "" "read" "exact" "README.md" "documentation-structure"]
        [localFinding "SRC-CONSUMER-EFFECT-MODULE" "src/A.hs"
          "effect module name must be nonempty"]
    , exactPreflight
        "empty effect binding name"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "A" "" "exact" "README.md" "documentation-structure"]
        [localFinding "SRC-CONSUMER-EFFECT-MODULE" "src/A.hs"
          "effect binding name must be nonempty"]
    , exactPreflight
        "empty effect target value"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "A" "read" "dynamic" "" "documentation-structure"]
        [localFinding "SRC-CONSUMER-TARGET-VALUE" "src/A.hs"
          "effect target value must be nonempty"]
    , exactPreflight
        "unsafe effect module path"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "/src/A.hs" "A" "read" "dynamic" "computed-path" "documentation-structure"]
        [localFinding "SRC-CONSUMER-POSIX-PATH" "effect-module-path"
          "path must be a nonempty safe relative POSIX path"]
    , exactPreflight
        "unsafe exact effect target path"
        64 3 1
        canonicalIdentity
        effectInventory
        [effect "src/A.hs" "A" "read" "exact" "../README.md" "documentation-structure"]
        [localFinding "SRC-CONSUMER-POSIX-PATH" "effect-target-path"
          "exact effect target must be a safe relative POSIX path"]
    ]

exactEffect :: String -> EffectWire -> Observation -> [Finding] -> [String]
exactEffect label observedEffect expectedEffect problems =
  expectExact
    label
    ( completeExpected canonicalIdentityExpected 3 1 2 1
        effectEntryObservations [expectedEffect]
        effectBindingObservations effectSubjectObservations problems
    )
    (diagnostic canonicalIdentity effectInventory [observedEffect])

resourceProblems :: [String]
resourceProblems =
  concat
    [ inventoryBoundaryProblems
    , effectBoundaryProblems
    , bindingBoundaryProblems
    , haskellBoundaryProblems
    , pathBoundaryProblems
    , depthBoundaryProblems
    , segmentBoundaryProblems
    , fieldBoundaryProblems
    , problemBoundaryProblems
    , observationBoundaryProblems
    ]

inventoryBoundaryProblems :: [String]
inventoryBoundaryProblems =
  expectExact
    "64 inventory rows are the exact maximum"
    (completeExpected canonicalIdentityExpected 64 0 0 32
      inventoryEntryObservations64 [] [] haskellObservations32 [])
    (diagnostic canonicalIdentity inventory64 [])
    <> expectExact
      "65 inventory rows refuse before row traversal"
      (preflightExpected 64 65 0
        [resourceFinding "inventory-entries" 64 65])
      (diagnostic canonicalIdentity inventory65 [])

effectBoundaryProblems :: [String]
effectBoundaryProblems =
  expectExact
    "64 caller effects are the exact maximum"
    (completeExpected canonicalIdentityExpected 3 64 2 1
      effectEntryObservations effectObservations64
      effectBindingObservations effectSubjectObservations [])
    (diagnostic canonicalIdentity effectInventory effects64)
    <> expectExact
      "65 caller effects refuse before traversal"
      (preflightExpected 64 3 65
        [resourceFinding "resolved-effects" 64 65])
      (diagnostic canonicalIdentity effectInventory effects65)

bindingBoundaryProblems :: [String]
bindingBoundaryProblems =
  expectExact
    "32 content bindings are the exact maximum"
    (completeExpected canonicalIdentityExpected 33 0 32 1
      bindingEntryObservations32 [] bindingObservations32 oneControlSubject [])
    (diagnostic canonicalIdentity bindingInventory32 [])
    <> expectExact
      "33 content bindings refuse before role construction"
      (preflightExpected 64 34 0
        [resourceFinding "content-bindings" 32 33])
      (diagnostic canonicalIdentity bindingInventory33 [])

haskellBoundaryProblems :: [String]
haskellBoundaryProblems =
  expectExact
    "32 Haskell subjects are the exact maximum"
    (completeExpected canonicalIdentityExpected 32 0 0 32
      haskellEntryObservations32 [] [] haskellObservations32 [])
    (diagnostic canonicalIdentity haskellInventory32 [])
    <> expectExact
      "33 Haskell subjects refuse before subject construction"
      (preflightExpected 64 33 0
        [resourceFinding "haskell-subjects" 32 33])
      (diagnostic canonicalIdentity haskellInventory33 [])

pathBoundaryProblems :: [String]
pathBoundaryProblems =
  expectExact
    "1024 safe path bytes are the exact maximum"
    (completeExpected canonicalIdentityExpected 2 0 0 1
      [ entryObservation 0 (path1024Expected, "other", "100644", objectAExpected)
      , controlEntryObservationAt1
      ] [] [] oneControlSubject [])
    (diagnostic canonicalIdentity (boundedOtherInventory path1024) [])
    <> expectExact
      "1025 path bytes refuse before parsing"
      (preflightExpected 64 2 0
        [resourceFinding "inventory-path-bytes" 1024 1025])
      (diagnostic canonicalIdentity (boundedOtherInventory path1025) [])

depthBoundaryProblems :: [String]
depthBoundaryProblems =
  expectExact
    "64 POSIX segments are the exact maximum"
    (completeExpected canonicalIdentityExpected 2 0 0 1
      [ entryObservation 0 (depth64Expected, "other", "100644", objectAExpected)
      , controlEntryObservationAt1
      ] [] [] oneControlSubject [])
    (diagnostic canonicalIdentity (boundedOtherInventory depth64) [])
    <> expectExact
      "65 POSIX segments refuse before semantics"
      (preflightExpected 64 2 0
        [resourceFinding "inventory-path-depth" 64 65])
      (diagnostic canonicalIdentity (boundedOtherInventory depth65) [])

segmentBoundaryProblems :: [String]
segmentBoundaryProblems =
  expectExact
    "255 segment bytes are the exact maximum"
    (completeExpected canonicalIdentityExpected 2 0 0 1
      [ entryObservation 0 (segment255Expected, "other", "100644", objectAExpected)
      , controlEntryObservationAt1
      ] [] [] oneControlSubject [])
    (diagnostic canonicalIdentity (boundedOtherInventory segment255) [])
    <> expectExact
      "256 segment bytes refuse before semantics"
      (preflightExpected 64 2 0
        [resourceFinding "inventory-path-segment-bytes" 255 256])
      (diagnostic canonicalIdentity (boundedOtherInventory segment256) [])

fieldBoundaryProblems :: [String]
fieldBoundaryProblems =
  expectExact
    "256 dynamic-target bytes are the exact field maximum"
    ( completeExpected canonicalIdentityExpected 3 1 2 1
        effectEntryObservations
        [effectObservation 0 ("src/A.hs", "A", "read", "dynamic", field256Expected, "documentation-structure")]
        effectBindingObservations
        effectSubjectObservations
        [localFinding "SRC-CONSUMER-DYNAMIC-TARGET" "src/A.hs"
          ("dynamic effect target may alias tracked content: " <> field256Expected)]
    )
    (diagnostic canonicalIdentity effectInventory [fieldEffect field256])
    <> expectExact
      "257 field bytes refuse before effect semantics"
      (preflightExpected 64 3 1
        [resourceFinding "effect-target-value-bytes" 256 257])
      (diagnostic canonicalIdentity effectInventory [fieldEffect field257])

problemBoundaryProblems :: [String]
problemBoundaryProblems =
  expectExact
    "32 row problems are retained in exact order"
    (preflightExpected 64 11 0 invalidFindings32)
    (diagnostic canonicalIdentity invalidRows32 [])
    <> expectExact
      "33 row problems collapse to the bounded refusal"
      (preflightExpected 64 11 0
        [resourceFinding "diagnostic-problems" 32 33])
      (diagnostic canonicalIdentity invalidRows33 [])

observationBoundaryProblems :: [String]
observationBoundaryProblems =
  expectEqual
    "the local exact result fixture contains literally 218 observations"
    218
    (length observationBoundaryExpected)
    <> expectExact
      "218 observations are rendered completely"
      (CheckResult diagnosticName observationBoundaryExpected permanentFindings)
      (diagnostic canonicalIdentity observationInventory observationEffects62)
    <> expectExact
      "219 observations refuse without a partial graph"
      (preflightExpected 64 64 63
        [resourceFinding "result-observations" 218 219])
      (diagnostic canonicalIdentity observationInventory observationEffects63)

opacityControlProblems :: [String]
opacityControlProblems =
  concat
    [ expectEqual "public check-name control" diagnosticName
        (checkName (diagnostic canonicalIdentity canonicalInventory []))
    , expectEqual "public permanent-refusal control" False
        (checkPassed (diagnostic canonicalIdentity canonicalInventory []))
    ]

diagnostic :: Text -> [EntryWire] -> [EffectWire] -> CheckResult
diagnostic = sourceConsumerGraphDiagnostic

exactPreflight
  :: String
  -> Int
  -> Int
  -> Int
  -> Text
  -> [EntryWire]
  -> [EffectWire]
  -> [Finding]
  -> [String]
exactPreflight label expectedIdentityCharacters expectedInventoryCount expectedEffectCount identity inventory effects problems =
  expectExact
    label
    (preflightExpected expectedIdentityCharacters expectedInventoryCount expectedEffectCount problems)
    (diagnostic identity inventory effects)

completeExpected
  :: Text
  -> Int
  -> Int
  -> Int
  -> Int
  -> [Observation]
  -> [Observation]
  -> [Observation]
  -> [Observation]
  -> [Finding]
  -> CheckResult
completeExpected identity inventoryCount effectCount bindingCount haskellCount entries effects bindings subjects problems =
  CheckResult
    { checkName = diagnosticName
    , checkObservations =
        limitObservations
          <> [ Observation "source-consumer.snapshot" identity
             , Observation "source-consumer.inventory-count" (decimal inventoryCount)
             , Observation "source-consumer.effect-count" (decimal effectCount)
             , Observation "source-consumer.binding-count" (decimal bindingCount)
             , Observation "source-consumer.haskell-count" (decimal haskellCount)
             ]
          <> entries
          <> effects
          <> bindings
          <> subjects
          <> compilerFactObservations
    , checkFindings = permanentFindings <> problems
    }

preflightExpected :: Int -> Int -> Int -> [Finding] -> CheckResult
preflightExpected identityCharacters inventoryCount effectCount problems =
  CheckResult
    { checkName = diagnosticName
    , checkObservations =
        limitObservations
          <> [ Observation "input.snapshot-identity-characters" (decimal identityCharacters)
             , Observation "input.inventory-count" (decimal inventoryCount)
             , Observation "input.effect-count" (decimal effectCount)
             ]
    , checkFindings = permanentFindings <> problems
    }

entryObservation :: Int -> EntryWire -> Observation
entryObservation index (path, classTag, mode, objectId) =
  Observation
    ("input.entry." <> decimal index)
    (Text.intercalate "\t" [Text.pack path, classTag, mode, objectId])

effectObservation :: Int -> EffectWire -> Observation
effectObservation index (modulePath, moduleName, bindingName, targetTag, targetValue, useTag) =
  Observation
    ("input.effect." <> decimal index)
    (Text.intercalate "\t" [Text.pack modulePath, moduleName, bindingName, targetTag, targetValue, useTag])

binding :: FilePath -> Text -> Text -> Observation
binding path role consumers =
  Observation ("source-consumer.binding." <> Text.pack path) (role <> "\t" <> consumers)

canonicalEntryObservations :: [Observation]
canonicalEntryObservations =
  [ entryObservation 0 (".dockerignore", "project-declaration", "100644", objectAExpected)
  , entryObservation 1 (".editorconfig", "project-declaration", "100644", objectAExpected)
  , entryObservation 2 (".gitattributes", "project-declaration", "100644", objectAExpected)
  , entryObservation 3 (".gitignore", "project-declaration", "100644", objectAExpected)
  , entryObservation 4 ("README.md", "documentation", "100644", objectAExpected)
  , entryObservation 5 ("amoebius.cabal", "project-declaration", "100644", objectAExpected)
  , entryObservation 6 ("cabal.project", "project-declaration", "100644", objectAExpected)
  , entryObservation 7 ("probe/probe.cabal", "project-declaration", "100644", objectAExpected)
  , entryObservation 8 ("src/A.hs", "haskell", "100644", objectAExpected)
  , entryObservation 9 ("vendor/B.hs", "haskell", "100644", objectBExpected)
  ]

canonicalBindingObservations :: [Observation]
canonicalBindingObservations =
  [ binding ".dockerignore" "DockerIgnoreContract" "HaskellSourceBoundaryStructureChecker,ContainerContextBuilder"
  , binding ".editorconfig" "EditorConfiguration" "HaskellSourceBoundaryStructureChecker,EditorTool"
  , binding ".gitattributes" "GitAttributesContract" "HaskellSourceBoundaryStructureChecker,GitClient"
  , binding ".gitignore" "GitIgnoreContract" "HaskellSourceBoundaryStructureChecker,GitClient"
  , binding "README.md" "GovernanceDocumentation" "HumanReader,HaskellSourceBoundaryStructureChecker,HaskellDocumentationStructureChecker"
  , binding "amoebius.cabal" "CabalPackageDescription" "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool"
  , binding "cabal.project" "CabalProjectDescription" "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool"
  , binding "probe/probe.cabal" "CabalPackageDescription" "HaskellSourceBoundaryStructureChecker,CabalBuildTool"
  ]

canonicalSubjectObservations :: [Observation]
canonicalSubjectObservations =
  [ Observation "source-consumer.haskell.src/A.hs" ("100644\t" <> objectAExpected)
  , Observation "source-consumer.haskell.vendor/B.hs" ("100644\t" <> objectBExpected)
  ]

canonicalInventory :: [EntryWire]
canonicalInventory =
  [ entry ".dockerignore" "project-declaration" regular objectA
  , entry ".editorconfig" "project-declaration" regular objectA
  , entry ".gitattributes" "project-declaration" regular objectA
  , entry ".gitignore" "project-declaration" regular objectA
  , entry "README.md" "documentation" regular objectA
  , entry "amoebius.cabal" "project-declaration" regular objectA
  , entry "cabal.project" "project-declaration" regular objectA
  , entry "probe/probe.cabal" "project-declaration" regular objectA
  , entry "src/A.hs" "haskell" regular objectA
  , entry "vendor/B.hs" "haskell" regular objectB
  ]

controlEntry :: EntryWire
controlEntry = entry "zz/Control.hs" "haskell" regular objectB

oneControlSubject :: [Observation]
oneControlSubject =
  [Observation "source-consumer.haskell.zz/Control.hs" ("100644\t" <> objectBExpected)]

controlEntryObservationAt1 :: Observation
controlEntryObservationAt1 =
  entryObservation 1 ("zz/Control.hs", "haskell", "100644", objectBExpected)

governanceEntry :: EntryWire
governanceEntry = entry "README.md" "documentation" regular objectA

governanceEntryObservation, governanceBindingObservation :: Observation
governanceEntryObservation = entryObservation 0 ("README.md", "documentation", "100644", objectAExpected)
governanceBindingObservation =
  binding
    "README.md"
    "GovernanceDocumentation"
    "HumanReader,HaskellSourceBoundaryStructureChecker,HaskellDocumentationStructureChecker"

duplicateInventory, reverseInventory :: [EntryWire]
duplicateInventory =
  [ entry "src/A.hs" "haskell" regular objectA
  , entry "src/A.hs" "haskell" regular objectB
  ]
reverseInventory =
  [ entry "src/B.hs" "haskell" regular objectB
  , entry "src/A.hs" "haskell" regular objectA
  ]

portableAlphabetPath :: FilePath
portableAlphabetPath = "a-Z_09.+@%=-"

effectInventory :: [EntryWire]
effectInventory =
  [ entry "README.md" "documentation" regular objectA
  , entry "amoebius.cabal" "project-declaration" regular objectA
  , entry "src/A.hs" "haskell" regular objectB
  ]

effectBindingObservations, effectSubjectObservations :: [Observation]
effectBindingObservations =
  [ binding "README.md" "GovernanceDocumentation" "HumanReader,HaskellSourceBoundaryStructureChecker,HaskellDocumentationStructureChecker"
  , binding "amoebius.cabal" "CabalPackageDescription" "HaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool"
  ]
effectSubjectObservations =
  [Observation "source-consumer.haskell.src/A.hs" ("100644\t" <> objectBExpected)]

effectEntryObservations :: [Observation]
effectEntryObservations =
  [ entryObservation 0 ("README.md", "documentation", "100644", objectAExpected)
  , entryObservation 1 ("amoebius.cabal", "project-declaration", "100644", objectAExpected)
  , entryObservation 2 ("src/A.hs", "haskell", "100644", objectBExpected)
  ]

documentationEffect, sourceBoundaryEffect, rootEffect :: EffectWire
documentationEffect =
  effect
    "src/validation-kernel/Amoebius/Validation/Documentation.hs"
    "Amoebius.Validation.Documentation"
    "readDocument"
    "exact"
    "README.md"
    "documentation-structure"
sourceBoundaryEffect =
  effect
    "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
    "Amoebius.Validation.SourceClosure.Internal"
    "classifyEntry"
    "exact"
    "README.md"
    "source-boundary-structure"
rootEffect =
  effect
    "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
    "Amoebius.Validation.Dispatch"
    "discoverRepositoryRoot"
    "exact"
    "amoebius.cabal"
    "repository-root-sentinel"

cabalProjectRootEffect :: EffectWire
cabalProjectRootEffect =
  effect
    "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
    "Amoebius.Validation.Dispatch"
    "discoverRepositoryRoot"
    "exact"
    "cabal.project"
    "repository-root-sentinel"

documentationEffectObservation, sourceBoundaryEffectObservation, rootEffectObservation, cabalProjectRootEffectObservation :: Observation
documentationEffectObservation =
  effectObservation
    0
    ( "src/validation-kernel/Amoebius/Validation/Documentation.hs"
    , "Amoebius.Validation.Documentation"
    , "readDocument"
    , "exact"
    , "README.md"
    , "documentation-structure"
    )
sourceBoundaryEffectObservation =
  effectObservation
    0
    ( "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
    , "Amoebius.Validation.SourceClosure.Internal"
    , "classifyEntry"
    , "exact"
    , "README.md"
    , "source-boundary-structure"
    )
rootEffectObservation =
  effectObservation
    0
    ( "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
    , "Amoebius.Validation.Dispatch"
    , "discoverRepositoryRoot"
    , "exact"
    , "amoebius.cabal"
    , "repository-root-sentinel"
    )
cabalProjectRootEffectObservation =
  effectObservation
    0
    ( "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
    , "Amoebius.Validation.Dispatch"
    , "discoverRepositoryRoot"
    , "exact"
    , "cabal.project"
    , "repository-root-sentinel"
    )

missingEffect, dynamicEffect, unresolvedEffect, directEffect :: EffectWire
missingEffect = effect "src/A.hs" "A" "read" "exact" "missing.md" "documentation-structure"
dynamicEffect = effect "src/A.hs" "A" "read" "dynamic" "computed-path" "documentation-structure"
unresolvedEffect = effect "src/A.hs" "A" "read" "unresolved" "renamer-gap" "documentation-structure"
directEffect = effect "src/A.hs" "A" "read" "exact" "README.md" "product-behaviour"

missingEffectObservation, dynamicEffectObservation, unresolvedEffectObservation, directEffectObservation :: Observation
missingEffectObservation = effectObservation 0 ("src/A.hs", "A", "read", "exact", "missing.md", "documentation-structure")
dynamicEffectObservation = effectObservation 0 ("src/A.hs", "A", "read", "dynamic", "computed-path", "documentation-structure")
unresolvedEffectObservation = effectObservation 0 ("src/A.hs", "A", "read", "unresolved", "renamer-gap", "documentation-structure")
directEffectObservation = effectObservation 0 ("src/A.hs", "A", "read", "exact", "README.md", "product-behaviour")

unauthorized :: FilePath -> Text -> FilePath -> Text -> Finding
unauthorized modulePath name target useName =
  localFinding
    "SRC-CONSUMER-EFFECT-UNAUTHORIZED"
    modulePath
    ( "resolved consumer "
        <> name
        <> " is not authorized for "
        <> Text.pack target
        <> " as "
        <> useName
    )

inventory64, inventory65, haskellInventory32, haskellInventory33 :: [EntryWire]
inventory64 = otherEntries 32 <> haskellEntries 32
inventory65 = otherEntries 33 <> haskellEntries 32
haskellInventory32 = haskellEntries 32
haskellInventory33 = haskellEntries 33

inventoryEntryObservations64, haskellEntryObservations32, haskellObservations32 :: [Observation]
inventoryEntryObservations64 =
  [ entryObservation index ("other/O" <> expectedPad3 index, "other", "100644", objectAExpected)
  | index <- [0 .. 31]
  ]
    <> [ entryObservation (32 + index) ("src/H" <> expectedPad3 index <> ".hs", "haskell", "100644", objectBExpected)
       | index <- [0 .. 31]
       ]
haskellEntryObservations32 =
  [ entryObservation index ("src/H" <> expectedPad3 index <> ".hs", "haskell", "100644", objectBExpected)
  | index <- [0 .. 31]
  ]
haskellObservations32 =
  [ Observation
      ("source-consumer.haskell.src/H" <> Text.pack (expectedPad3 index) <> ".hs")
      ("100644\t" <> objectBExpected)
  | index <- [0 .. 31]
  ]

otherEntries :: Int -> [EntryWire]
otherEntries count =
  [ entry ("other/O" <> pad3 index) "other" regular objectA
  | index <- [0 .. count - 1]
  ]

haskellEntries :: Int -> [EntryWire]
haskellEntries count =
  [ entry ("src/H" <> pad3 index <> ".hs") "haskell" regular objectB
  | index <- [0 .. count - 1]
  ]

effects64, effects65 :: [EffectWire]
effects64 = replicate 64 documentationEffect
effects65 = replicate 65 documentationEffect

effectObservations64 :: [Observation]
effectObservations64 =
  [ effectObservation index
      ( "src/validation-kernel/Amoebius/Validation/Documentation.hs"
      , "Amoebius.Validation.Documentation"
      , "readDocument"
      , "exact"
      , "README.md"
      , "documentation-structure"
      )
  | index <- [0 .. 63]
  ]

bindingInventory32, bindingInventory33, projectBindingInventory33 :: [EntryWire]
bindingInventory32 = documentationEntries 32 <> [controlEntry]
bindingInventory33 = documentationEntries 33 <> [controlEntry]
projectBindingInventory33 =
  [ entry ("project/P" <> pad3 index) "project-declaration" regular objectA
  | index <- [0 .. 32]
  ]
    <> [controlEntry]

documentationEntries :: Int -> [EntryWire]
documentationEntries count =
  [ entry ("docs/D" <> pad3 index <> ".md") "documentation" regular objectA
  | index <- [0 .. count - 1]
  ]

bindingObservations32 :: [Observation]
bindingObservations32 =
  [ binding
      ("docs/D" <> expectedPad3 index <> ".md")
      "GovernanceDocumentation"
      "HumanReader,HaskellSourceBoundaryStructureChecker,HaskellDocumentationStructureChecker"
  | index <- [0 .. 31]
  ]

bindingEntryObservations32 :: [Observation]
bindingEntryObservations32 =
  [ entryObservation index
      ("docs/D" <> expectedPad3 index <> ".md", "documentation", "100644", objectAExpected)
  | index <- [0 .. 31]
  ]
    <> [entryObservation 32 ("zz/Control.hs", "haskell", "100644", objectBExpected)]

boundedOtherInventory :: FilePath -> [EntryWire]
boundedOtherInventory path =
  [ entry path "other" regular objectA
  , controlEntry
  ]

path1024, path1025, depth64, depth65, segment255, segment256 :: FilePath
path1024 = intercalateSlash (replicate 5 (replicate 204 'p'))
path1025 = path1024 <> "p"
depth64 = intercalateSlash (replicate 64 "a")
depth65 = intercalateSlash (replicate 65 "a")
segment255 = replicate 255 's'
segment256 = replicate 256 's'

path1024Expected, depth64Expected, segment255Expected :: FilePath
path1024Expected = expectedSlashJoin (replicate 5 (replicate 204 'p'))
depth64Expected = expectedSlashJoin (replicate 64 "a")
segment255Expected = replicate 255 's'

intercalateSlash :: [String] -> String
intercalateSlash [] = ""
intercalateSlash (value : values) =
  foldl (\current next -> current <> "/" <> next) value values

expectedSlashJoin :: [String] -> String
expectedSlashJoin [] = ""
expectedSlashJoin [value] = value
expectedSlashJoin (value : values) = value <> "/" <> expectedSlashJoin values

field256, field257, fieldTwoByte256, fieldTwoByte257, fieldThreeByte256, fieldThreeByte257, fieldFourByte256, fieldFourByte257 :: Text
field256 = Text.replicate 256 "d"
field257 = Text.replicate 257 "d"
fieldTwoByte256 = Text.replicate 128 "\233"
fieldTwoByte257 = Text.replicate 127 "\233" <> "\233a"
fieldThreeByte256 = Text.replicate 85 "\8364" <> "a"
fieldThreeByte257 = Text.replicate 85 "\8364" <> "aa"
fieldFourByte256 = Text.replicate 64 "\128512"
fieldFourByte257 = Text.replicate 64 "\128512" <> "a"

field256Expected, fieldTwoByte256Expected, fieldThreeByte256Expected, fieldFourByte256Expected :: Text
field256Expected = Text.replicate 256 "d"
fieldTwoByte256Expected = Text.replicate 128 "\233"
fieldThreeByte256Expected = Text.replicate 85 "\8364" <> "a"
fieldFourByte256Expected = Text.replicate 64 "\128512"

fieldEffect :: Text -> EffectWire
fieldEffect detail =
  effect "src/A.hs" "A" "read" "dynamic" detail "documentation-structure"

invalidRows32, invalidRows33 :: [EntryWire]
invalidRows32 =
  [ entry ("bad/T" <> pad3 index) "invented" "100600" "xyz"
  | index <- [0 .. 9]
  ]
    <> [entry "bad/Z999" "invented" "100600" objectA]
invalidRows33 =
  [ entry ("bad/T" <> pad3 index) "invented" "100600" "xyz"
  | index <- [0 .. 10]
  ]

invalidFindings32 :: [Finding]
invalidFindings32 =
  concat [invalidTriple ("bad/T" <> expectedPad3 index) | index <- [0 .. 9]]
    <> [ localFinding "SRC-CONSUMER-CLASS-TAG" "bad/Z999"
          "class tag must be haskell, documentation, project-declaration, or other"
       , localFinding "SRC-CONSUMER-MODE-TAG" "bad/Z999"
          "Git mode must be exactly 100644, 100755, or 120000"
       ]

invalidTriple :: FilePath -> [Finding]
invalidTriple path =
  [ localFinding "SRC-CONSUMER-CLASS-TAG" path
      "class tag must be haskell, documentation, project-declaration, or other"
  , localFinding "SRC-CONSUMER-MODE-TAG" path
      "Git mode must be exactly 100644, 100755, or 120000"
  , localFinding "SRC-CONSUMER-OBJECT-ID" path
      "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
  ]

observationInventory :: [EntryWire]
observationInventory = documentationEntries 32 <> haskellEntries 32

observationEntryObservations :: [Observation]
observationEntryObservations =
  [ entryObservation index
      ("docs/D" <> expectedPad3 index <> ".md", "documentation", "100644", objectAExpected)
  | index <- [0 .. 31]
  ]
    <> [ entryObservation (32 + index)
          ("src/H" <> expectedPad3 index <> ".hs", "haskell", "100644", objectBExpected)
       | index <- [0 .. 31]
       ]

observationBoundaryExpected :: [Observation]
observationBoundaryExpected =
  checkObservations
    ( completeExpected
        canonicalIdentityExpected
        64
        62
        32
        32
        observationEntryObservations
        observationEffectObservations62
        bindingObservations32
        haskellObservations32
        []
    )

observationEffects62, observationEffects63 :: [EffectWire]
observationEffects62 = replicate 62 observationEffect
observationEffects63 = replicate 63 observationEffect

observationEffect :: EffectWire
observationEffect =
  effect
    "src/validation-kernel/Amoebius/Validation/Documentation.hs"
    "Amoebius.Validation.Documentation"
    "readDocument"
    "exact"
    "docs/D000.md"
    "documentation-structure"

observationEffectObservations62 :: [Observation]
observationEffectObservations62 =
  [ effectObservation index
      ( "src/validation-kernel/Amoebius/Validation/Documentation.hs"
      , "Amoebius.Validation.Documentation"
      , "readDocument"
      , "exact"
      , "docs/D000.md"
      , "documentation-structure"
      )
  | index <- [0 .. 61]
  ]

entry :: FilePath -> Text -> Text -> Text -> EntryWire
entry path classTag mode objectId = (path, classTag, mode, objectId)

effect :: FilePath -> Text -> Text -> Text -> Text -> Text -> EffectWire
effect modulePath moduleName bindingName targetTag targetValue useTag =
  (modulePath, moduleName, bindingName, targetTag, targetValue, useTag)

pad3 :: Int -> String
pad3 value
  | value < 10 = "00" <> show value
  | value < 100 = "0" <> show value
  | otherwise = show value

expectedPad3 :: Int -> String
expectedPad3 value =
  case show value of
    [digit] -> ['0', '0', digit]
    [tens, units] -> ['0', tens, units]
    digits -> digits

limitObservations :: [Observation]
limitObservations =
  [ Observation "limit.inventory-entries" "64"
  , Observation "limit.resolved-effects" "64"
  , Observation "limit.path-bytes" "1024"
  , Observation "limit.path-depth" "64"
  , Observation "limit.segment-bytes" "255"
  , Observation "limit.field-bytes" "256"
  , Observation "limit.content-bindings" "32"
  , Observation "limit.haskell-subjects" "32"
  , Observation "limit.problems" "32"
  , Observation "limit.result-findings" "46"
  , Observation "limit.result-observations" "218"
  ]

compilerFacts :: [Text]
compilerFacts =
  [ "CompilerParseSucceeded"
  , "ConditionalPreprocessingClosed"
  , "CompileTimeExecutionFeaturesAbsent"
  , "ImportsRenamed"
  , "CallsResolved"
  , "IndirectCallsClosed"
  , "ControlFlowClosed"
  , "FilesystemEffectsClassified"
  , "ExternalProcessAndFfiEffectsClassified"
  , "TrackedContentProvenanceFlowsClosed"
  , "ProductBehaviourSinksClassified"
  , "DynamicCodeAndPluginLoadingAbsent"
  ]

compilerFactObservations :: [Observation]
compilerFactObservations =
  zipWith
    (\index fact -> Observation ("source-consumer.required-fact." <> decimal index) fact)
    [0 :: Int ..]
    compilerFacts

permanentFindings :: [Finding]
permanentFindings =
  [ localFinding
      "SRC-CONSUMER-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.SourceConsumerGraph.sourceConsumerGraphDiagnostic"
      "caller-supplied inventory and effect rows cannot establish source-consumer closure"
  , localFinding
      "SRC-CONSUMER-SOURCE-BINDING-RESIDUE"
      "source-snapshot"
      "an independently authenticated immutable source snapshot is absent"
  ]
    <> [ localFinding
          "SRC-CONSUMER-COMPILER-RESIDUE"
          (Text.unpack fact)
          "this mandatory fact requires an exact source-bound compiler graph and cannot be supplied by a caller effect list"
       | fact <- compilerFacts
       ]

localFinding :: Text -> FilePath -> Text -> Finding
localFinding = Finding

resourceFinding :: Text -> Int -> Int -> Finding
resourceFinding resource limit observed =
  localFinding
    "SRC-CONSUMER-RESOURCE-LIMIT"
    (Text.unpack resource)
    ( resource
        <> " exceeds the "
        <> decimal limit
        <> " bound; observed "
        <> decimal observed
    )

regular, executable, symlinkMode, objectA, objectB, object64, uppercaseObject, mixedObject :: Text
regular = "100644"
executable = "100755"
symlinkMode = "120000"
objectA = Text.replicate 40 "a"
objectB = Text.replicate 40 "b"
object64 = Text.replicate 64 "d"
uppercaseObject = "A" <> Text.replicate 39 "a"
mixedObject = Text.replicate 34 "a" <> "012345"

objectAExpected, objectBExpected, object64Expected, mixedObjectExpected :: Text
objectAExpected = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
objectBExpected = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
object64Expected = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
mixedObjectExpected = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa012345"

canonicalIdentity, canonicalIdentityExpected, mixedIdentity, mixedIdentityExpected, uppercaseIdentity, diagnosticName :: Text
canonicalIdentity = Text.replicate 64 "c"
canonicalIdentityExpected = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
mixedIdentity = Text.replicate 58 "c" <> "012345"
mixedIdentityExpected = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc012345"
uppercaseIdentity = "C" <> Text.replicate 63 "c"
diagnosticName = "source-consumer-graph-diagnostic"

decimal :: Int -> Text
decimal = Text.pack . show

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
