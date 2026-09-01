{-# LANGUAGE OverloadedStrings #-}

module CompilerSourceGraphAcquiredOracle (
    compilerSourceGraphAcquiredSelectorNames,
    runCompilerSourceGraphAcquiredOracle,
    runCompilerSourceGraphAcquiredSelectorImpactOracle,
    runCompilerSourceGraphAcquiredSelectorIsolationOracle,
    runCompilerSourceGraphAcquiredSelectorOracle,
    runCompilerSourceGraphAcquiredSelectorProductControlOracle,
) where

-- This is a direct-source component oracle for the package-hidden acquired
-- seam. It is never linked against the packaged library: the driver compiles
-- this module and the exact production source tree together under one CPP
-- selector. A CPP-only constructor in SourceClosure.Internal exists solely in
-- this component and is absent from the packaged library.

import Amoebius.Validation.CompilerSourceGraph.Internal (
    acquireCompilerSourceGraph,
    acquiredCompilerSnapshotIdentity,
    acquiredCompilerSourceCheck,
    analyzeAcquiredCompilerSourceGraph,
    compilerAcquisitionProblemCode,
    compilerAcquisitionProblemSnapshotIdentity,
    compilerSourceAttemptDiagnostic,
    compilerSourceAttemptProblems,
    compilerSourceInternalTestAcquiredBranchProblems,
    compilerSourceInternalTestClosedGraphProblems,
    compilerSourceInternalTestTypedBindingProjection,
    foldCompilerSourceAttempt,
 )
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    IndexEntry (..),
    IndexMode (RegularFile),
    SourceSnapshot (..),
    TrackedEntry (..),
    sourceClosureInternalTestAcquire,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding,
    Observation,
    finding,
    observation,
 )
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text qualified as Text

data ExactCase = ExactCase String AcquiredSourceSnapshot Text CheckResult

runCompilerSourceGraphAcquiredOracle :: IO ()
runCompilerSourceGraphAcquiredOracle = do
    observedProblems <- fmap concat (mapM runExactCase exactCases)
    attemptProblems <- runTypedAttemptCase
    let problems =
            registryProblems
                <> typedBindingProjectionProblems
                <> closedGraphValidationProblems
                <> acquiredBranchValidationProblems
                <> attemptProblems
                <> observedProblems
    unless (null problems) (failWith "aggregate" problems)

runTypedAttemptCase :: IO [String]
runTypedAttemptCase = do
    attempt <- acquireCompilerSourceGraph simpleAcquired
    let diagnostic = compilerSourceAttemptDiagnostic attempt
        problems = compilerSourceAttemptProblems attempt
        observedCodes = map compilerAcquisitionProblemCode problems
        observedIdentities = map compilerAcquisitionProblemSnapshotIdentity problems
        observedBranch =
            foldCompilerSourceAttempt
                (\_ _ -> "refused" :: Text)
                (\_ _ -> "acquired")
                attempt
    pure
        ( [ "typed attempt did not remain on its refusal branch: " <> show observedBranch
          | observedBranch /= "refused"
          ]
            <> [ "typed attempt changed its diagnostic identity: "
                    <> show (acquiredCompilerSnapshotIdentity diagnostic)
               | acquiredCompilerSnapshotIdentity diagnostic /= "acquired-simple"
               ]
            <> [ "typed attempt changed its exact diagnostic projection"
               | acquiredCompilerSourceCheck diagnostic /= simpleExpected
               ]
            <> [ "typed attempt problem order/boundaries changed: " <> show observedCodes
               | observedCodes /= expectedTypedAttemptCodes
               ]
            <> [ "typed attempt problem escaped its acquired snapshot: " <> show observedIdentities
               | observedIdentities /= replicate (length expectedTypedAttemptCodes) "acquired-simple"
               ]
        )

expectedTypedAttemptCodes :: [Text]
expectedTypedAttemptCodes =
    [ "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
    , "SRC-COMPILER-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE"
    , "SRC-COMPILER-ELABORATED-MULTI-RUN-UNAVAILABLE"
    , "SRC-COMPILER-TOOLCHAIN-UNAUTHENTICATED"
    , "SRC-COMPILER-EXECUTION-UNSUPERVISED"
    , "SRC-COMPILER-SEMANTIC-CLOSURE-UNAVAILABLE"
    ]

acquiredBranchValidationProblems :: [String]
acquiredBranchValidationProblems =
    [ "acquired compiler branch validation changed: "
        <> show compilerSourceInternalTestAcquiredBranchProblems
    | compilerSourceInternalTestAcquiredBranchProblems /= expectedAcquiredBranchProblems
    ]

expectedAcquiredBranchProblems :: [(Text, [Text])]
expectedAcquiredBranchProblems =
    [ ("valid-mixed", [])
    , ("empty", ["SRC-COMPILER-ACQUIRED-RUN-UNIVERSE-EMPTY"])
    ,
        ( "duplicate-plan"
        ,
            [ "SRC-COMPILER-ACQUIRED-RUN-KEY-DUPLICATE"
            , "SRC-COMPILER-ACQUIRED-WITNESS-KEY-DUPLICATE"
            ]
        )
    , ("inventory-mismatch", ["SRC-COMPILER-ACQUIRED-RUN-INVENTORY-MISMATCH"])
    ,
        ( "run-bindings"
        ,
            [ "SRC-COMPILER-ACQUIRED-RUN-SNAPSHOT"
            , "SRC-COMPILER-ACQUIRED-RUN-PATH"
            , "SRC-COMPILER-ACQUIRED-RUN-OBJECT-IDENTITY"
            , "SRC-COMPILER-ACQUIRED-RUN-COMPONENT"
            , "SRC-COMPILER-ACQUIRED-RUN-CONFIGURATION"
            , "SRC-COMPILER-ACQUIRED-RUN-GENERATED-INPUTS"
            , "SRC-COMPILER-ACQUIRED-RUN-ARGV"
            , "SRC-COMPILER-ACQUIRED-RUN-ELABORATION"
            , "SRC-COMPILER-ACQUIRED-RUN-TOOLCHAIN"
            , "SRC-COMPILER-ACQUIRED-RUN-SUPERVISOR"
            ]
        )
    , ("success-facts", ["SRC-COMPILER-ACQUIRED-RUN-SEMANTIC-FACTS"])
    , ("success-product", ["SRC-COMPILER-ACQUIRED-TRANSCRIPT-PRODUCT"])
    , ("refusal-stage", ["SRC-COMPILER-ACQUIRED-RUN-REFUSAL-STAGE"])
    , ("refusal-diagnostic", ["SRC-COMPILER-ACQUIRED-RUN-REFUSAL-DIAGNOSTIC"])
    , ("refusal-signal", ["SRC-COMPILER-ACQUIRED-TRANSCRIPT-SIGNAL"])
    , ("refusal-timeout", ["SRC-COMPILER-ACQUIRED-TRANSCRIPT-TIMEOUT"])
    , ("refusal-output-limit", ["SRC-COMPILER-ACQUIRED-TRANSCRIPT-OUTPUT-LIMIT"])
    , ("fixture-result", ["SRC-COMPILER-ACQUIRED-RUN-FIXTURE-RESULT"])
    , ("fixture-exit", ["SRC-COMPILER-ACQUIRED-TRANSCRIPT-EXIT"])
    , ("wrong-branch", ["SRC-COMPILER-ACQUIRED-RUN-EVIDENCE-BRANCH"])
    ]

closedGraphValidationProblems :: [String]
closedGraphValidationProblems =
    [ "closed compiler graph validation changed: "
        <> show compilerSourceInternalTestClosedGraphProblems
    | compilerSourceInternalTestClosedGraphProblems /= expectedClosedGraphProblems
    ]

expectedClosedGraphProblems :: [(Text, [Text])]
expectedClosedGraphProblems =
    [ ("valid", [])
    , ("wrong-name", ["SRC-COMPILER-ACQUIRED-DIAGNOSTIC-NOT-CLOSED"])
    , ("retained-finding", ["SRC-COMPILER-ACQUIRED-DIAGNOSTIC-NOT-CLOSED"])
    ]

typedBindingProjectionProblems :: [String]
typedBindingProjectionProblems =
    [ "opaque compiler row/witness/facts binding projection changed: "
        <> show compilerSourceInternalTestTypedBindingProjection
    | compilerSourceInternalTestTypedBindingProjection /= expectedTypedBindingProjection
    ]

expectedTypedBindingProjection :: [(Text, Text)]
expectedTypedBindingProjection =
    [ ("success-key", successKeyProjection)
    , ("refusal-key", refusalKeyProjection)
    , ("fixture-key", fixtureKeyProjection)
    , ("success-witness", successWitnessProjection)
    , ("refusal-witness", refusalWitnessProjection)
    , ("fixture-witness", fixtureWitnessProjection)
    ,
        ( "acquired-facts"
        , Text.intercalate
            "\t"
            [ "snapshot-identity"
            , "plan-identity"
            , Text.intercalate ";" [successKeyProjection, refusalKeyProjection, fixtureKeyProjection]
            , Text.intercalate ";" [successWitnessProjection, refusalWitnessProjection, fixtureWitnessProjection]
            ]
        )
    ]

successKeyProjection, refusalKeyProjection, fixtureKeyProjection :: Text
successKeyProjection =
    "snapshot-identity\tsrc/Example.hs\tsource-object-identity\tlib:example\tconfiguration-identity\tgenerated-input-set-identity\texact-compiler-argv-identity\tsuccess"
refusalKeyProjection =
    "snapshot-identity\ttest/compile-negative/Example.hs\tsource-object-identity\ttest:compile-negative-example\tconfiguration-identity\tgenerated-input-set-identity\texact-compiler-argv-identity\trefusal:CompilerTypecheckFailure:expected-diagnostic-identity"
fixtureKeyProjection =
    "snapshot-identity\ttest/ExampleFixture.hs\tsource-object-identity\ttest:example-fixture\tconfiguration-identity\tgenerated-input-set-identity\texact-compiler-argv-identity\tfixture:fixture-harness:fixture-case:expected-result-identity:0"

successWitnessProjection, refusalWitnessProjection, fixtureWitnessProjection :: Text
successWitnessProjection =
    Text.intercalate
        "\t"
        [ "success"
        , successKeyProjection
        , "plan-identity"
        , "verified-toolchain-root-identity"
        , "supervisor-observation-identity"
        , "CompilerExited 0:1:stdout-identity:2:stderr-identity:product-identity:resource-observation-identity"
        , "CompilerParseSucceeded,ConditionalPreprocessingClosed"
        ]
refusalWitnessProjection =
    Text.intercalate
        "\t"
        [ "refusal"
        , refusalKeyProjection
        , "plan-identity"
        , "verified-toolchain-root-identity"
        , "supervisor-observation-identity"
        , "CompilerExited 1:1:stdout-identity:2:stderr-identity:none:resource-observation-identity"
        , "CompilerTypecheckFailure"
        , "expected-diagnostic-identity"
        ]
fixtureWitnessProjection =
    Text.intercalate
        "\t"
        [ "fixture"
        , fixtureKeyProjection
        , "plan-identity"
        , "verified-toolchain-root-identity"
        , "supervisor-observation-identity"
        , "CompilerExited 0:1:stdout-identity:2:stderr-identity:none:resource-observation-identity"
        , "fixture-harness"
        , "fixture-case"
        , "expected-result-identity"
        ]

runCompilerSourceGraphAcquiredSelectorOracle :: String -> IO ()
runCompilerSourceGraphAcquiredSelectorOracle selector =
    case (selectorTargets selector, selectorCases selector) of
        ([target], [candidate]) -> do
            unless (null registryProblems) (failWith "unaffected-control" registryProblems)
            problems <- runExactCase candidate
            unless (null problems) (failWith ("assigned-locus:" <> target) problems)
        (targets, candidates) ->
            failWith
                "unresolvable-selector"
                [ "selector=" <> selector
                , "targets=" <> show targets
                , "exact-case-count=" <> show (length candidates)
                ]

runCompilerSourceGraphAcquiredSelectorImpactOracle :: String -> IO ()
runCompilerSourceGraphAcquiredSelectorImpactOracle selector = do
    unless (null registryProblems) (failWith "declared-impact-control" registryProblems)
    problems <- fmap concat (mapM runExpectedRedCase (selectorAffectedCases selector))
    unless (null problems) (failWith "declared-impact" problems)
  where
    runExpectedRedCase candidate@(ExactCase label _ _ _) = do
        exactProblems <- runExactCase candidate
        pure
            [ "declared impacted exact case remained green: selector="
                <> selector
                <> "; exact-case="
                <> label
            | null exactProblems
            ]

runCompilerSourceGraphAcquiredSelectorIsolationOracle :: String -> IO ()
runCompilerSourceGraphAcquiredSelectorIsolationOracle selector = do
    unless (null registryProblems) (failWith "unaffected-control" registryProblems)
    problems <- fmap concat (mapM runExactCase unaffected)
    unless (null problems) (failWith "unaffected" problems)
  where
    affectedLabels = selectorAffectedCaseLabels selector
    unaffected =
        [ candidate
        | candidate@(ExactCase label _ _ _) <- exactCases
        , label `notElem` affectedLabels
        ]

runCompilerSourceGraphAcquiredSelectorProductControlOracle :: String -> IO ()
runCompilerSourceGraphAcquiredSelectorProductControlOracle selector =
    case selectorCases selector of
        [ExactCase _ acquired expectedIdentity _] -> do
            graph <- analyzeAcquiredCompilerSourceGraph acquired
            let observedIdentity = acquiredCompilerSnapshotIdentity graph
                observedName = checkName (acquiredCompilerSourceCheck graph)
                problems =
                    if selector == "VALIDATION_COMPILER_GRAPH_ACQUIRED_CHECK_NAME_MAPPING_MUTANT"
                        then
                            [ "check-name selector disturbed the independent identity control: selector="
                                <> selector
                                <> "; observed="
                                <> show observedIdentity
                            | observedIdentity /= expectedIdentity
                            ]
                        else
                            [ "assigned fixture lost the independent check-name control: selector="
                                <> selector
                                <> "; observed="
                                <> show observedName
                            | observedName /= "acquired-compiler-source-graph-refusal"
                            ]
            unless
                (null (registryProblems <> problems))
                (failWith "product-control" (registryProblems <> problems))
        candidates ->
            failWith
                "product-control-unresolvable"
                ["selector=" <> selector <> "; exact-case-count=" <> show (length candidates)]

runExactCase :: ExactCase -> IO [String]
runExactCase (ExactCase label acquired expectedIdentity expectedCheck) = do
    graph <- analyzeAcquiredCompilerSourceGraph acquired
    let observedIdentity = acquiredCompilerSnapshotIdentity graph
        observedCheck = acquiredCompilerSourceCheck graph
    pure
        ( [ label <> ": expected identity " <> show expectedIdentity <> ", observed " <> show observedIdentity
          | observedIdentity /= expectedIdentity
          ]
            <> [label <> ": expected " <> show expectedCheck <> ", observed " <> show observedCheck | observedCheck /= expectedCheck]
        )

failWith :: String -> [String] -> IO ()
failWith label problems =
    fail (unlines (("CompilerSourceGraphAcquiredOracle " <> label <> ":") : map ("  " <>) problems))

acquiredMutationIntent :: [(String, String)]
acquiredMutationIntent =
    [
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_LIMIT_WIDEN_MUTANT"
        , "acquired entry maximum plus one refuses before consumer construction"
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT"
        , "acquired source binding retains all five compiler-boundary refusals"
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DROP_MUTANT"
        , "acquired source binding retains all five compiler-boundary refusals"
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DROP_MUTANT"
        , "acquired source binding retains all five compiler-boundary refusals"
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DROP_MUTANT"
        , "acquired source binding retains all five compiler-boundary refusals"
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DROP_MUTANT"
        , "acquired source binding retains all five compiler-boundary refusals"
        )
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_BOUNDED_ENTRIES_PROJECTION_MUTANT", "acquired entry exact maximum reaches the source-consumer diagnostic")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CHECK_NAME_MAPPING_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_FINDINGS_RETENTION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_OBSERVATIONS_RETENTION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_CODE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DETAIL_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_SUBJECT_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_EXCEEDED_MAPPING_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_SUFFIX_MAPPING_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_CODE_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_DETAIL_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_RETENTION_DROP_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_SUBJECT_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXCEEDED_COMPOSITION_MAPPING_MUTANT", "acquired entry maximum plus one refuses before consumer construction")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_CODE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DETAIL_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_SUBJECT_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_FINDING_COMPOSITION_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_LOCAL_OBSERVATION_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_MANDATORY_FINDING_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_OBSERVATION_COMPOSITION_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_REFUSAL_FINDINGS_RETENTION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_FINDING_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_OBSERVATION_ORDER_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_CODE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DETAIL_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_SUBJECT_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_MAPPING_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_PROJECTION_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SOURCE_CHECK_PROJECTION_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_IDENTITY_ASSEMBLY_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_RESULT_ASSEMBLY_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_CODE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DETAIL_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_SUBJECT_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_DROP_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_NAME_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_VALUE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_CODE_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DETAIL_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_SUBJECT_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_COMPOSITION_MAPPING_MUTANT", "acquired source binding retains all five compiler-boundary refusals")
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_ENTRY_COUNT_MAPPING_MUTANT", "acquired entry exact maximum reaches the source-consumer diagnostic")
    ]

acquiredSelectorDependentCaseLabels :: [(String, [String])]
acquiredSelectorDependentCaseLabels =
    [ ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_LIMIT_WIDEN_MUTANT", [])
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT"
        ,
            [ "acquired entry exact maximum reaches the source-consumer diagnostic"
            , "acquired entry maximum plus one refuses before consumer construction"
            ]
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DROP_MUTANT"
        ,
            [ "acquired entry exact maximum reaches the source-consumer diagnostic"
            , "acquired entry maximum plus one refuses before consumer construction"
            ]
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DROP_MUTANT"
        ,
            [ "acquired entry exact maximum reaches the source-consumer diagnostic"
            , "acquired entry maximum plus one refuses before consumer construction"
            ]
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DROP_MUTANT"
        ,
            [ "acquired entry exact maximum reaches the source-consumer diagnostic"
            , "acquired entry maximum plus one refuses before consumer construction"
            ]
        )
    ,
        ( "VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DROP_MUTANT"
        ,
            [ "acquired entry exact maximum reaches the source-consumer diagnostic"
            , "acquired entry maximum plus one refuses before consumer construction"
            ]
        )
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_BOUNDED_ENTRIES_PROJECTION_MUTANT", ["acquired source binding retains all five compiler-boundary refusals"])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CHECK_NAME_MAPPING_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_FINDINGS_RETENTION_DROP_MUTANT", ["acquired entry exact maximum reaches the source-consumer diagnostic"])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_OBSERVATIONS_RETENTION_DROP_MUTANT", ["acquired entry exact maximum reaches the source-consumer diagnostic"])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_CODE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DETAIL_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_SUBJECT_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_EXCEEDED_MAPPING_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_SUFFIX_MAPPING_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_CODE_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_DETAIL_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_RETENTION_DROP_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_SUBJECT_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXCEEDED_COMPOSITION_MAPPING_MUTANT", [])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_CODE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DETAIL_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_SUBJECT_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_FINDING_COMPOSITION_ORDER_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_LOCAL_OBSERVATION_ORDER_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_MANDATORY_FINDING_ORDER_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_OBSERVATION_COMPOSITION_ORDER_MUTANT", ["acquired entry exact maximum reaches the source-consumer diagnostic"])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_REFUSAL_FINDINGS_RETENTION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_FINDING_ORDER_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_OBSERVATION_ORDER_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_CODE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DETAIL_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_SUBJECT_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_MAPPING_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_PROJECTION_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SOURCE_CHECK_PROJECTION_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_IDENTITY_ASSEMBLY_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_RESULT_ASSEMBLY_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_CODE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DETAIL_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_SUBJECT_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_DROP_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_NAME_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_VALUE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_CODE_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DETAIL_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_SUBJECT_MUTANT", allOtherAcquiredCases)
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_COMPOSITION_MAPPING_MUTANT", ["acquired entry exact maximum reaches the source-consumer diagnostic"])
    , ("VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_ENTRY_COUNT_MAPPING_MUTANT", ["acquired source binding retains all five compiler-boundary refusals"])
    ]

allOtherAcquiredCases :: [String]
allOtherAcquiredCases =
    [ "acquired entry exact maximum reaches the source-consumer diagnostic"
    , "acquired entry maximum plus one refuses before consumer construction"
    ]

compilerSourceGraphAcquiredSelectorNames :: [String]
compilerSourceGraphAcquiredSelectorNames = map fst acquiredMutationIntent

selectorTargets :: String -> [String]
selectorTargets selector =
    [target | (candidate, target) <- acquiredMutationIntent, candidate == selector]

selectorCases :: String -> [ExactCase]
selectorCases selector =
    [ candidate
    | target <- selectorTargets selector
    , candidate@(ExactCase label _ _ _) <- exactCases
    , label == target
    ]

selectorAffectedCaseLabels :: String -> [String]
selectorAffectedCaseLabels selector =
    selectorTargets selector
        <> concat [labels | (candidate, labels) <- acquiredSelectorDependentCaseLabels, candidate == selector]

selectorAffectedCases :: String -> [ExactCase]
selectorAffectedCases selector =
    [ candidate
    | label <- selectorAffectedCaseLabels selector
    , candidate@(ExactCase candidateLabel _ _ _) <- exactCases
    , candidateLabel == label
    ]

registryProblems :: [String]
registryProblems =
    [ "expected 70 acquired mutation-intent rows, observed " <> show (length acquiredMutationIntent)
    | length acquiredMutationIntent /= 70
    ]
        <> ["duplicate acquired selector " <> selector | selector <- duplicates (map fst acquiredMutationIntent)]
        <> ["duplicate acquired exact-case label " <> label | label <- duplicates exactCaseLabels]
        <> [ "expected 70 acquired dependency rows, observed " <> show (length acquiredSelectorDependentCaseLabels)
           | length acquiredSelectorDependentCaseLabels /= 70
           ]
        <> [ "acquired dependency selector registry is not two-way complete"
           | map fst acquiredSelectorDependentCaseLabels /= map fst acquiredMutationIntent
           ]
        <> [ "acquired selector target must name exactly one executable exact case: "
                <> selector
                <> " -> "
                <> target
                <> "; observed "
                <> show count
           | (selector, target) <- acquiredMutationIntent
           , let count = length (filter (== target) exactCaseLabels)
           , count /= 1
           ]
        <> [ "acquired dependent exact case must occur exactly once: "
                <> selector
                <> " -> "
                <> label
           | (selector, labels) <- acquiredSelectorDependentCaseLabels
           , label <- labels
           , length (filter (== label) exactCaseLabels) /= 1
           ]
        <> [ "acquired primary/dependent overlap: " <> selector <> " -> " <> label
           | (selector, labels) <- acquiredSelectorDependentCaseLabels
           , label <- labels
           , label `elem` selectorTargets selector
           ]
  where
    exactCaseLabels = [label | ExactCase label _ _ _ <- exactCases]

duplicates :: (Eq value) => [value] -> [value]
duplicates = go []
  where
    go _ [] = []
    go seen (value : remaining)
        | value `elem` seen = value : go seen remaining
        | otherwise = go (value : seen) remaining

exactCases :: [ExactCase]
exactCases =
    [ ExactCase
        "acquired source binding retains all five compiler-boundary refusals"
        simpleAcquired
        "acquired-simple"
        simpleExpected
    , ExactCase
        "acquired entry exact maximum reaches the source-consumer diagnostic"
        acquiredMaximum
        "acquired-maximum"
        maximumExpected
    , ExactCase
        "acquired entry maximum plus one refuses before consumer construction"
        acquiredMaximumPlusOne
        "acquired-maximum-plus-one"
        maximumPlusOneExpected
    ]

simpleExpected, maximumExpected, maximumPlusOneExpected :: CheckResult
simpleExpected =
    CheckResult
        { checkName = "acquired-compiler-source-graph-refusal"
        , checkObservations =
            consumerLimitObservations
                <> [ observation "source-consumer.snapshot" "acquired-simple"
                   , observation "source-consumer.binding-count" "1"
                   , observation "source-consumer.pending-haskell-count" "1"
                   , observation
                        "source-consumer.binding.amoebius.cabal"
                        "CabalPackageDescription\tHaskellSourceBoundaryStructureChecker,HaskellRepositoryRootLocator,CabalBuildTool"
                   , observation
                        "source-consumer.pending-haskell.A.hs"
                        "100644\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                   ]
                <> acquiredObservations
                    "acquired-simple"
                    "2"
                    "source-consumer-diagnostic-only"
        , checkFindings =
            [ finding
                "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
                "."
                ( "snapshot acquired-simple has 1 exact Haskell subjects but lacks compiler-derived facts: "
                    <> requiredFactsText
                )
            ]
                <> acquiredRefusalFindings
        }
maximumExpected =
    CheckResult
        { checkName = "acquired-compiler-source-graph-refusal"
        , checkObservations =
            consumerLimitObservations
                <> [ observation "source-consumer.snapshot" "acquired-maximum"
                   , observation "source-consumer.binding-count" "0"
                   , observation "source-consumer.pending-haskell-count" "0"
                   ]
                <> acquiredObservations
                    "acquired-maximum"
                    "16384"
                    "source-consumer-diagnostic-only"
        , checkFindings =
            [ finding
                "SRC-CONSUMER-EMPTY-HASKELL"
                "."
                "the compiler graph cannot be closed over an empty Haskell subject inventory"
            , finding
                "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
                "."
                ( "snapshot acquired-maximum has 0 exact Haskell subjects but lacks compiler-derived facts: "
                    <> requiredFactsText
                )
            ]
                <> acquiredRefusalFindings
        }
maximumPlusOneExpected =
    CheckResult
        { checkName = "acquired-compiler-source-graph-refusal"
        , checkObservations =
            acquiredObservations
                "acquired-maximum-plus-one"
                "16385+"
                "refused-before-source-consumer-diagnostic"
        , checkFindings =
            [ finding
                "SRC-COMPILER-ACQUIRED-ENTRY-LIMIT"
                "compiler-source-graph"
                "limit=16384; observed-at-least=16385"
            ]
                <> acquiredRefusalFindings
        }

acquiredObservations :: Text -> Text -> Text -> [Observation]
acquiredObservations identity count composition =
    [ observation "source-compiler.snapshot" identity
    , observation "source-compiler.inventory-entry-count" count
    , observation "source-compiler.consumer-graph-composition" composition
    , observation "source-compiler.subject-role-registry" "refused"
    , observation "source-compiler.elaborated-multi-run-plan" "absent"
    , observation "source-compiler.toolchain-authentication" "absent"
    , observation "source-compiler.execution" "not-attempted"
    , observation "source-compiler.semantic-closure" "absent"
    ]

consumerLimitObservations :: [Observation]
consumerLimitObservations =
    [ observation "limit.snapshot-entries" "16384"
    , observation "limit.resolved-effects" "64"
    , observation "limit.consumer-graph-problems" "128"
    , observation "limit.result-observations" "16392"
    , observation "limit.result-findings" "129"
    ]

acquiredRefusalFindings :: [Finding]
acquiredRefusalFindings =
    [ finding
        "SRC-COMPILER-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE"
        "compiler-source-graph"
        "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is two-way complete against the acquired .hs inventory"
    , finding
        "SRC-COMPILER-ELABORATED-MULTI-RUN-UNAVAILABLE"
        "compiler-source-graph"
        "no authenticated Cabal elaboration binds every component, flag vector, generated input, compiler argument, and expected compile-refusal run"
    , finding
        "SRC-COMPILER-TOOLCHAIN-UNAUTHENTICATED"
        "compiler-source-graph"
        "the compiler executable, libdir, package databases, dependencies, and build-info inputs have no independent authenticated network-independent observation"
    , finding
        "SRC-COMPILER-EXECUTION-UNSUPERVISED"
        "compiler-source-graph"
        "no challenged source-bound Haskell supervisor has bounded compiler time, memory, output, filesystem inputs, and process identity"
    , finding
        "SRC-COMPILER-SEMANTIC-CLOSURE-UNAVAILABLE"
        "compiler-source-graph"
        "resolved calls, indirect calls, control flow, effects, tracked-content provenance, behaviour sinks, and dynamic loading are not completely established"
    ]

requiredFactsText :: Text
requiredFactsText =
    "CompilerParseSucceeded,ConditionalPreprocessingClosed,CompileTimeExecutionFeaturesAbsent,ImportsRenamed,CallsResolved,IndirectCallsClosed,ControlFlowClosed,FilesystemEffectsClassified,ExternalProcessAndFfiEffectsClassified,TrackedContentProvenanceFlowsClosed,ProductBehaviourSinksClassified,DynamicCodeAndPluginLoadingAbsent"

simpleAcquired, acquiredMaximum, acquiredMaximumPlusOne :: AcquiredSourceSnapshot
simpleAcquired = acquiredFixture "acquired-simple" simpleEntries
acquiredMaximum = acquiredFixture "acquired-maximum" (boundaryEntries 16384)
acquiredMaximumPlusOne = acquiredFixture "acquired-maximum-plus-one" (boundaryEntries 16385)

acquiredFixture :: Text -> [TrackedEntry] -> AcquiredSourceSnapshot
acquiredFixture identity entries =
    sourceClosureInternalTestAcquire
        SourceSnapshot
            { snapshotRoot = "/oracle/acquired"
            , snapshotIdentity = identity
            , snapshotEntries = entries
            }

simpleEntries :: [TrackedEntry]
simpleEntries =
    [ tracked "A.hs" "module A where\n"
    , tracked "amoebius.cabal" "cabal-version: 3.0\n"
    ]

boundaryEntries :: Int -> [TrackedEntry]
boundaryEntries count =
    [tracked ("opaque/entry-" <> pad5 ordinal <> ".bin") "x" | ordinal <- [0 .. count - 1]]

tracked :: FilePath -> ByteString -> TrackedEntry
tracked path bytes =
    TrackedEntry
        { trackedIndex = IndexEntry path RegularFile (Text.replicate 40 "a")
        , trackedBytes = bytes
        }

pad5 :: Int -> String
pad5 value = replicate (5 - length rendered) '0' <> rendered
  where
    rendered = show value
