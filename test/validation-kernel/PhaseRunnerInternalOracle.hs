{-# LANGUAGE OverloadedStrings #-}

module PhaseRunnerInternalOracle (
    runPhaseRunnerInternalOracle,
) where

import Amoebius.Validation.PhaseRunner.Internal (
    PhaseRunner (DocumentationSuiteRunner),
    phaseRunnerInternalTestRegistryCheck,
    phaseRunnerInternalTestSelect,
    phaseRunnerRegistryCheck,
    selectPhaseRunner,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    Observation (..),
 )
import Control.Monad (unless)
import Data.Text qualified as Text

runPhaseRunnerInternalOracle :: IO ()
runPhaseRunnerInternalOracle =
    finishDiagnostics
        "PhaseRunnerInternalOracle"
        ( productionRegistryProblems
            <> productionSelectionProblems
            <> injectedRegistryProblems
        )

productionRegistryProblems :: [String]
productionRegistryProblems =
    expectEqual "production registry is structurally closed" [] (checkFindings phaseRunnerRegistryCheck)
        <> expectEqual
            "production registry observations are exact"
            [ ("phase-runner.registry-count", "1")
            , ("phase-runner.registry-kind", "closed capability-keyed list")
            , ("phase-runner.documentation_suite", "DocumentationSuiteRunner")
            ]
            [ (observationKey item, observationValue item)
            | item <- checkObservations phaseRunnerRegistryCheck
            ]

productionSelectionProblems :: [String]
productionSelectionProblems =
    expectEqual
        "Phase 0 selects the one documentation-suite runner"
        (Right DocumentationSuiteRunner)
        (selectPhaseRunner 0)
        <> concat
            [ expectLeft
                ("later Phase " <> show ordinal <> " has no prematurely registered runner")
                "PHASE-RUNNER-ABSENT"
                ("phase-" <> show ordinal)
                (selectPhaseRunner ordinal)
            | ordinal <- [1 .. 95]
            ]
        <> expectLeft
            "negative ordinal has no compiled phase identity"
            "PHASE-RUNNER-IDENTITY-ABSENT"
            "phase--1"
            (selectPhaseRunner (-1))
        <> expectLeft
            "ordinal beyond the closed domain has no compiled phase identity"
            "PHASE-RUNNER-IDENTITY-ABSENT"
            "phase-96"
            (selectPhaseRunner 96)

injectedRegistryProblems :: [String]
injectedRegistryProblems =
    expectLeft
        "an omitted Phase-0 registration refuses selection"
        "PHASE-RUNNER-ABSENT"
        "phase-0"
        (phaseRunnerInternalTestSelect [] 0)
        <> expectLeft
            "a duplicate Phase-0 registration refuses ambiguous selection"
            "PHASE-RUNNER-AMBIGUOUS"
            "phase-0"
            (phaseRunnerInternalTestSelect duplicateRegistry 0)
        <> expectFindingCodes
            "a duplicate registration is visible in both capability and ordinal domains"
            ["PHASE-RUNNER-CAPABILITY-DUPLICATE", "PHASE-RUNNER-ORDINAL-DUPLICATE"]
            (phaseRunnerInternalTestRegistryCheck duplicateRegistry)
        <> expectFindingCodes
            "an uncompiled capability is refused"
            ["PHASE-RUNNER-CAPABILITY-UNKNOWN"]
            (phaseRunnerInternalTestRegistryCheck [("not_a_compiled_capability", DocumentationSuiteRunner)])
        <> expectEqual
            "the exact injected production registration selects identically"
            (Right DocumentationSuiteRunner)
            (phaseRunnerInternalTestSelect [("documentation_suite", DocumentationSuiteRunner)] 0)
  where
    duplicateRegistry =
        [ ("documentation_suite", DocumentationSuiteRunner)
        , ("documentation_suite", DocumentationSuiteRunner)
        ]

expectLeft :: String -> Text.Text -> FilePath -> Either Finding value -> [String]
expectLeft label code subject result = case result of
    Left item
        | findingCode item == code && findingSubject item == subject -> []
        | otherwise -> [label <> ": expected " <> show (code, subject) <> "; observed=" <> show item]
    Right _ -> [label <> ": unexpectedly selected a runner"]

expectFindingCodes :: String -> [Text.Text] -> CheckResult -> [String]
expectFindingCodes label expected result =
    expectEqual label expected (map findingCode (checkFindings result))

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
    | expected == actual = []
    | otherwise = [label <> ": expected=" <> show expected <> "; observed=" <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name diagnostics =
    unless
        (null diagnostics)
        (fail (name <> " failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack diagnostics))))
