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
import Amoebius.Ui.LocalComposition
import Control.Monad (unless)
import Data.Text qualified as Text
import System.Exit (die)
import UiLocalCompositionCases qualified as Cases
import UiLocalCompositionReference qualified as Reference

main :: IO ()
main = do
  let challenge = "fresh-challenge-43-to-44"
      ready = ReadyArtifactHandle "tenant-a" "alice" True "artifact-a"
      notReady = ready{handleReceiptReady = False}
      foreignTenant = ready{handleTenant = "tenant-b"}
      start = run "tenant-a" "alice" (StartWorkflow challenge)
      observe = run "tenant-a" "alice" (ObserveWorkflow challenge ready)
      use = run "tenant-a" "alice" (UseArtifact ready challenge)
      sameTenantForeign = run "tenant-a" "bob" (UseArtifact ready challenge)
      foreignResult = run "tenant-b" "alice" (UseArtifact ready challenge)
      spoof = run "tenant-a" "alice" (UseArtifact foreignTenant challenge)
      notReadyResult = run "tenant-a" "alice" (UseArtifact notReady challenge)
      bypass = run "tenant-a" "alice" DirectDomainRequest
      visible =
        [ ("single-start", visibleOf start)
        , ("single-observe", visibleOf observe)
        , ("single-use", visibleOf use)
        , ("multi-foreign-use", visibleOf sameTenantForeign)
        ]
      effects = concatMap snd [start, observe, use]
      effectRows = [(Text.unpack (effectBoundary effect), Text.unpack (effectValue effect)) | effect <- effects] <> [("multi-foreign", "zero-effects")]
      access = [("own", accepted use), ("same-tenant-foreign", accepted sameTenantForeign), ("foreign-tenant", accepted foreignResult)]
      denials =
        [ denial "same-tenant-foreign" sameTenantForeign
        , denial "foreign-tenant" foreignResult
        , denial "caller-tenant-header" spoof
        , denial "non-ready-handle" notReadyResult
        , denial "direct-browser-backend" bypass
        ]
  checkMutantLocus foreignResult sameTenantForeign notReadyResult bypass
  assertEqual "interaction names" 5 (length Cases.interactionNames)
  assertEqual "visible state rows" Reference.visibleRows visible
  assertEqual "effect sequence rows" Reference.effectRows effectRows
  assertEqual "access rows" Reference.accessRows access
  assertEqual "denial rows" Reference.denialRows denials
  assertEqual "paired plan digest" True (pairedPlanIdentity compiledCompositionMutant "plan-digest" "plan-digest")
  checkCalculus
  putStrLn "ui-local-composition-calculus: PASS (5 kinds, 55 projected units)"
  putStrLn "ui-local-composition-spec: PASS (2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"
 where
  run = runCompositionRequest compiledCompositionMutant

visibleOf :: (CompositionResponse, [DomainEffect]) -> String
visibleOf = Text.unpack . compositionVisible . fst

accepted :: (CompositionResponse, [DomainEffect]) -> Bool
accepted = (< 400) . compositionStatus . fst

denial :: String -> (CompositionResponse, [DomainEffect]) -> (String, Int, String)
denial name result = (name, compositionStatus (fst result), Text.unpack (compositionTag (fst result)))

checkMutantLocus ::
  (CompositionResponse, [DomainEffect]) ->
  (CompositionResponse, [DomainEffect]) ->
  (CompositionResponse, [DomainEffect]) ->
  (CompositionResponse, [DomainEffect]) ->
  IO ()
checkMutantLocus foreignResult sameTenantForeign notReadyResult bypass = case compiledCompositionMutant of
  CompositionClean -> pure ()
  DropHandleTenant -> assertEqual "foreign tenant denial" False (accepted foreignResult)
  DirectWorkflowFetch -> assertEqual "direct browser backend denial" False (accepted bypass)
  MixClientServerPlan -> assertEqual "paired plan digest" True (pairedPlanIdentity compiledCompositionMutant "plan-digest" "plan-digest")
  ReadyBeforeReceipt -> assertEqual "non-ready handle denial" False (accepted notReadyResult)
  OwnerKeySwap -> assertEqual "foreign subject denial" False (accepted sameTenantForeign)

checkCalculus :: IO ()
checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "local-composition-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "local-composition-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral (count :: Int)) 0 0
        counts = [1, 3, 42, 4, 5] :: [Int]
        artifact = artifactComponent scope "generic-composition-artifact" (resources 1) (RecipeId "local-ui-composition" 1)
        budget = budgetComponent scope "closed-scope-budget" (resources 3) (allowance (Bytes 3) (Slots 1) (Bytes 3))
        lift = liftComponent scope "local-composition-corpus" (resources 42) OnHost
        workflow = workflowComponent scope "ordered-effect-workflow" (resources 4) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 5) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        render = Text.unpack . Text.intercalate ","
        actual =
          [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
          , ["component-names", render (compositionNames composition)]
          , ["projection-counts", render (map (Text.pack . show) counts)]
          , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
          ]
    assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
    assertEqual "composition calculus projection" Cases.calculusRows actual
  action

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
