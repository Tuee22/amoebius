{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON, Result (Error, Success), Value (Array, Object), eitherDecodeFileStrict', fromJSON)
import Data.Aeson.Key (Key)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (die)

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_33/singleton-live.json"
  evidence <- either die pure decoded
  expectedValue <- eitherDecodeFileStrict' "test/fixtures/phase33/expected-enact-pass1.json"
  expected <- either die pure expectedValue
  expectedObjects <- either die pure (get ["objects"] expected :: Either String [Text])
  either die pure (verify expectedObjects evidence)
  putStrLn "phase33-singleton-live-spec: PASS (Lease handoff, exact singleton effects, admin boundary, durable replacement, teardown)"

verify :: [Text] -> Value -> Either String ()
verify expected evidence = do
  equal ["schema"] ("amoebius.phase33.singleton-live.v1" :: Text)
  equal ["register"] (3 :: Int)
  equal ["substrate"] ("linux-cpu" :: Text)
  equal ["prerequisites", "retainedCluster"] ("amoebius-bootstrap-coordinator" :: Text)
  true ["historyCapacity", "withinEngineSystemReserve"]
  positive ["historyCapacity", "retainedByteCapacity"]
  true ["artifacts", "staticallyLinked"]
  equal ["manifest", "kind"] ("Deployment" :: Text)
  equal ["manifest", "replicas"] (1 :: Int)
  equal ["manifest", "strategy"] ("Recreate" :: Text)
  equal ["manifest", "persistentVolumeClaims"] ([] :: [Text])
  equal ["manifest", "standbyReplicas"] (0 :: Int)
  false ["manifest", "amoebiusElection"]
  equal ["manifest", "fieldManager"] ("amoebius-phase33-singleton" :: Text)
  equal ["handoff", "bootstrap", "holder"] ("phase26-bootstrap-host" :: Text)
  true ["handoff", "hostQuiescedBeforeRelease"]
  true ["handoff", "sameLeaseUid"]
  true ["handoff", "podNonServingBeforeRelease"]
  true ["handoff", "noSingletonMutationBeforeAcquire"]
  equal ["adminSequence", "vaultInit", "result"] ("already-initialized" :: Text)
  equal ["adminSequence", "vaultUnseal", "result"] ("unsealed" :: Text)
  equal ["adminSequence", "firstPass", "objects"] expected
  equal ["adminSequence", "secondPass", "objects"] ([] :: [Text])
  true ["adminSequence", "secondPass", "discoverReran"]
  equal ["adminSequence", "kvCrud"] (["put", "get", "list", "delete"] :: [Text])
  equal ["edge", "status"] (200 :: Int)
  equal ["edge", "body"] ("phase33-trivial:/probe" :: Text)
  true ["edge", "oidcOwned"]
  equal ["adminReach", "endpointClass"] ("HostLocalPeer" :: Text)
  true ["adminReach", "offHostDenied"]
  equal ["negativeCorpus", "count"] (26 :: Int)
  true ["negativeCorpus", "platformAppResourceVersionsUnchanged"]
  equal ["negativeCorpus", "vaultContacts"] (0 :: Int)
  equal ["negativeCorpus", "apiserverWrites"] (0 :: Int)
  arraySize ["adminNegatives", "reach"] 6
  equal ["adminNegatives", "reachVaultContacts"] (0 :: Int)
  arraySize ["adminNegatives", "admission"] 4
  equal ["adminNegatives", "admissionApiserverWrites"] (0 :: Int)
  equal ["adminNegatives", "admissionVaultContacts"] (0 :: Int)
  false ["passwordObserver", "passwordPersisted"]
  equal ["passwordObserver", "containerFilesystem"] ("clear" :: Text)
  equal ["passwordObserver", "processArgvAndEnvironment"] ("clear" :: Text)
  equal ["passwordObserver", "kubernetesObjects"] ("clear" :: Text)
  equal ["passwordObserver", "singletonLogs"] ("clear" :: Text)
  true ["replacement", "uidChanged"]
  true ["replacement", "byteIdentical"]
  true ["postflight", "sharedStackRestored"]
  equal ["postflight", "runLabelSweep"] ([] :: [Text])
  positive ["attribution", "singletonWriteCount"]
  equal ["attribution", "harnessPlatformWrites"] (0 :: Int)
  equal ["attribution", "observer"] ("kube-apiserver audit log" :: Text)
  equal ["artifactSource", "imagePullPolicy"] ("Never" :: Text)
  equal ["artifactSource", "publicPulls"] (0 :: Int)
  true ["artifactSource", "haskellSingleton"]
  true ["artifactSource", "pythonEffectHelper"]
  true ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "apple"] ("Lima" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "windows"] ("WSL2" :: Text)
  equal ["deferred", "fullAppTenancy"] ("UNVERIFIED" :: Text)
  equal ["deferred", "crossClusterGatewayMigration"] ("UNVERIFIED" :: Text)
  equal ["deferred", "tenantAdminScope"] ("UNVERIFIED" :: Text)
  equal ["deferred", "parentChildAdminReach"] ("UNVERIFIED" :: Text)
 where
  equal :: (Eq value, Show value, FromJSON value) => [Key] -> value -> Either String ()
  equal path expectedValue = do
    actual <- get path evidence
    unless (actual == expectedValue) (Left (showPath path <> ": expected " <> show expectedValue <> ", got " <> show actual))
  true path = equal path True
  false path = equal path False
  positive path = do
    actual <- get path evidence
    unless ((actual :: Int) > 0) (Left (showPath path <> ": not positive"))
  arraySize path expectedSize = do
    actual <- lookupPath path evidence
    case actual of
      Array values -> unless (length values == expectedSize) (Left (showPath path <> ": wrong array size"))
      _ -> Left (showPath path <> ": not an array")

get :: FromJSON value => [Key] -> Value -> Either String value
get path value = do
  selected <- lookupPath path value
  case fromJSON selected of
    Error problem -> Left (showPath path <> ": " <> problem)
    Success decoded -> Right decoded

lookupPath :: [Key] -> Value -> Either String Value
lookupPath [] value = Right value
lookupPath (key : rest) (Object object) =
  maybe (Left (showPath (key : rest) <> ": absent")) (lookupPath rest) (KeyMap.lookup key object)
lookupPath path _ = Left (showPath path <> ": parent is not an object")

showPath :: [Key] -> String
showPath = Text.unpack . Text.intercalate "." . fmap (Text.pack . show)
