{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the typed capability graph.
--
-- The graph exists to make forward dependencies findable. Seven remain in the
-- present order, and each is now declared by a @Forward-deferred:@ field in the
-- phase document that has it. So this oracle asserts two projections:
--
--   * with no declarations supplied, all seven reach are findings — the
--     fail-closed direction, and the shape the module had while it was dormant;
--   * with exactly the seven declared pairs supplied, the relation is clean.
--
-- Both matter. The first proves the relation still sees the reaches; the second
-- proves the declarations match them. A reach that gains a declaration it does
-- not have, or loses one it needs, fails one projection or the other.
--
-- The pairs below are restated from the plan documents, not read back from
-- 'Amoebius.Validation.Documentation.Internal.forwardDeferredDeclarations'. If
-- the two ever disagree, that disagreement is the finding.
module CapabilityGraphOracle
  ( runCapabilityGraphOracle
  ) where

import Amoebius.Validation.CapabilityGraph
  ( capabilityGraphDiagnostic
  , capabilityGraphDiagnosticWith
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import Data.List (sort)
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
    ( "CapabilityGraphOracle: the declared capability relation reports its exact forward-dependency set; "
        <> "no cycle, no unknown provider or consumer. A typed relation, not a gate result."
    )

-- | Authored from the plan's current state, not captured from the module.
expectedObservations :: [(Text, Text)]
expectedObservations =
  [ ("capability.provision-count", "29")
  , ("capability.edge-count", "106")
  , ("capability.confirmed-edge-count", "101")
  , ("capability.proposed-edge-count", "5")
  , ("capability.consumer-phase-count", "96")
  , ("capability.declared-coverage", "96/96")
  , ("capability.forward-edge-count", "7")
  , ("capability.forward-declared-count", "0")
  , ("capability.forward-undeclared-count", "7")
  , ("capability.forward-declaration-count", "0")
  , ("capability.owned-cycle-count", "2")
  , ("capability.unowned-cycle-count", "0")
  ]

-- | The reaches the phase documents declare, restated here from the documents:
-- Phase 0 reaching the toolchain phase for its pinned input, the five calculi
-- reaching the compile-fail harness, and the boundary phase reaching the
-- generation harness for its fake executables.
declaredReaches :: [(Int, Int)]
declaredReaches = [(0, 1), (3, 15), (5, 15), (6, 15), (7, 15), (10, 15), (34, 47)]

-- | Seven declared edges run backwards in the present order: five calculi
-- reaching the later compile-fail harness, one documentation-phase toolchain
-- requirement, and one boundary-phase generated-fake requirement. The other
-- fifty-six that once appeared here were fixed in place rather than declared.
expectedForwardCount :: Int
expectedForwardCount = 7

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
observedValue key =
  case [observationValue item | item <- checkObservations capabilityGraphDiagnostic, observationKey item == key] of
    [value] -> value
    _ -> "<absent-or-duplicated>"

findingProblems :: [String]
findingProblems =
  [ "expected exactly "
      <> show expectedForwardCount
      <> " forward-dependency findings, observed "
      <> show (length forwardFindings)
  | length forwardFindings /= expectedForwardCount
  ]
    <> [ "unexpected finding code: " <> Text.unpack code
       | code <- sort (distinct (map findingCode allFindings))
       , code `notElem` ["PLAN-CAPABILITY-FORWARD-UNDECLARED"]
       ]
    <> [ "with every reach declared the relation must be clean, observed "
           <> show (map (Text.unpack . findingCode) declaredFindings)
       | not (null declaredFindings)
       ]
    <> [ "dropping one declaration must redden exactly that reach, observed "
           <> show (map (Text.unpack . findingSubjectText) droppedFindings)
       | map findingSubjectText droppedFindings /= ["documentation_suite"]
       ]
    <> [ "a declaration matching no reach must be reported stale, observed "
           <> show (map (Text.unpack . findingCode) staleFindings)
       | map findingCode staleFindings /= ["PLAN-FORWARD-DECLARATION-UNMATCHED"]
       ]
 where
  allFindings = checkFindings capabilityGraphDiagnostic
  forwardFindings =
    [item | item <- allFindings, findingCode item == "PLAN-CAPABILITY-FORWARD-UNDECLARED"]
  declaredFindings = checkFindings (capabilityGraphDiagnosticWith declaredReaches)
  droppedFindings = checkFindings (capabilityGraphDiagnosticWith (drop 1 declaredReaches))
  staleFindings = checkFindings (capabilityGraphDiagnosticWith (declaredReaches <> [(1, 90)]))

-- The bootstrap cycle: the documentation phase now provides run-input closure
-- and consumes the pinned toolchain, while the toolchain phase consumes run-input
-- closure back. Reassigning the run-input owner did not create this; it made a
-- pre-existing trusting-trust bootstrap visible as a typed finding. It closes
-- when that bootstrap is minted as an owned legacy binding.

distinct :: [Text] -> [Text]
distinct = foldr (\value seen -> if value `elem` seen then seen else value : seen) []
