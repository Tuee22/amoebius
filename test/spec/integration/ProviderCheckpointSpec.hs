{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Vector qualified as Vector
import System.Exit (die)

data Evidence = Evidence
  { evidenceRegister :: Int
  , evidenceSubstrate :: Text
  , evidenceControlPlaneDaemon :: ControlPlaneDaemon
  , evidenceExecutors :: ExecutorPlacement
  , evidenceCheckpoint :: Checkpoint
  , evidenceEngine :: Engine
  , evidenceProvider :: Provider
  , evidenceCleanup :: Cleanup
  , evidenceUniversal :: Universal
  }

data ControlPlaneDaemon = ControlPlaneDaemon Int Int Int Bool
data ExecutorPlacement = ExecutorPlacement Int [Executor]
data Executor = Executor Int Bool
data Checkpoint = Checkpoint Int Bool Bool Int Bool
data Engine = Engine Bool Int Text
data Provider = Provider Text Text Text Text
data Cleanup = Cleanup Bool Bool Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value ->
    Evidence
      <$> value .: "register"
      <*> value .: "substrate"
      <*> value .: "controlPlane"
      <*> value .: "executorPlacement"
      <*> value .: "checkpoint"
      <*> value .: "engineBoundary"
      <*> value .: "providerMaterialization"
      <*> value .: "cleanup"
      <*> value .: "universalLinuxCpu"

instance FromJSON ControlPlaneDaemon where
  parseJSON = withObject "ControlPlaneDaemon" $ \value ->
    ControlPlaneDaemon <$> value .: "replicas" <*> value .: "readyReplicas" <*> value .: "availableReplicas" <*> value .: "bespokeElection"

instance FromJSON ExecutorPlacement where
  parseJSON = withObject "ExecutorPlacement" $ \value ->
    ExecutorPlacement <$> value .: "boundedParallel" <*> value .: "jobs"

instance FromJSON Executor where
  parseJSON = withObject "Executor" $ \value ->
    Executor <$> value .: "environmentEntries" <*> value .: "serviceLinks"

instance FromJSON Checkpoint where
  parseJSON = withObject "Checkpoint" $ \value ->
    Checkpoint
      <$> value .: "exactObjectPeak"
      <*> value .: "directTransitDecrypt"
      <*> value .: "sealedVaultCheckpointInventoryUnchanged"
      <*> value .: "sealedVaultRefusalStatus"
      <*> value .: "plaintextDataKeyWritten"

instance FromJSON Engine where
  parseJSON = withObject "Engine" $ \value ->
    Engine <$> value .: "absolutePath" <*> value .: "environmentEntries" <*> value .: "providerUpArgv"

instance FromJSON Provider where
  parseJSON = withObject "Provider" $ \value ->
    Provider <$> value .: "eksControlPlane" <*> value .: "managedNodeGroup" <*> value .: "providerAccountObservation" <*> value .: "cloudTrailMutationAudit"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value ->
    Cleanup <$> value .: "checkpointBucketRemoved" <*> value .: "phase44NamespaceAbsent" <*> value .: "temporaryRootAbsent" <*> value .: "transitKeyRemoved"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value ->
    Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value ->
    Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

main :: IO ()
main = do
  bytes <- ByteString.readFile "DEVELOPMENT_PLAN/evidence/phase_44/provider-checkpoint-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "provider-deploy-checkpoint-live: PASS (scoped live boundaries; AWS/EKS materialization UNVERIFIED)"

verify :: Evidence -> IO ()
verify evidence = do
  assert (evidenceRegister evidence == 3 && evidenceSubstrate evidence == "linux-cpu") "register/substrate"
  case evidenceControlPlaneDaemon evidence of
    ControlPlaneDaemon replicas ready available election ->
      assert (replicas == 1 && ready == 1 && available == 1 && not election) "control-plane"
  case evidenceExecutors evidence of
    ExecutorPlacement parallel jobs -> do
      assert (parallel == 2 && length jobs == 2) "executor-live-set"
      assert (Vector.fromList jobs `seq` all executorClean jobs) "executor-environment"
  case evidenceCheckpoint evidence of
    Checkpoint peak directDecrypt inventoryStable refusalStatus dataKeyWritten ->
      assert (peak == 6 && directDecrypt && inventoryStable && refusalStatus >= 400 && not dataKeyWritten) "checkpoint"
  case evidenceEngine evidence of
    Engine absolute environmentCount providerUp ->
      assert (absolute && environmentCount == 0 && providerUp == "UNVERIFIED (AWS authority invalid)") "engine-boundary"
  case evidenceProvider evidence of
    Provider eks nodeGroup account audit ->
      assert (all (== "UNVERIFIED") [eks, nodeGroup, account, audit]) "provider-honesty"
  case evidenceCleanup evidence of
    Cleanup bucket namespace temporary transit ->
      assert (and [bucket, namespace, temporary, transit]) "cleanup"
  case evidenceUniversal evidence of
    Universal available (Pristine linux linuxCuda apple windows) ->
      assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
 where
  executorClean (Executor environmentCount serviceLinks) = environmentCount == 0 && not serviceLinks
  assert condition marker = unless condition (die marker)
