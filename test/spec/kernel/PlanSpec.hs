{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Capacity.Provision (ProvisionedSpec)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Kernel.Chain
import Amoebius.Kernel.Descent (Plan (..), PlanEntry (..), foldLift, nextFrameAfter)
import Amoebius.Kernel.Plan (renderChainPlan, renderPlan)
import Amoebius.Kernel.Step
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject (K8sObject (objectIdentity))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import ChainBoundaryOracle
  ( expectedCalculusProjection
  , expectedCases
  , expectedPlanRows
  )
import Control.DeepSeq (deepseq)
import Control.Monad (forM_, unless)
import Data.Aeson (eitherDecode)
import Data.IORef (IORef, newIORef, readIORef)
import Data.List (find, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ProvisionFixtures (provisionFixture)

data KernelCase = KernelCase
  { kernelCaseId :: Text
  , kernelFixtureSlug :: Text
  , kernelShape :: ServiceShape
  }

data OracleRow = OracleRow
  { oracleCase :: Text
  , oraclePosition :: Int
  , oracleEntry :: PlanEntry
  }

main :: IO ()
main = do
  cases <- loadCases
  oracle <- loadPlanOracle
  runGreen cases oracle

runGreen :: [KernelCase] -> Map Text [PlanEntry] -> IO ()
runGreen cases oracle = do
  rowCounts <- mapM (checkCase oracle) cases
  assert (sum rowCounts == 19) "semantic plan oracle no longer contains exactly nineteen rows"
  checkZeroPlan
  checkCanary
  checkPureImports
  checkChainCalculusProjection (sum rowCounts)
  putStrLn "chain-calculus: PASS (5 kinds, 38 projected units)"
  putStrLn "chain-invariants: PASS (2 consumed cases, 19 semantic plan rows, 19 canonical round-trips, 4 activation frames, 0 render actions, 1 canary)"
  putStrLn "chain-spec: PASS (2 semantic cases, 19 exact plan/descent entries, 1 zero-step render, 2 mutants)"

checkCase :: Map Text [PlanEntry] -> KernelCase -> IO Int
checkCase oracle kernelCase = do
  (counter, cfg, sealed, steps) <- buildCase kernelCase
  let actualPlan@(Plan actualEntries) = foldLift () steps
      encoded = renderChainPlan steps
      objects = concatMap stepObjects steps
      identities = fmap objectIdentity objects
      sealedObjects = renderAll sealed
  expectedEntries <- maybe (fail ("semantic oracle omitted " <> Text.unpack (kernelCaseId kernelCase))) pure (Map.lookup (kernelCaseId kernelCase) oracle)
  assert (planConfigId cfg == kernelCaseId kernelCase) "PlanConfig lost its case identity"
  assert (planConfigProvisionedSpec cfg == sealed) "PlanConfig does not retain the whole ProvisionedSpec"
  assert (foldLift () (chain cfg) == actualPlan) "chain is not a stable pure builder"
  assert (actualEntries == expectedEntries) (Text.unpack (kernelCaseId kernelCase) <> " semantic plan projection drifted")
  steps `deepseq` pure ()
  count <- readIORef counter
  assert (count == 0) "forcing or rendering a Step executed its action"
  decoded <- either (fail . ("canonical Plan failed Aeson decode: " <>)) pure (eitherDecode encoded)
  assert (decoded == actualPlan) "canonical plan render changed its semantic Plan"
  assert (renderPlan decoded == encoded) "canonical Plan encoding changed after round trip"
  assert (objects == sealedObjects) "Step object union differs from whole-deployment renderAll"
  assert (length identities == Set.size (Set.fromList identities)) "Step object projections overlap"
  assert
    ( Set.fromList (fmap stepFrame steps)
        == Set.fromList [ImmediateFrame, BootstrapSchedulerFrame, AfterBootstrapAddonCutoverFrame, AfterManagedCapacityReadyFrame]
    )
    "activation projection does not cover exactly the four render frames"
  assert (nextFrameAfter ImmediateFrame steps == Just BootstrapSchedulerFrame) "Immediate frame descent drifted"
  assert (nextFrameAfter BootstrapSchedulerFrame steps == Just AfterBootstrapAddonCutoverFrame) "scheduler frame descent drifted"
  assert (nextFrameAfter AfterBootstrapAddonCutoverFrame steps == Just AfterManagedCapacityReadyFrame) "cutover frame descent drifted"
  assert (nextFrameAfter AfterManagedCapacityReadyFrame steps == Nothing) "managed-capacity frame is not terminal"
  pure (length actualEntries)

buildCase :: KernelCase -> IO (IORef Int, PlanConfig, ProvisionedSpec, [Step PlanConfig])
buildCase kernelCase = do
  fixture <- maybe (fail "unknown capability fixture") pure (find ((== kernelFixtureSlug kernelCase) . fixtureSlug) capabilityFixtures)
  sealed <- either (fail . show) pure (provisionFixture fixture (kernelShape kernelCase))
  counter <- newIORef 0
  let cfg = mkPlanConfig (kernelCaseId kernelCase) sealed counter
  pure (counter, cfg, sealed, chain cfg)

checkZeroPlan :: IO ()
checkZeroPlan = do
  let emptySteps = [] :: [Step PlanConfig]
      bytes = renderChainPlan emptySteps
      expected = Plan []
  decoded <- either (fail . ("zero-step Plan failed Aeson decode: " <>)) pure (eitherDecode bytes)
  assert (decoded == expected && renderPlan expected == bytes) "zero-step canonical Plan drifted"

checkCanary :: IO ()
checkCanary = do
  counter <- newIORef 0
  let canary = mkCountingStep counter "canary" BoundaryFrame PulumiUp [] (const (pure ()))
  stepRun canary ()
  count <- readIORef counter
  assert (count == 1) "step-run canary did not observe execution"

checkPureImports :: IO ()
checkPureImports = do
  sources <- mapM Text.readFile ["src/Amoebius/Kernel/Plan.hs", "src/Amoebius/Cli.hs"]
  let prohibited = ["System.Process", "Network.", "VAULT_", "KUBECONFIG", "unsafePerformIO"]
  assert (all (\token -> all (not . Text.isInfixOf token) sources) prohibited) "dry-run import closure reaches an effect module"

loadCases :: IO [KernelCase]
loadCases = do
  cases <- mapM parseCase expectedCases
  assert (fmap kernelCaseId cases == ["minimal", "multi"]) "chain cases must be exactly minimal then multi"
  pure cases
 where
  parseCase (caseId, fixture, shapeName, nodes) = do
      shape <- case shapeName of
        "SingleNode" | nodes == 1 -> pure SingleNode
        "Distributed" | nodes >= 2 -> pure (Distributed (fromIntegral nodes))
        _ -> fail ("invalid case shape: " <> Text.unpack shapeName)
      pure (KernelCase caseId fixture shape)

loadPlanOracle :: IO (Map Text [PlanEntry])
loadPlanOracle = do
  parsed <- mapM parseRow expectedPlanRows
  let cases = Set.toAscList (Set.fromList (fmap oracleCase parsed))
      ordered caseId = sortOn oraclePosition (filter ((== caseId) . oracleCase) parsed)
  forM_ cases $ \caseId -> do
    let positions = fmap oraclePosition (ordered caseId)
    assert (positions == [1 .. length positions]) ("non-contiguous plan positions for " <> Text.unpack caseId)
  pure (Map.fromList [(caseId, fmap oracleEntry (ordered caseId)) | caseId <- cases])
 where
  parseRow (caseId, position, label, frameText, kindText, objectId) = do
      frame <- parseFrame frameText
      kind <- parseKind kindText
      pure (OracleRow caseId position (PlanEntry label frame kind [objectId]))

parseFrame :: Text -> IO Frame
parseFrame value = case value of
  "ImmediateFrame" -> pure ImmediateFrame
  "BootstrapSchedulerFrame" -> pure BootstrapSchedulerFrame
  "AfterBootstrapAddonCutoverFrame" -> pure AfterBootstrapAddonCutoverFrame
  "AfterManagedCapacityReadyFrame" -> pure AfterManagedCapacityReadyFrame
  "BoundaryFrame" -> pure BoundaryFrame
  _ -> fail ("unknown frame: " <> Text.unpack value)

parseKind :: Text -> IO StepKind
parseKind value = case value of
  "ApplyObjects" -> pure ApplyObjects
  "DockerBuild" -> pure DockerBuild
  "DockerPush" -> pure DockerPush
  "PulumiUp" -> pure PulumiUp
  _ -> fail ("unknown step kind: " <> Text.unpack value)

checkChainCalculusProjection :: Int -> IO ()
checkChainCalculusProjection planRows = do
  let expected = expectedCalculusProjection
      boundaryTranscripts = 4
      astRows = 6
      mutantCount = 7
      kernelProperties = 2
  tenant <- either (fail . show) pure (trustedTenant "chain-boundary-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "chain-boundary-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "semantic-plan-rows" (resources planRows) (RecipeId "chain-boundary-corpus" 1)
        budget = budgetComponent scope "boundary-transcripts" (resources boundaryTranscripts) (allowance (Bytes (fromIntegral boundaryTranscripts)) (Slots 1) (Bytes (fromIntegral boundaryTranscripts)))
        lift = liftComponent scope "ast-negatives" (resources astRows) OnHost
        workflow = workflowComponent scope "kernel-properties" (resources kernelProperties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutantCount) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [planRows, boundaryTranscripts, astRows, kernelProperties, mutantCount]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "chain boundary projection omitted or reordered a calculus"
    assert (actual == expected) ("chain boundary calculus projection changed: " <> show actual)
  action

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
