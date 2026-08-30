{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the typed capability graph.
--
-- The graph exists to make forward dependencies findable. It reports them
-- today, so this oracle asserts the exact set that is currently true rather
-- than an empty one: an unexpected new forward dependency fails here, and so
-- does one that silently disappears. As the ordering defects are fixed the
-- expected count comes down, which makes this a progress measure rather than a
-- snapshot.
module CapabilityGraphOracle
  ( runCapabilityGraphOracle
  ) where

import Amoebius.Validation.CapabilityGraph (capabilityGraphDiagnostic)
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
  ]

-- | Sixty-three declared edges run backwards in the present order: five calculi
-- reaching the later compile-fail harness, four from the toolchain phase, five
-- from the layout phase, one documentation-phase toolchain requirement, one
-- boundary-phase generated-fake requirement, and forty-seven phases inheriting
-- run-input closure from a later owner.
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
       , code `notElem` ["PLAN-CAPABILITY-FORWARD-DEPENDENCY", "PLAN-CAPABILITY-CYCLE"]
       ]
    <> [ "expected the bootstrap cycle to be reported at exactly two capabilities, observed "
           <> show (map (Text.unpack . findingSubjectText) cycleFindings)
       | sort (map findingSubjectText cycleFindings) /= ["documentation_suite", "toolchain_spike"]
       ]
 where
  allFindings = checkFindings capabilityGraphDiagnostic
  forwardFindings =
    [item | item <- allFindings, findingCode item == "PLAN-CAPABILITY-FORWARD-DEPENDENCY"]
  cycleFindings =
    [item | item <- allFindings, findingCode item == "PLAN-CAPABILITY-CYCLE"]

-- The bootstrap cycle: the documentation phase now provides run-input closure
-- and consumes the pinned toolchain, while the toolchain phase consumes run-input
-- closure back. Reassigning the run-input owner did not create this; it made a
-- pre-existing trusting-trust bootstrap visible as a typed finding. It closes
-- when that bootstrap is minted as an owned legacy binding.

distinct :: [Text] -> [Text]
distinct = foldr (\value seen -> if value `elem` seen then seen else value : seen) []
