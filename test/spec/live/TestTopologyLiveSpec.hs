{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  bytes <- ByteString.readFile (root </> "DEVELOPMENT_PLAN/evidence/phase_54/test-topology-live.json")
  value <- either die pure (eitherDecodeStrict' bytes)
  validate value
  putStrLn "test-topology-dsl-test-topology-live-gate: PASS-SCOPED (host inventory/forced-failure/SIGINT/idempotent teardown/process takeover; Kubernetes/Pulsar/retained-PV/Vault/AWS UNVERIFIED)"

validate :: Value -> IO ()
validate (Object root) = do
  text root "schema" "amoebius.phase54.test-topology-live.v1"
  text root "result" "PASS-SCOPED"
  object root "teardown" $ \teardown -> do
    boolean teardown "forcedFailureClean" True
    boolean teardown "secondTeardownNoop" True
    object teardown "sigint" $ \sigint -> boolean sigint "markerRemoved" True >> boolean sigint "processReaped" True
  object root "inventory" $ \inventory -> do
    arrayLength inventory "diff" 0
    arrayLength inventory "untaggedMutantDiff" 1
  object root "failover" $ \failover -> do
    text failover "promoted" "worker-b"
    text failover "pulsarBrokerStats" "UNVERIFIED"
  object root "executionBoundary" $ \boundary -> boolean boundary "pathPresent" False
  object root "universalLinuxCpu" $ \universal -> do
    boolean universal "availableOnEveryHardwareSubstrate" True
    object universal "pristineLinuxHost" $ \routing -> do
      text routing "linux" "Incus"; text routing "linux-cuda" "Incus"; text routing "apple" "Lima"; text routing "windows" "WSL2"
  object root "honesty" $ \honesty -> mapM_ (\name -> text honesty name "UNVERIFIED")
    ["kubernetesTopology", "retainedPvBackingDelete", "pulsarBrokerFailoverStats", "vaultLiveCredential", "awsCloudInventory", "providerCloudLeakMutant"]
validate _ = die "phase54 evidence root"

object :: KeyMap.KeyMap Value -> Text -> (KeyMap.KeyMap Value -> IO ()) -> IO ()
object value name action = case KeyMap.lookup (Key.fromText name) value of Just (Object nested) -> action nested; _ -> die ("missing object " <> show name)
text :: KeyMap.KeyMap Value -> Text -> Text -> IO ()
text value name expected = case KeyMap.lookup (Key.fromText name) value of Just (String actual) -> unless (actual == expected) (die ("wrong text " <> show name)); _ -> die ("missing text " <> show name)
boolean :: KeyMap.KeyMap Value -> Text -> Bool -> IO ()
boolean value name expected = case KeyMap.lookup (Key.fromText name) value of Just (Bool actual) -> unless (actual == expected) (die ("wrong bool " <> show name)); _ -> die ("missing bool " <> show name)
arrayLength :: KeyMap.KeyMap Value -> Text -> Int -> IO ()
arrayLength value name expected = case KeyMap.lookup (Key.fromText name) value of Just (Array actual) -> unless (length actual == expected) (die ("wrong array " <> show name)); _ -> die ("missing array " <> show name)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else let parent = takeDirectory path in if parent == path then die "test-topology-dsl-project-root-absent" else ascend parent
