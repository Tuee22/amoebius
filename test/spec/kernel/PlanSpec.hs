{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Kernel.Chain
import Amoebius.Kernel.Descent (Plan (..), PlanEntry (..), foldLift, nextFrameAfter)
import Amoebius.Kernel.Plan (renderChainPlan)
import Amoebius.Kernel.Step
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject (K8sObject (objectIdentity))
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Control.DeepSeq (deepseq)
import Control.Monad (unless)
import Data.Aeson (eitherDecode)
import Data.ByteString.Lazy qualified as ByteString
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import ProvisionFixtures (provisionFixture)
import System.Environment (getArgs)

data KernelCase = KernelCase
  { kernelCaseId :: Text
  , kernelFixtureSlug :: Text
  , kernelShape :: ServiceShape
  }

kernelCases :: [KernelCase]
kernelCases =
  [ KernelCase "minimal" "objectstore" SingleNode
  , KernelCase "multi" "sql" (Distributed 3)
  ]

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--print-goldens"] -> mapM_ printGolden kernelCases
    ["--mutant=m1_cfg_drop_service"] -> rejectMutant "m1_cfg_drop_service" mutateDropStep
    ["--mutant=m2_descent_inframe"] -> rejectMutant "m2_descent_inframe" mutateDescent
    _ -> runGreen

runGreen :: IO ()
runGreen = do
  summaries <- mapM checkCase kernelCases
  expectedBytes <- ByteString.readFile "test/fixture/chain_boundary/plan/expected_steps.json"
  expected <- either (fail . ("invalid expected_steps.json: " <>)) pure (eitherDecode expectedBytes)
  assert (Map.fromList summaries == expected) "kernel step-set oracle drifted"
  checkCanary
  checkPureImports
  putStrLn "chain-spec: PASS (2 cfg fixtures, 2 plan goldens, 2 descent goldens, 0 render actions, 1 canary, 2 mutants)"

checkCase :: KernelCase -> IO (Text, [Text])
checkCase kernelCase = do
  (counter, cfg, steps) <- buildCase kernelCase
  steps `deepseq` pure ()
  count <- readIORef counter
  assert (count == 0) "rendering executed a step action"
  expectedPlan <- ByteString.readFile (planPath kernelCase)
  assert (renderChainPlan steps == expectedPlan) (Text.unpack (kernelCaseId kernelCase) <> " plan golden drifted")
  expectedDescent <- ByteString.readFile (descentPath kernelCase)
  assert (renderDescent steps == expectedDescent) (Text.unpack (kernelCaseId kernelCase) <> " descent golden drifted")
  let objects = concatMap stepObjects steps
      identities = fmap objectIdentity objects
      sealedObjects = renderAll (planConfigProvisionedSpec cfg)
  assert (objects == sealedObjects) "Step object union differs from whole-deployment renderAll"
  assert (length identities == Set.size (Set.fromList identities)) "Step object projections overlap"
  assert (nextFrameAfter ImmediateFrame steps == Just BootstrapSchedulerFrame) "fixture frame descent drifted"
  pure (kernelCaseId kernelCase, fmap stepLabel steps)

buildCase :: KernelCase -> IO (IORef Int, PlanConfig, [Step PlanConfig])
buildCase kernelCase = do
  fixture <- maybe (fail "unknown capability fixture") pure (find ((== kernelFixtureSlug kernelCase) . fixtureSlug) capabilityFixtures)
  sealed <- either (fail . show) pure (provisionFixture fixture (kernelShape kernelCase))
  counter <- newIORef 0
  let cfg = mkPlanConfig (kernelCaseId kernelCase) sealed counter
  pure (counter, cfg, chain cfg)

checkCanary :: IO ()
checkCanary = do
  counter <- newIORef 0
  let canary = mkCountingStep counter "canary" BoundaryFrame PulumiUp [] (const (pure ()))
  stepRun canary ()
  count <- readIORef counter
  assert (count == 1) "step-run canary did not observe execution"
  writeIORef counter 0

checkPureImports :: IO ()
checkPureImports = do
  sources <- mapM readFile ["src/Amoebius/Kernel/Plan.hs", "src/Amoebius/Cli.hs"]
  let prohibited = ["System.Process", "Network.", "VAULT_", "KUBECONFIG", "unsafePerformIO"]
  assert (all (\token -> all (not . Text.isInfixOf (Text.pack token) . Text.pack) sources) prohibited) "dry-run import closure reaches an effect module"

printGolden :: KernelCase -> IO ()
printGolden kernelCase = do
  (_, _, steps) <- buildCase kernelCase
  ByteString.putStr (ByteString.fromStrict ("==" <> TextEncoding.encodeUtf8 (kernelCaseId kernelCase) <> ".plan==\n"))
  ByteString.putStr (renderChainPlan steps)
  ByteString.putStr (ByteString.fromStrict ("==" <> TextEncoding.encodeUtf8 (kernelCaseId kernelCase) <> ".descent==\n"))
  ByteString.putStr (renderDescent steps)
  print (fmap stepLabel steps)

renderDescent :: [Step cfg] -> ByteString.ByteString
renderDescent steps = ByteString.fromStrict . TextEncoding.encodeUtf8 . Text.unlines $ fmap renderEntry entries
 where
  Plan entries = foldLift () steps
  renderEntry entry = Text.pack (show (planEntryFrame entry)) <> "\t" <> planEntryLabel entry

rejectMutant :: String -> ([Step PlanConfig] -> (ByteString.ByteString, ByteString.ByteString)) -> IO ()
rejectMutant name mutation = do
  kernelCase <- maybe (fail "multi fixture absent") pure (find ((== "multi") . kernelCaseId) kernelCases)
  (_, _, steps) <- buildCase kernelCase
  expectedPlan <- ByteString.readFile (planPath kernelCase)
  expectedDescent <- ByteString.readFile (descentPath kernelCase)
  let (mutantPlan, mutantDescent) = mutation steps
      caught = mutantPlan /= expectedPlan || mutantDescent /= expectedDescent
  if caught
    then putStrLn ("chain-boundary-chain-mutant: RED " <> name) >> fail ("chain boundary mutant rejected: " <> name)
    else putStrLn ("chain-boundary-chain-mutant: SURVIVED " <> name)

mutateDropStep :: [Step cfg] -> (ByteString.ByteString, ByteString.ByteString)
mutateDropStep steps = (renderChainPlan (dropLast steps), renderDescent (dropLast steps))

mutateDescent :: [Step cfg] -> (ByteString.ByteString, ByteString.ByteString)
mutateDescent steps = (renderChainPlan steps, ByteString.fromStrict (TextEncoding.encodeUtf8 "mutant-in-frame\n"))

dropLast :: [a] -> [a]
dropLast values = case reverse values of
  [] -> []
  _ : remaining -> reverse remaining

planPath :: KernelCase -> FilePath
planPath kernelCase = "test/fixture/chain_boundary/plan/" <> Text.unpack (kernelCaseId kernelCase) <> ".plan.golden"

descentPath :: KernelCase -> FilePath
descentPath kernelCase = "test/fixture/chain_boundary/descent/" <> Text.unpack (kernelCaseId kernelCase) <> ".descent.golden"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
