{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.JitML.CudaArtifactLift
  ( TrainingTarget (..)
  , TrainingCommandId (..)
  , ScopedTrainingRequest (..)
  , CudaCapacity (..)
  , ProvisionedCudaTraining
  , provisionCudaTraining
  , CudaExecutionProof
  , cudaExecutionProof
  , PointerRevision (..)
  , PointerCasResult (..)
  , StagedJitMLArtifact
  , stageCheckpoint
  , CommittedJitMLArtifact
  , commitStagedArtifact
  , committedArtifactTenant
  , committedArtifactApp
  , committedArtifactCommandId
  , committedArtifactWorkId
  , committedArtifactManifestSha
  , committedArtifactPointerRevision
  , LiftError (..)
  , LiftEffectCounts (..)
  , JitMLLiftState
  , emptyJitMLLiftState
  , liftEffectCounts
  , runCommittedTraining
  ) where

import Amoebius.Store.ContentAddress (ContentDigest, contentDigest, digestHex)
import Amoebius.Store.Manifest
  ( Component (..)
  , Manifest
  , canonicalManifestBytes
  , manifest
  , manifestContentDigest
  )
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteStringChar8
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word64)

data TrainingTarget = CudaTarget | CpuTarget
  deriving stock (Eq, Ord, Show)

newtype TrainingCommandId = TrainingCommandId Text
  deriving stock (Eq, Ord, Show)

data ScopedTrainingRequest = ScopedTrainingRequest
  { trainingTenant :: Text
  , trainingApp :: Text
  , trainingCommandId :: TrainingCommandId
  , trainingTarget :: TrainingTarget
  , trainingOptimizerSteps :: Word64
  , trainingParameterCount :: Word64
  , trainingRequiredVramBytes :: Word64
  , trainingBatch :: ByteString
  , trainingChallenge :: Text
  }
  deriving stock (Eq, Show)

data CudaCapacity = CudaCapacity
  { cudaDeviceIdentity :: Text
  , cudaDeviceProfile :: Text
  , cudaWholeDeviceCount :: Word64
  , cudaTotalVramBytes :: Word64
  , cudaMandatoryReserveBytes :: Word64
  , cudaNetAllocatableBytes :: Word64
  , cudaCurrentFreeVramBytes :: Word64
  }
  deriving stock (Eq, Show)

data ProvisionedCudaTraining = ProvisionedCudaTraining
  { provisionedRequest :: ScopedTrainingRequest
  , provisionedCapacity :: CudaCapacity
  }
  deriving stock (Eq, Show)

data CudaExecutionProof = CudaExecutionProof
  { executionDeviceIdentity :: Text
  , executionOptimizerSteps :: Word64
  , executionParameterCount :: Word64
  , executionCheckpointBytes :: ByteString
  }
  deriving stock (Eq, Show)

newtype PointerRevision = PointerRevision Text
  deriving stock (Eq, Ord, Show)

data PointerCasResult
  = PointerCasSucceeded PointerRevision
  | PointerCasConflict
  deriving stock (Eq, Show)

data StagedJitMLArtifact = StagedJitMLArtifact
  { stagedRequest :: ScopedTrainingRequest
  , stagedManifest :: Manifest
  , stagedManifestDigest :: ContentDigest
  }
  deriving stock (Eq, Show)

data CommittedJitMLArtifact = CommittedJitMLArtifact
  { internalArtifactTenant :: Text
  , internalArtifactApp :: Text
  , internalArtifactCommandId :: TrainingCommandId
  , internalArtifactWorkId :: TrainingCommandId
  , internalArtifactManifestSha :: Text
  , internalArtifactPointerRevision :: PointerRevision
  }
  deriving stock (Eq, Show)

data LiftError
  = CudaRequired
  | CudaExecutionUnavailable
  | CudaDeviceCountMismatch
  | CudaCapacityInvalid
  | CudaNetAllocatableShort
  | CudaCurrentFreeShort
  | TrainingStepFloor
  | TrainingParameterFloor
  | CudaExecutionMismatch
  | CheckpointManifestInvalid Text
  | PointerConflict
  | IdempotencyConflict
  deriving stock (Eq, Show)

data LiftEffectCounts = LiftEffectCounts
  { trainerLaunches :: Word64
  , cudaKernelLaunches :: Word64
  , immutableObjectWrites :: Word64
  , pointerAdvances :: Word64
  }
  deriving stock (Eq, Show)

data StoredOutcome = StoredOutcome
  { storedRequestDigest :: ContentDigest
  , storedArtifact :: CommittedJitMLArtifact
  }

data JitMLLiftState = JitMLLiftState
  { internalOutcomes :: Map (Text, Text, TrainingCommandId) StoredOutcome
  , internalEffects :: LiftEffectCounts
  }

emptyJitMLLiftState :: JitMLLiftState
emptyJitMLLiftState = JitMLLiftState Map.empty (LiftEffectCounts 0 0 0 0)

liftEffectCounts :: JitMLLiftState -> LiftEffectCounts
liftEffectCounts = internalEffects

provisionCudaTraining
  :: ScopedTrainingRequest
  -> CudaCapacity
  -> Either LiftError ProvisionedCudaTraining
provisionCudaTraining request capacity = do
  case trainingTarget request of
    CudaTarget -> Right ()
#ifdef JITML_LIFT_CUDA_SILENT_CPU_FALLBACK_MUTANT
    CpuTarget -> Right ()
#else
    CpuTarget -> Left CudaRequired
#endif
  if trainingOptimizerSteps request < 200 then Left TrainingStepFloor else Right ()
  if trainingParameterCount request < 10000000 then Left TrainingParameterFloor else Right ()
  if cudaWholeDeviceCount capacity /= 1 then Left CudaDeviceCountMismatch else Right ()
  if cudaMandatoryReserveBytes capacity + cudaNetAllocatableBytes capacity > cudaTotalVramBytes capacity
    then Left CudaCapacityInvalid
    else Right ()
  if trainingRequiredVramBytes request > capacityForAdmission capacity
    then Left CudaNetAllocatableShort
    else Right ()
  if trainingRequiredVramBytes request > cudaCurrentFreeVramBytes capacity
    then Left CudaCurrentFreeShort
    else Right ()
  Right (ProvisionedCudaTraining request capacity)

capacityForAdmission :: CudaCapacity -> Word64
#ifdef JITML_LIFT_CUDA_SPEND_RAW_VRAM_MUTANT
capacityForAdmission = cudaTotalVramBytes
#else
capacityForAdmission = cudaNetAllocatableBytes
#endif

cudaExecutionProof
  :: ProvisionedCudaTraining
  -> Text
  -> Word64
  -> Word64
  -> ByteString
  -> Either LiftError CudaExecutionProof
cudaExecutionProof provisioned device steps parameters checkpoint
  | device /= cudaDeviceIdentity (provisionedCapacity provisioned) = Left CudaExecutionMismatch
  | steps /= trainingOptimizerSteps (provisionedRequest provisioned) = Left CudaExecutionMismatch
  | parameters /= trainingParameterCount (provisionedRequest provisioned) = Left CudaExecutionMismatch
  | otherwise = Right (CudaExecutionProof device steps parameters checkpoint)

stageCheckpoint
  :: ProvisionedCudaTraining
  -> CudaExecutionProof
  -> Either LiftError StagedJitMLArtifact
stageCheckpoint provisioned proof = do
  let request = provisionedRequest provisioned
      weights = contentDigest (executionCheckpointBytes proof)
      batch = contentDigest (trainingBatch request)
  value <- case manifest [Component "batch" batch, Component "weights" weights] of
    Left problem -> Left (CheckpointManifestInvalid problem)
    Right result -> Right result
  Right
    StagedJitMLArtifact
      { stagedRequest = request
      , stagedManifest = value
      , stagedManifestDigest = manifestContentDigest value
      }

commitStagedArtifact
  :: PointerCasResult
  -> StagedJitMLArtifact
  -> Either LiftError CommittedJitMLArtifact
commitStagedArtifact result staged = case result of
#ifdef JITML_LIFT_CUDA_MINT_ARTIFACT_BEFORE_CAS_MUTANT
  _ -> Right (mintArtifact (PointerRevision "uncommitted") staged)
#else
  PointerCasSucceeded revision -> Right (mintArtifact revision staged)
  PointerCasConflict -> Left PointerConflict
#endif

mintArtifact :: PointerRevision -> StagedJitMLArtifact -> CommittedJitMLArtifact
mintArtifact revision staged =
  let request = stagedRequest staged
      workId = workIdentity request
   in CommittedJitMLArtifact
        { internalArtifactTenant = trainingTenant request
        , internalArtifactApp = trainingApp request
        , internalArtifactCommandId = trainingCommandId request
        , internalArtifactWorkId = workId
        , internalArtifactManifestSha = digestHex (stagedManifestDigest staged)
        , internalArtifactPointerRevision = revision
        }

workIdentity :: ScopedTrainingRequest -> TrainingCommandId
#ifdef JITML_LIFT_CUDA_REGENERATE_COMMAND_ID_MUTANT
workIdentity _ = TrainingCommandId "regenerated-command"
#else
workIdentity request = trainingCommandId request
#endif

committedArtifactTenant :: CommittedJitMLArtifact -> Text
committedArtifactTenant = internalArtifactTenant

committedArtifactApp :: CommittedJitMLArtifact -> Text
committedArtifactApp = internalArtifactApp

committedArtifactCommandId :: CommittedJitMLArtifact -> TrainingCommandId
committedArtifactCommandId = internalArtifactCommandId

committedArtifactWorkId :: CommittedJitMLArtifact -> TrainingCommandId
committedArtifactWorkId = internalArtifactWorkId

committedArtifactManifestSha :: CommittedJitMLArtifact -> Text
committedArtifactManifestSha = internalArtifactManifestSha

committedArtifactPointerRevision :: CommittedJitMLArtifact -> PointerRevision
committedArtifactPointerRevision = internalArtifactPointerRevision

runCommittedTraining
  :: ScopedTrainingRequest
  -> CudaCapacity
  -> Text
  -> ByteString
  -> PointerRevision
  -> JitMLLiftState
  -> Either LiftError (CommittedJitMLArtifact, JitMLLiftState)
runCommittedTraining request capacity observedDevice checkpoint revision state =
  let identity = (trainingTenant request, trainingApp request, trainingCommandId request)
      digest = requestDigest request
   in case Map.lookup identity (internalOutcomes state) of
        Just prior
          | storedRequestDigest prior == digest -> Right (storedArtifact prior, state)
          | otherwise -> Left IdempotencyConflict
        Nothing -> do
          provisioned <- provisionCudaTraining request capacity
          proof <- cudaExecutionProof provisioned observedDevice
            (trainingOptimizerSteps request) (trainingParameterCount request) checkpoint
          staged <- stageCheckpoint provisioned proof
          artifact <- commitStagedArtifact (PointerCasSucceeded revision) staged
          let old = internalEffects state
              effects =
                LiftEffectCounts
                  { trainerLaunches = trainerLaunches old + 1
                  , cudaKernelLaunches = cudaKernelLaunches old + trainingOptimizerSteps request
                  , immutableObjectWrites = immutableObjectWrites old + 3
                  , pointerAdvances = pointerAdvances old + 1
                  }
              outcome = StoredOutcome digest artifact
          Right (artifact, JitMLLiftState (Map.insert identity outcome (internalOutcomes state)) effects)

requestDigest :: ScopedTrainingRequest -> ContentDigest
requestDigest request =
  contentDigest
    ( TextEncoding.encodeUtf8 (trainingTenant request)
        <> TextEncoding.encodeUtf8 (trainingApp request)
        <> commandBytes (trainingCommandId request)
        <> ByteStringChar8.pack (show (trainingTarget request))
        <> ByteStringChar8.pack (show (trainingOptimizerSteps request))
        <> ByteStringChar8.pack (show (trainingParameterCount request))
        <> ByteStringChar8.pack (show (trainingRequiredVramBytes request))
        <> trainingBatch request
        <> TextEncoding.encodeUtf8 (trainingChallenge request)
    )
 where
  commandBytes (TrainingCommandId value) = TextEncoding.encodeUtf8 value

_manifestBytesWitness :: StagedJitMLArtifact -> ByteString
_manifestBytesWitness = canonicalManifestBytes . stagedManifest
