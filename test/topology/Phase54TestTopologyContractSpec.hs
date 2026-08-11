{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Test.Credentials
import Amoebius.Test.Harness
import Amoebius.Test.Ledger
import Amoebius.Test.ResourceWitness
import Amoebius.Test.Runner
import Amoebius.Test.SuggestTest
import Amoebius.Test.Sweep
import Amoebius.Test.Topology
import Control.Exception (SomeException, throwIO, try)
import Control.Monad (forM_, unless)
import Data.IORef
import Data.Set qualified as Set
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  verifyCredentials
  provisioned <- verifySuggestAndProvision
  verifyRunner provisioned
  verifySweep
  verifyHarness
  verifyLedger provisioned
  putStrLn "phase54-test-topology-contract: PASS (20 Phase-0 rows; deterministic single-substrate suggestion; nine resource axes; flagged credential; structured teardown; independent leak diff; derived honesty ledger)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/phase0_oracle_manifest.tsv"
  let phaseRows = filter (Text.isPrefixOf "54\t" . Text.pack) rows
  assertEqual "Phase-0 custody" 20 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing custody file: " <> path)
    _ -> die "malformed Phase-54 custody row"

verifyCredentials :: IO ()
verifyCredentials = do
  ref <- either (die . show) pure (secretRef "vault/test/phase54")
  credential <- either (die . show) pure (flaggedTestCredential ref True)
  assert (credentialIsTestSimulation credential) "test flag absent"
  assertEqual "secret by name" "vault/test/phase54" (credentialSecretName credential)
  assertLeft "everyday credential" TestSimulationFlagRequired (flaggedTestCredential ref False)

verifySuggestAndProvision :: IO ProvisionedTestTopology
verifySuggestAndProvision = do
  ref <- either (die . show) pure (secretRef "vault/test/phase54")
  credential <- either (die . show) pure (flaggedTestCredential ref True)
  let supply = ResourceVector 8000 17179869184 68719476736 4294967296 1073741824 32 32 0 0
      input branch = SuggestInput TestLinuxCpu supply credential branch Nothing
  outputs <- traverse (either (die . show) pure . suggestTest . input) [minBound .. maxBound]
  assertEqual "closed optional branch cardinality" 4 (length outputs)
  let provisioned = head outputs
      witness = resourceWitness provisioned
      expected = ResourceVector 3000 3221225472 8589934592 1073741824 536870912 4 4 0 0
  assertEqual "canonical demand" expected (witnessedDemand witness)
  let firstRender = renderSuggestedDhall provisioned
      secondRender = renderSuggestedDhall provisioned
  assertEqual "deterministic cache-bypass render" firstRender secondRender
  assert ("phase54-failover" `Text.isInfixOf` firstRender && "vault/test/phase54" `Text.isInfixOf` firstRender) "suggested topology omissions"
  forM_
    [ (CpuShort, supply {resourceCpuMillis = 2999})
    , (MemoryShort, supply {resourceMemoryBytes = 3221225471})
    , (EphemeralShort, supply {resourceEphemeralBytes = 8589934591})
    , (DurableShort, supply {resourceDurableBytes = 1073741823})
    , (CacheShort, supply {resourceCacheBytes = 536870911})
    , (PodSlotsShort, supply {resourcePodSlots = 3})
    , (IpSlotsShort, supply {resourceIpSlots = 3})
    ] $ \(failure, short) -> assertLeft "resource one-short" (NoRepresentativeTopologyFits failure)
      (suggestTest (SuggestInput TestLinuxCpu short credential NoOptionalBranch Nothing))
  let topology = provisionedTopology provisioned
  assertLeft "missing accelerator" MissingAcceleratorCapability
    (provisionTestTopology topology {topologyAcceleratorRequirement = Accelerator "cuda"})
  assertLeft "untagged allocation" TestOwnedTagRequired
    (provisionTestTopology topology {topologyAllocations = [Allocation "leak" False 1]})
  assertLeft "teardown mandatory" TeardownRequired
    (provisionTestTopology topology {topologyTeardownRequired = False})
  pure provisioned

verifyRunner :: ProvisionedTestTopology -> IO ()
verifyRunner provisioned = do
  trace <- newIORef ([] :: [String])
  let mark value = modifyIORef' trace (<> [value])
      actions = RunnerActions (mark "spin") (mark "run" >> throwIO (userError "forced"))
        (mark "fault") (mark "evaluate") (mark "teardown")
  result <- try (runTestTopology provisioned actions) :: IO (Either SomeException ())
  assert (isLeft result) "workflow exception disappeared"
  assertEqual "teardown on failure" ["spin", "run", "teardown"] =<< readIORef trace
 where
  isLeft (Left _) = True
  isLeft (Right _) = False

verifySweep :: IO ()
verifySweep = do
  let retained = InventoryEntry "retained" "pre-existing" False
      untyped = InventoryEntry "configmap" "outside-typed-path" False
      before = Inventory (Set.singleton retained)
      clean = Inventory (Set.singleton retained)
      leaked = Inventory (Set.fromList [retained, untyped])
  assert (inventoryClean (diffInventory before clean)) "retained-by-design reported as leak"
  assert (not (inventoryClean (diffInventory before leaked))) "untagged leak escaped independent diff"

verifyHarness :: IO ()
verifyHarness = do
  let tagged = Allocation "test-volume" True 1024
      untagged = Allocation "production-volume" False 1024
  assertLeft "everyday backing delete" ElevatedHarnessRequired (authorizeBackingDelete EverydayActor tagged)
  assertEqual "elevated tagged delete" (Right ()) (authorizeBackingDelete ElevatedTestHarness tagged)
  assertLeft "elevated production delete" TestOwnedBackingRequired (authorizeBackingDelete ElevatedTestHarness untagged)

verifyLedger :: ProvisionedTestTopology -> IO ()
verifyLedger provisioned = assertEqual "derived applicable coverage"
  (RunLedger [CoverageRow "StandbyTakesOver" Tested, CoverageRow "CrossZoneContinuity" Unverified])
  (deriveRunLedger provisioned)

splitTabs :: String -> [String]
splitTabs source = case break (== '\t') source of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assertLeft :: (Eq err, Show err, Show value) => String -> err -> Either err value -> IO ()
assertLeft label expected actual = case actual of
  Left observed -> assertEqual label expected observed
  Right value -> die (label <> ": expected Left, got " <> show value)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "phase54-project-root-absent" else ascend parent
