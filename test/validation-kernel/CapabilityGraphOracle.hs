{-# LANGUAGE OverloadedStrings #-}

{- | Independent expectations for the typed capability graph.

The graph exists to make forward dependencies findable. The six former
misorderings are now closed by assigning phase-local compile-negative and
generated-fake boundaries to their actual consumers. Phase 0's compiler is an
explicit GenesisTrust/local-custody assumption below the numbered plan, while
the later work its finite gate excludes is carried as declared, non-gating
residue.
This oracle asserts four independent projections:

  * the current typed relation has exactly nine declared forward-residue edges,
    no forward gate prerequisite, and no cycle;
  * omitting their declarations fails closed;
  * each removed Forward-deferred reach is rejected as stale;
  * an unrelated Phase-0 declaration is likewise rejected as stale.

Together they prove that the finite gate has no forward prerequisite, that
each exclusion is explicit, and that declarations do not hide the six removed
misorderings.

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
        ( "CapabilityGraphOracle: the capability relation has nine declared non-gating residue edges across three reaches and no forward gate prerequisite; "
            <> "omitted or stale declarations are rejected, and GenesisTrust/local-custody is a non-numbered bootstrap root. "
            <> "No cycle, no unknown provider or consumer. A typed relation, not a gate result."
        )

-- | Authored from the plan's current state, not captured from the module.
expectedObservations :: [(Text, Text)]
expectedObservations =
    [ ("capability.provision-count", "30")
    , ("capability.edge-count", "60")
    , ("capability.confirmed-edge-count", "60")
    , ("capability.proposed-edge-count", "0")
    , ("capability.gate-prerequisite-edge-count", "51")
    , ("capability.deferred-residue-edge-count", "9")
    , ("capability.bootstrap-root-count", "1")
    , ("capability.consumer-phase-count", "48")
    , ("capability.declared-coverage", "48/96")
    , ("capability.forward-edge-count", "9")
    , ("capability.forward-gate-prerequisite-count", "0")
    , ("capability.forward-deferred-residue-count", "9")
    , ("capability.forward-declared-count", "9")
    , ("capability.forward-undeclared-count", "0")
    , ("capability.forward-declaration-count", "3")
    , ("capability.owned-cycle-count", "0")
    , ("capability.unowned-cycle-count", "0")
    ]

-- | Restated independently from the Phase-0 document and graph implementation.
canonicalResidueDeclarations :: [(Int, Int)]
canonicalResidueDeclarations = [(0, 1), (0, 2), (0, 49)]

cleanCapabilityGraph :: CheckResult
cleanCapabilityGraph = capabilityGraphDiagnosticWith canonicalResidueDeclarations

-- | One declaration fans out to every exact later-owned capability in that phase.
omittedCanonicalCases :: [((Int, Int), Int)]
omittedCanonicalCases = [((0, 1), 1), ((0, 2), 2), ((0, 49), 6)]

{- | The six removed plan reaches, restated independently rather than read back
from the implementation.
-}
removedReaches :: [(Int, Int)]
removedReaches = [(3, 15), (5, 15), (6, 15), (7, 15), (10, 15), (34, 47)]

{- | Introduce an unrelated Phase-0-to-Phase-3 declaration as a negative. The
graph must distinguish an explicit finite-gate exclusion from an arbitrary
ordinal reach.
-}
stalePhaseDependencyDeclarations :: [(Int, Int)]
stalePhaseDependencyDeclarations = canonicalResidueDeclarations <> ((0, 3) : removedReaches)

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
observedValue = observedValueFrom cleanCapabilityGraph

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
        <> [ "omitting the three Phase-0 residue declarations did not fail closed for all nine edges: "
                <> show [(Text.unpack (findingCode item), Text.unpack (findingSubjectText item)) | item <- undeclaredResidueFindings]
           | map findingCode undeclaredResidueFindings /= replicate 9 "PLAN-CAPABILITY-DEFERRED-UNDECLARED"
                || map findingSubjectText undeclaredResidueFindings /= replicate 9 "documentation_suite"
           ]
        <> [ "omitting canonical declaration "
                <> show omitted
                <> " did not expose its exact "
                <> show expectedCount
                <> " residue edge(s): "
                <> show [(Text.unpack (findingCode item), Text.unpack (findingSubjectText item)) | item <- omittedFindings]
           | (omitted, expectedCount) <- omittedCanonicalCases
           , let omittedFindings =
                    checkFindings
                        ( capabilityGraphDiagnosticWith
                            (filter (/= omitted) canonicalResidueDeclarations)
                        )
           , map findingCode omittedFindings /= replicate expectedCount "PLAN-CAPABILITY-DEFERRED-UNDECLARED"
                || map findingSubjectText omittedFindings /= replicate expectedCount "documentation_suite"
           ]
        <> [ "the six removed reaches were not rejected as stale declarations: "
                <> show [(Text.unpack (findingCode item), Text.unpack (findingSubjectText item)) | item <- removedDeclarationFindings]
           | map findingCode removedDeclarationFindings /= replicate 6 "PLAN-FORWARD-DECLARATION-UNMATCHED"
                || map findingSubjectText removedDeclarationFindings /= removedDeclarationSubjects
           ]
        <> [ "stale declarations changed the clean graph's nine forward-residue observations"
           | observedValueFrom removedDeclarationResult "capability.forward-edge-count" /= "9"
                || observedValueFrom removedDeclarationResult "capability.forward-declaration-count" /= "9"
                || observedValueFrom removedDeclarationResult "capability.forward-declared-count" /= "9"
           ]
        <> [ "the unrelated Phase-0-to-Phase-3 declaration and six removed reaches must all be stale, observed "
                <> show
                    [ (Text.unpack (findingCode item), Text.unpack (findingSubjectText item))
                    | item <- staleDependencyFindings
                    ]
           | map findingCode staleDependencyFindings /= replicate 7 "PLAN-FORWARD-DECLARATION-UNMATCHED"
                || map findingSubjectText staleDependencyFindings /= "phase 00" : removedDeclarationSubjects
           ]
  where
    allFindings = checkFindings cleanCapabilityGraph
    undeclaredResidueFindings = checkFindings capabilityGraphDiagnostic
    removedDeclarationResult = capabilityGraphDiagnosticWith (canonicalResidueDeclarations <> removedReaches)
    removedDeclarationFindings = checkFindings removedDeclarationResult
    staleDependencyFindings = checkFindings (capabilityGraphDiagnosticWith stalePhaseDependencyDeclarations)
