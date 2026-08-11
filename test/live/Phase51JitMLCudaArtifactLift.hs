{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word64)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

data Evidence = Evidence Int Text Text Text Challenge Cuda Artifact Linked Kubernetes Cleanup Universal Honesty
data Challenge = Challenge Text Text Text Int
data Cuda = Cuda Text Text Text Text Word64 Word64 Word64 Word64 Word64 Word64 Bool Bool Bool Double Double Text Int
data Artifact = Artifact Text Text Text [Text] Bool Int Bool Int Bool Int
data Linked = Linked Text Text Bool
data Kubernetes = Kubernetes Text Text Text
data Cleanup = Cleanup Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Honesty = Honesty Text Text Text Text Text Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value -> Evidence
    <$> value .: "register" <*> value .: "substrate" <*> value .: "result"
    <*> value .: "evidenceDigest" <*> value .: "challenge" <*> value .: "cuda"
    <*> value .: "artifact" <*> value .: "linkedSibling" <*> value .: "kubernetes"
    <*> value .: "cleanup" <*> value .: "universalLinuxCpu" <*> value .: "honesty"

instance FromJSON Challenge where
  parseJSON = withObject "Challenge" $ \value -> Challenge
    <$> value .: "commandId" <*> value .: "workId" <*> value .: "nonce"
    <*> value .: "unpredictableBytes"

instance FromJSON Cuda where
  parseJSON = withObject "Cuda" $ \value -> Cuda
    <$> value .: "driverApi" <*> value .: "ptxTarget" <*> value .: "name"
    <*> value .: "uuid" <*> value .: "parameters" <*> value .: "optimizerSteps"
    <*> value .: "kernelLaunches" <*> value .: "checkpointBytes"
    <*> value .: "mandatoryReserveBytes" <*> value .: "netAllocatableBytes"
    <*> value .: "physicalDevice" <*> value .: "cpuFallback"
    <*> value .: "independentCheckpointOracle" <*> value .: "firstParameter"
    <*> value .: "lastParameter" <*> value .: "checkpointDigest"
    <*> value .: "nvidiaSmiObservedPid"

instance FromJSON Artifact where
  parseJSON = withObject "Artifact" $ \value -> Artifact
    <$> value .: "batchDigest" <*> value .: "checkpointDigest"
    <*> value .: "manifestDigest" <*> value .: "writeOrder"
    <*> value .: "pointerWrittenLast" <*> value .: "pointerConflictStatus"
    <*> value .: "pointerUnchangedAfterConflict" <*> value .: "exactResendObjectDelta"
    <*> value .: "readbackEtagsPresent" <*> value .: "unauthenticatedReadStatus"

instance FromJSON Linked where
  parseJSON = withObject "Linked" $ \value -> Linked
    <$> value .: "module" <*> value .: "sourceDigest" <*> value .: "compiledByContractPackage"

instance FromJSON Kubernetes where
  parseJSON = withObject "Kubernetes" $ \value -> Kubernetes
    <$> value .: "retainedNodeGpuAllocatable" <*> value .: "acceleratorOwnerPod"
    <*> value .: "devicePlugin"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup
    <$> value .: "MinioBucket" <*> value .: "CudaAllocationReleased"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal
    <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine
    <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Honesty where
  parseJSON = withObject "Honesty" $ \value -> Honesty
    <$> value .: "linkedSiblingCudaCodegen" <*> value .: "hostCudaKernelTraining"
    <*> value .: "retainedMinioCommit" <*> value .: "kubernetesAcceleratorOwner"
    <*> value .: "devicePluginAllocation" <*> value .: "nativeCborCommandEventChain"
    <*> value .: "fullSiblingTrainer" <*> value .: "trainerFailover"
    <*> value .: "generalTenantNoninterference"

main :: IO ()
main = do
  root <- projectRoot
  bytes <- ByteString.readFile (root </> "DEVELOPMENT_PLAN/evidence/phase_51/jitml-cuda-live.json")
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "jitml-cuda-artifact-lift-live-gate: PASS-SCOPED (physical host CUDA, 10M parameters, 200 steps, retained MinIO commit/conflict, cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate result evidenceDigest challenge cuda artifact linked kubernetes cleanup universal honesty) = do
  assert (register == 3 && substrate == "linux-cuda" && result == "PASS-SCOPED" && digestShape evidenceDigest)
    "register/substrate/result/digest"
  case challenge of
    Challenge command work nonce unpredictable ->
      assert (command == work && "cmd-" `Text.isPrefixOf` command && Text.length nonce == 48 && unpredictable == 24)
        "challenge/identity"
  case cuda of
    Cuda driver target name uuid parameters steps launches bytes reserve net physical fallback oracle first lastValue checkpoint pid ->
      assert (driver == "libcuda.so.1" && target == "sm_52" && name == "NVIDIA GeForce GTX 970"
        && "GPU-" `Text.isPrefixOf` uuid && parameters == 10000000 && steps == 200 && launches == 200
        && bytes == 40000000 && reserve == 268435456 && net == 4026531840 && physical
        && not fallback && oracle && first == lastValue && digestShape checkpoint && pid > 0) "cuda"
  case artifact of
    Artifact batch checkpoint manifest order pointerLast conflict unchanged resendDelta etags unauthenticated ->
      assert (all digestShape [batch, checkpoint, manifest] && length order == 4 && pointerLast
        && conflict == 412 && unchanged && resendDelta == 0 && etags && unauthenticated == 403) "artifact"
  case linked of
    Linked name source compiled ->
      assert (name == "JitML.Codegen.RuntimeOperationsCuda" && digestShape source && compiled) "linked-sibling"
  case kubernetes of
    Kubernetes allocatable owner plugin ->
      assert (Text.null allocatable && owner == "UNVERIFIED" && plugin == "UNVERIFIED") "kubernetes-honesty"
  case cleanup of Cleanup minio allocation -> assert (minio && allocation) "cleanup"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) ->
      assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2")
        "universal-linux-cpu"
  case honesty of
    Honesty sibling hostCuda minio owner plugin cbor trainer failover general ->
      assert (all (== "TESTED") [sibling, hostCuda, minio]
        && all (== "UNVERIFIED") [owner, plugin, cbor, trainer, failover, general]) "honesty"

digestShape :: Text -> Bool
digestShape value = "sha256:" `Text.isPrefixOf` value && Text.length value == 71

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "phase51-project-root-absent" else ascend parent

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)
