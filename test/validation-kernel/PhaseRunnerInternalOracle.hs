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
        -- The registry is asserted by shape, not by census. Enumerating its exact
        -- contents made every newly implemented capability redden this oracle,
        -- and because the gate chain re-derives gate 0 inside every later
        -- phase's gate, implementing a runner reopened a closed Phase 0 — the
        -- registry being the one place that must change when a phase is built.
        <> expectEqual
            "production registry declares its closed kind"
            [("phase-runner.registry-kind", "closed capability-keyed list")]
            [ (observationKey item, observationValue item)
            | item <- checkObservations phaseRunnerRegistryCheck
            , observationKey item == "phase-runner.registry-kind"
            ]
        <> expectEqual
            "the documentation-suite capability is registered"
            [("phase-runner.documentation_suite", "DocumentationSuiteRunner")]
            [ (observationKey item, observationValue item)
            | item <- checkObservations phaseRunnerRegistryCheck
            , observationKey item == "phase-runner.documentation_suite"
            ]

-- | Either a single registered runner, or the absent-runner refusal reported
-- against that ordinal's own subject.
resolvesOrRefusesExactly :: Int -> Bool
resolvesOrRefusesExactly ordinal =
    case selectPhaseRunner ordinal of
        Right _ -> True
        Left problem ->
            findingCode problem == "PHASE-RUNNER-ABSENT"
                && findingSubject problem == ("phase-" <> show ordinal)

productionSelectionProblems :: [String]
productionSelectionProblems =
    expectEqual
        "Phase 0 selects the one documentation-suite runner"
        (Right DocumentationSuiteRunner)
        (selectPhaseRunner 0)
        -- Every ordinal in the closed domain either resolves to exactly one
        -- runner or refuses by naming its own capability. Which ordinals are
        -- implemented is the frontier, and the frontier moves; enumerating it
        -- here would make building a runner a refusal.
        <> concat
            [ [ "ordinal "
                  <> show ordinal
                  <> " neither resolved to a runner nor refused with PHASE-RUNNER-ABSENT at its own subject"
              | not (resolvesOrRefusesExactly ordinal)
              ]
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
