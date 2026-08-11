{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.JitML.CudaArtifactLift
import Control.Monad (unless)
import Data.ByteString.Char8 qualified as ByteString
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import JitML.Codegen.RuntimeOperationsCuda (renderRuntimeOperationsCudaSource)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  validatePhase0 root
  let request = baseRequest
      capacity = fittingCapacity
  provisioned <- either (die . show) pure (provisionCudaTraining request capacity)
  proof <- either (die . show) pure
    (cudaExecutionProof provisioned "gpu0" 200 10000000 "checkpoint-challenge-51")
  staged <- either (die . show) pure (stageCheckpoint provisioned proof)

  assertWith "mut-51-silent-cpu-fallback" $
    provisionCudaTraining request {trainingTarget = CpuTarget} capacity == Left CudaRequired
  assertWith "mut-51-spend-raw-vram" $
    provisionCudaTraining request netOneShort == Left CudaNetAllocatableShort
  assertEqual "current-free one-short"
    (Left CudaCurrentFreeShort) (provisionCudaTraining request currentFreeOneShort)
  assertEqual "step floor" (Left TrainingStepFloor)
    (provisionCudaTraining request {trainingOptimizerSteps = 199} capacity)
  assertEqual "parameter floor" (Left TrainingParameterFloor)
    (provisionCudaTraining request {trainingParameterCount = 9999999} capacity)
  assertWith "mut-51-mint-artifact-before-cas" $
    commitStagedArtifact PointerCasConflict staged == Left PointerConflict

  let revision = PointerRevision "etag-phase51-1"
  (artifact, state1) <- either (die . show) pure
    (runCommittedTraining request capacity "gpu0" "checkpoint-challenge-51" revision emptyJitMLLiftState)
  assertWith "mut-51-regenerate-command-id" $
    committedArtifactCommandId artifact == committedArtifactWorkId artifact
  assertEqual "artifact tenant" "tenant-a" (committedArtifactTenant artifact)
  assertEqual "artifact app" "jitml-training" (committedArtifactApp artifact)
  assertEqual "pointer revision" revision (committedArtifactPointerRevision artifact)
  assert (Text.length (committedArtifactManifestSha artifact) == 64) "manifest digest width"
  assertEqual "positive effects" (LiftEffectCounts 1 200 3 1) (liftEffectCounts state1)

  (resent, state2) <- either (die . show) pure
    (runCommittedTraining request capacity "gpu0" "checkpoint-challenge-51" revision state1)
  assertEqual "exact resend artifact" artifact resent
  assertEqual "exact resend zero effects" (liftEffectCounts state1) (liftEffectCounts state2)
  assertLeft "changed input conflict" IdempotencyConflict
    (runCommittedTraining request {trainingBatch = "different-batch"} capacity "gpu0"
      "checkpoint-challenge-51" revision state1)

  let linkedSource = show renderRuntimeOperationsCudaSource
  assert ("cudaMalloc" `Text.isInfixOf` Text.pack linkedSource) "linked sibling CUDA source absent"
  assert ("runtime_input_transform_kernel<<<1, 1>>>" `Text.isInfixOf` Text.pack linkedSource)
    "linked sibling kernel launch absent"
  putStrLn "jitml-cuda-artifact-lift-contract: PASS (linked sibling CUDA source, no CPU fallback, capacity, commit, identity, idempotency)"

baseRequest :: ScopedTrainingRequest
baseRequest =
  ScopedTrainingRequest
    { trainingTenant = "tenant-a"
    , trainingApp = "jitml-training"
    , trainingCommandId = TrainingCommandId "phase0-command-51"
    , trainingTarget = CudaTarget
    , trainingOptimizerSteps = 200
    , trainingParameterCount = 10000000
    , trainingRequiredVramBytes = 67108864
    , trainingBatch = ByteString.pack "phase51-batch|phase0-challenge-51"
    , trainingChallenge = "phase0-challenge-51"
    }

fittingCapacity :: CudaCapacity
fittingCapacity =
  CudaCapacity
    { cudaDeviceIdentity = "gpu0"
    , cudaDeviceProfile = "sm_52"
    , cudaWholeDeviceCount = 1
    , cudaTotalVramBytes = 4294967296
    , cudaMandatoryReserveBytes = 268435456
    , cudaNetAllocatableBytes = 4026531840
    , cudaCurrentFreeVramBytes = 3758096384
    }

netOneShort :: CudaCapacity
netOneShort =
  fittingCapacity
    { cudaTotalVramBytes = 335544319
    , cudaNetAllocatableBytes = 67108863
    , cudaCurrentFreeVramBytes = 335544319
    }

currentFreeOneShort :: CudaCapacity
currentFreeOneShort = fittingCapacity {cudaCurrentFreeVramBytes = 67108863}

validatePhase0 :: FilePath -> IO ()
validatePhase0 root = do
  rows <- filter (Text.isPrefixOf "51\t") . Text.lines
    <$> TextIO.readFile (root </> "test/phase0_oracle_manifest.tsv")
  assertEqual "Phase51 manifest cardinality" 9 (length rows)
  assertEqual "Phase51 oracle cardinality" 5 (length (filter (Text.isInfixOf "\toracle\t") rows))
  assertEqual "Phase51 mutant cardinality" 4 (length (filter (Text.isInfixOf "\tmutant\t") rows))
  dhall <- TextIO.readFile (root </> "test/dhall/phase_51/jitml_cuda_artifact.dhall")
  mapM_ (\needle -> assert (needle `Text.isInfixOf` dhall) ("Phase51 Dhall pin absent: " <> Text.unpack needle))
    ["optimizerSteps = 200", "parameterCount = 10000000", "cpuFallback = False", "availableOnEveryHardwareSubstrate = True"]
  package <- TextIO.readFile (root </> "dhall/jitml/package.dhall")
  mapM_ (\needle -> assert (needle `Text.isInfixOf` package) ("jitML package surface absent: " <> Text.unpack needle))
    ["JitBuild", "Coordination", "InferenceEngine", "publicInfrastructureFields = []"]

assertWith :: String -> Bool -> IO ()
assertWith = flip assert

assertLeft :: String -> LiftError -> Either LiftError value -> IO ()
assertLeft label expected value = case value of
  Left actual -> assertEqual label expected actual
  Right _ -> die (label <> ": expected Left, got Right")

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "phase51-project-root-absent" else ascend parent
