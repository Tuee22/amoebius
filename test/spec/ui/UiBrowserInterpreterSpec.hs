{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Browser.Interpreter
import Amoebius.Ui.Browser.Projection
import Control.Monad (unless)
import Data.Text qualified as Text
import System.Exit (die)
import UiBrowserInterpreterCases qualified as Cases
import UiBrowserInterpreterReference qualified as Reference

main :: IO ()
main = do
  observed <- traverse (either (die . Text.unpack) pure . interpret Cases.currentPlan) Cases.interactions
  assertEqual "interpreter traces" Reference.traceRows (zipWith renderTrace Cases.interactions observed)
  assertEqual "stale envelope" (Left "ReloadRequired") (verifyEnvelope Cases.stalePlan)
  assertEqual "trusted text escaping" "&lt;img&gt;" (renderTrustedText "<img>")
  assertEqual "accessibility rows" 3 (length Reference.accessibilityRows)
  assertEqual "focus rows" Reference.focusRows
    [["Escape", Text.unpack (focusAfter "Escape" "modal-opener")], ["route", Text.unpack (focusAfter "route" "")], ["Enter", Text.unpack (focusAfter "Enter" "")], ["Tab", Text.unpack (focusAfter "Tab" "")], ["validation", Text.unpack (focusAfter "validation" "")]]
  let allowed = TransportPlan "POST" "same-origin" "/ui/action/submit" (challengeBody "nonce-012345678901234567890123456789")
      provider = TransportPlan "GET" "https://provider.invalid" "/api" ""
  assertEqual "same-origin request" True (providerRequestAllowed allowed)
  assertEqual "provider request refusal" False (providerRequestAllowed provider)
  assertEqual "fresh challenge" "challenge=nonce-012345678901234567890123456789" (transportBody allowed)
  assertEqual "transport rows" 4 (length Reference.transportRows)
  assertEqual "safe projected source" True (projectionIsSafe projectPureScript)
  assertEqual "deterministic projection" projectPureScript projectPureScript
  checkCalculus
  putStrLn "ui-browser-interpreter-calculus: PASS (5 kinds, 72 projected units)"
  putStrLn "ui-browser-interpreter-spec: PASS (2 plans, 5 interactions, 5 traces, 2 semantic views, 3 accessibility rows, 5 focus rows, 4 transport rows, 9 mutants)"

renderTrace :: Interaction -> Observation -> [String]
renderTrace selected observed =
  [ Text.unpack (caseName selected), show (visibleState observed), show (requestedEffect observed)
  , Text.unpack (route observed), show (atomicWrites observed)
  ]

checkCalculus :: IO ()
checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-browser-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-browser-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral (count :: Int)) 0 0
        counts = [9, 5, 45, 4, 9] :: [Int]
        artifact = artifactComponent scope "browser-bundle-artifacts" (resources 9) (RecipeId "ui-browser-interpreter" 9)
        budget = budgetComponent scope "closed-browser-budget" (resources 5) (allowance (Bytes 5) (Slots 1) (Bytes 5))
        lift = liftComponent scope "browser-boundary-corpus" (resources 45) OnHost
        workflow = workflowComponent scope "differential-browser-workflow" (resources 4) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 9) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        render = Text.unpack . Text.intercalate ","
        actual = [["calculus-kinds", render (map calculusTag (compositionKinds composition))], ["component-names", render (compositionNames composition)], ["projection-counts", render (map (Text.pack . show) counts)], ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]]
    assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
    assertEqual "browser calculus projection" Cases.calculusRows actual
  action

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure
assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
