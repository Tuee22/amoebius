{-# LANGUAGE OverloadedStrings #-}

{- | Independent expectations for the typed capability graph.

The graph exists to make forward dependencies findable. The six former
misorderings are now closed by assigning phase-local compile-negative and
generated-fake boundaries to their actual consumers. The former
Phase-0-to-Phase-1 edge is an authenticated, non-numbered bootstrap input.
This oracle asserts three independent projections:

  * the current typed relation has no forward edge or cycle;
  * each removed Forward-deferred reach is rejected as stale;
  * the former Phase-0-to-Phase-1 declaration is likewise rejected as stale.

Together they prove that the remediation removed the dependencies rather
than hiding them with declarations.

The essential pairs below are restated independently, not read back from
'Amoebius.Validation.Documentation.Internal.forwardDeferredDeclarations'.
-}
module CapabilityGraphOracle (
    runCapabilityGraphOracle,
) where

import Amoebius.Validation.CapabilityGraph (
    capabilityGraphDiagnostic,
    capabilityGraphDiagnosticWith,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    Observation (..),
 )
import Control.Monad (unless)
import Data.Text (Text)
import Data.Text qualified as Text

findingSubjectText :: Finding -> Text
findingSubjectText = Text.pack . findingSubject

runCapabilityGraphOracle :: IO ()
runCapabilityGraphOracle = do
    let problems = observationProblems <> findingProblems
    unless (null problems) $
        fail (unlines ("CapabilityGraphOracle component diagnostics failed:" : map ("  " <>) problems))
    putStrLn
        ( "CapabilityGraphOracle: the capability relation has no forward edge; "
            <> "the six removed reaches are stale declarations, and the authenticated compiler is a non-numbered bootstrap root. "
            <> "No cycle, no unknown provider or consumer. A typed relation, not a gate result."
        )

-- | Authored from the plan's current state, not captured from the module.
expectedObservations :: [(Text, Text)]
expectedObservations =
    [ ("capability.provision-count", "29")
    , ("capability.edge-count", "100")
    , ("capability.confirmed-edge-count", "100")
    , ("capability.proposed-edge-count", "0")
    , ("capability.gate-prerequisite-edge-count", "100")
    , ("capability.deferred-residue-edge-count", "0")
    , ("capability.bootstrap-root-count", "1")
    , ("capability.consumer-phase-count", "96")
    , ("capability.declared-coverage", "96/96")
    , ("capability.forward-edge-count", "0")
    , ("capability.forward-gate-prerequisite-count", "0")
    , ("capability.forward-deferred-residue-count", "0")
    , ("capability.forward-declared-count", "0")
    , ("capability.forward-undeclared-count", "0")
    , ("capability.forward-declaration-count", "0")
    , ("capability.owned-cycle-count", "0")
    , ("capability.unowned-cycle-count", "0")
    ]

{- | The six removed plan reaches, restated independently rather than read back
from the implementation.
-}
removedReaches :: [(Int, Int)]
removedReaches = [(3, 15), (5, 15), (6, 15), (7, 15), (10, 15), (34, 47)]

{- | Reintroduce the former Phase-0-to-Phase-1 declaration as a negative. The
bootstrap-root correction must make it stale instead of silently treating
the compiler as a phase provision again.
-}
formerPhaseDependencyDeclarations :: [(Int, Int)]
formerPhaseDependencyDeclarations = (0, 1) : removedReaches

removedDeclarationSubjects :: [Text]
removedDeclarationSubjects = ["phase 03", "phase 05", "phase 06", "phase 07", "phase 10", "phase 34"]

observationProblems :: [String]
observationProblems =
    [ "observation "
        <> Text.unpack key
        <> ": expected "
        <> Text.unpack expected
        <> ", observed "
        <> Text.unpack (observedValue key)
    | (key, expected) <- expectedObservations
    , observedValue key /= expected
    ]

observedValue :: Text -> Text
observedValue = observedValueFrom capabilityGraphDiagnostic

observedValueFrom :: CheckResult -> Text -> Text
observedValueFrom result key =
    case [observationValue item | item <- checkObservations result, observationKey item == key] of
        [value] -> value
        _ -> "<absent-or-duplicated>"

findingProblems :: [String]
findingProblems =
    [ "the clean capability relation emitted findings: "
        <> show [(Text.unpack (findingCode item), Text.unpack (findingSubjectText item)) | item <- allFindings]
    | not (null allFindings)
    ]
        <> [ "the six removed reaches were not rejected as stale declarations: "
                <> show [(Text.unpack (findingCode item), Text.unpack (findingSubjectText item)) | item <- removedDeclarationFindings]
           | map findingCode removedDeclarationFindings /= replicate 6 "PLAN-FORWARD-DECLARATION-UNMATCHED"
                || map findingSubjectText removedDeclarationFindings /= removedDeclarationSubjects
           ]
        <> [ "stale declarations changed the clean graph's zero forward-edge observations"
           | observedValueFrom removedDeclarationResult "capability.forward-edge-count" /= "0"
                || observedValueFrom removedDeclarationResult "capability.forward-declaration-count" /= "6"
           ]
        <> [ "the former Phase-0-to-Phase-1 declaration and six removed reaches must all be stale, observed "
                <> show
                    [ (Text.unpack (findingCode item), Text.unpack (findingSubjectText item))
                    | item <- formerDependencyFindings
                    ]
           | map findingCode formerDependencyFindings /= replicate 7 "PLAN-FORWARD-DECLARATION-UNMATCHED"
                || map findingSubjectText formerDependencyFindings /= "phase 00" : removedDeclarationSubjects
           ]
  where
    allFindings = checkFindings capabilityGraphDiagnostic
    removedDeclarationResult = capabilityGraphDiagnosticWith removedReaches
    removedDeclarationFindings = checkFindings removedDeclarationResult
    formerDependencyFindings = checkFindings (capabilityGraphDiagnosticWith formerPhaseDependencyDeclarations)
