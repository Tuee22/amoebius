{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  bytes <- ByteString.readFile (root </> "DEVELOPMENT_PLAN/evidence/phase_53/apple-host-live.json")
  value <- either die pure (eitherDecodeStrict' bytes)
  validate value
  putStrLn "apple-metal-host-live-gate: PASS-SCOPED (portable host/resource/loopback/lifecycle/numerical contracts; physical Apple/Lima/Metal UNVERIFIED)"

validate :: Value -> IO ()
validate (Object root) = do
  assertText root "schema" "amoebius.phase53.apple-host-live.v1"
  assertText root "result" "PASS-SCOPED"
  assertObject root "universalLinuxCpu" $ \universal -> do
    assertBool universal "availableOnEveryHardwareSubstrate" True
    assertObject universal "pristineLinuxHost" $ \routing -> do
      assertText routing "linux" "Incus"
      assertText routing "linux-cuda" "Incus"
      assertText routing "apple" "Lima"
      assertText routing "windows" "WSL2"
  assertObject root "resourceFold" $ \resource -> do
    assertNumber resource "vmProvisionedBytes" 42949672960
    assertNumber resource "hostMemoryDebitBytes" 20401094656
    assertNumber resource "hostDiskDebitBytes" 128849018880
  assertObject root "numerical" $ \numerical -> do
    assertText numerical "jobA" "000040400000a0400000e04000001041"
    assertText numerical "jobB" "000080bf00000040000070410000b841"
    assertText numerical "challenge" "0000dc41000090c00000a03f00080046"
    assertText numerical "metalDispatch" "UNVERIFIED"
  assertObject root "loopback" $ \loopback -> do
    assertText loopback "bindAddress" "127.0.0.1"
    assertText loopback "serviceType" "NodePort"
    assertBool loopback "rawMinioNodePort" False
    assertBool loopback "envoyRoute" False
    assertBool loopback "daemonWildIngress" False
  assertObject root "managedSubprocess" $ \managed -> do
    assertBool managed "pathPresent" False
    assertBool managed "terminatedAndReaped" True
  assertObject root "honesty" $ \honesty -> mapM_ (\key -> assertText honesty key "UNVERIFIED")
    ["physicalAppleSilicon", "limaVm", "brewEnsure", "metalFramework", "metalDeviceAndLibrary", "nativePulsar", "contentMutationGateway", "minioArtifact"]
  assertObject root "cleanup" $ \cleanup -> mapM_ (\key -> assertBool cleanup key True)
    ["listenersClosed", "subprocessReaped", "temporaryChallengeRemoved"]
validate _ = die "phase53 evidence root must be an object"

assertObject :: KeyMap.KeyMap Value -> Text -> (KeyMap.KeyMap Value -> IO ()) -> IO ()
assertObject object key action = case KeyMap.lookup (fromText key) object of
  Just (Object nested) -> action nested
  _ -> die ("missing object: " <> show key)

assertText :: KeyMap.KeyMap Value -> Text -> Text -> IO ()
assertText object key expected = case KeyMap.lookup (fromText key) object of
  Just (String actual) -> unless (actual == expected) (die ("wrong text: " <> show key))
  _ -> die ("missing text: " <> show key)

assertBool :: KeyMap.KeyMap Value -> Text -> Bool -> IO ()
assertBool object key expected = case KeyMap.lookup (fromText key) object of
  Just (Bool actual) -> unless (actual == expected) (die ("wrong bool: " <> show key))
  _ -> die ("missing bool: " <> show key)

assertNumber :: KeyMap.KeyMap Value -> Text -> Integer -> IO ()
assertNumber object key expected = case KeyMap.lookup (fromText key) object of
  Just (Number actual) -> unless (actual == fromInteger expected) (die ("wrong number: " <> show key))
  _ -> die ("missing number: " <> show key)

fromText :: Text -> Data.Aeson.Key.Key
fromText = Data.Aeson.Key.fromText

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "apple-metal-host-daemon-project-root-absent" else ascend parent
