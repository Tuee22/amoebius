{-# LANGUAGE OverloadedStrings #-}

module Infernix.Adapter.Core
  ( CpuInferenceWorkBudget (..)
  , CpuBudgetError (..)
  , minimumCpuInferenceWorkBudget
  , admitCpuInferenceWorkBudget
  , RunId (..)
  , WorkflowRequest (..)
  , WorkflowOutcome (..)
  , WorkflowError (..)
  , EffectCounts (..)
  , AdapterState
  , emptyAdapterState
  , adapterEffectCounts
  , runWorkflow
  ) where

import Amoebius.Kernel.Rng (splitMixSeed)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word64)
import Infernix.Adapter.Engine (EngineResolution, resolveNamedEngine)
import Infernix.Adapter.Pulsar
import Infernix.Adapter.Secrets (ServiceCredential, credentialScope, tenantScopeText)
import Infernix.Adapter.Store
import Infernix.Inference.Deterministic (deterministicCpuDecode)
import Infernix.Topic.Metadata (CompactedView, KeyedEvent (..), emptyCompactedView, lookupCompactedView, upsertCompactedView)
import Numeric.Natural (Natural)

data CpuInferenceWorkBudget = CpuInferenceWorkBudget
  { cpuThreads :: Natural
  , cpuConcurrency :: Natural
  , cpuMaxInputTokens :: Natural
  , cpuMaxOutputTokens :: Natural
  , cpuRetries :: Natural
  , cpuBufferBytes :: Natural
  , cpuMilli :: Natural
  , cpuMemoryMiB :: Natural
  , cpuEphemeralMiB :: Natural
  , cpuCacheMiB :: Natural
  }
  deriving stock (Eq, Show)

data CpuBudgetError
  = CpuInferenceThreadsUnderReserved
  | CpuInferenceConcurrencyUnderReserved
  | CpuInferenceInputTokensUnderReserved
  | CpuInferenceOutputTokensUnderReserved
  | CpuInferenceRetriesUnderReserved
  | CpuInferenceBufferUnderReserved
  | CpuInferenceCpuUnderReserved
  | CpuInferenceMemoryUnderReserved
  | CpuInferenceEphemeralUnderReserved
  | CpuInferenceCacheUnderReserved
  deriving stock (Eq, Show)

minimumCpuInferenceWorkBudget :: CpuInferenceWorkBudget
minimumCpuInferenceWorkBudget = CpuInferenceWorkBudget 2 1 64 16 1 4096 500 256 64 96

admitCpuInferenceWorkBudget :: CpuInferenceWorkBudget -> Either CpuBudgetError CpuInferenceWorkBudget
admitCpuInferenceWorkBudget candidate
  | cpuThreads candidate < cpuThreads required = Left CpuInferenceThreadsUnderReserved
  | cpuConcurrency candidate < cpuConcurrency required = Left CpuInferenceConcurrencyUnderReserved
  | cpuMaxInputTokens candidate < cpuMaxInputTokens required = Left CpuInferenceInputTokensUnderReserved
  | cpuMaxOutputTokens candidate < cpuMaxOutputTokens required = Left CpuInferenceOutputTokensUnderReserved
  | cpuRetries candidate < cpuRetries required = Left CpuInferenceRetriesUnderReserved
  | cpuBufferBytes candidate < cpuBufferBytes required = Left CpuInferenceBufferUnderReserved
  | cpuMilli candidate < cpuMilli required = Left CpuInferenceCpuUnderReserved
  | cpuMemoryMiB candidate < cpuMemoryMiB required = Left CpuInferenceMemoryUnderReserved
  | cpuEphemeralMiB candidate < cpuEphemeralMiB required = Left CpuInferenceEphemeralUnderReserved
  | cpuCacheMiB candidate < cpuCacheMiB required = Left CpuInferenceCacheUnderReserved
  | otherwise = Right candidate
 where
  required = minimumCpuInferenceWorkBudget

newtype RunId = RunId Text
  deriving stock (Eq, Ord, Show)

data WorkflowRequest = WorkflowRequest
  { workflowCommandId :: CommandId
  , workflowWorkId :: WorkId
  , workflowRunId :: RunId
  , workflowNonce :: Nonce
  , workflowInput :: Text
  , workflowSeed :: Word64
  , workflowExperimentHash :: Text
  , workflowArtifact :: ReadyArtifactHandle
  , workflowBudget :: CpuInferenceWorkBudget
  }
  deriving stock (Eq, Show)

data WorkflowOutcome = WorkflowOutcome
  { outcomeCommandId :: CommandId
  , outcomeWorkId :: WorkId
  , outcomeRunId :: RunId
  , outcomeNonce :: Nonce
  , outcomeExperimentHash :: Text
  , outcomeOutput :: ByteString
  , outcomeEvent :: InferenceEvent
  , outcomeEngine :: EngineResolution
  , outcomeReadyHandle :: ReadyArtifactHandle
  }
  deriving stock (Eq, Show)

data WorkflowError
  = WorkflowArtifactError ArtifactError
  | WorkflowBudgetError CpuBudgetError
  | WorkflowEngineError Text
  | IdempotencyConflict
  deriving stock (Eq, Show)

data EffectCounts = EffectCounts
  { effectWorkflows :: Natural
  , effectDispatches :: Natural
  , effectArtifactReads :: Natural
  , effectResultWrites :: Natural
  }
  deriving stock (Eq, Show)

data StoredOutcome = StoredOutcome Text WorkflowOutcome
  deriving stock (Eq, Show)

data AdapterState = AdapterState (CompactedView StoredOutcome) EffectCounts
  deriving stock (Eq, Show)

emptyAdapterState :: AdapterState
emptyAdapterState = AdapterState emptyCompactedView (EffectCounts 0 0 0 0)

adapterEffectCounts :: AdapterState -> EffectCounts
adapterEffectCounts (AdapterState _ effects) = effects

runWorkflow :: ServiceCredential -> WorkflowRequest -> AdapterState -> Either WorkflowError (WorkflowOutcome, AdapterState)
runWorkflow credential request state@(AdapterState outcomes effects) = do
  _ <- either (Left . WorkflowBudgetError) Right (admitCpuInferenceWorkBudget (workflowBudget request))
  ready <- either (Left . WorkflowArtifactError) Right (authorizeReadyArtifact credential (workflowArtifact request))
  let scope = tenantScopeText (credentialScope credential)
      normalized = normalizeInput (workflowInput request)
      identity = requestIdentity normalized request
      key = scope <> "\NUL" <> commandIdText (workflowCommandId request)
  case lookupCompactedView key outcomes of
    Just (StoredOutcome previous original)
      | previous == identity -> Right (original, state)
      | otherwise -> Left IdempotencyConflict
    Nothing -> do
      engine <- either (Left . WorkflowEngineError . Text.pack . show) Right resolveNamedEngine
      let command =
            InferenceCommand
              { commandScopeText = scope
              , commandId = workflowCommandId request
              , commandWorkId = workflowWorkId request
              , commandNonce = workflowNonce request
              , commandNormalizedInput = normalized
              }
          outcome =
            WorkflowOutcome
              { outcomeCommandId = workflowCommandId request
              , outcomeWorkId = workflowWorkId request
              , outcomeRunId = workflowRunId request
              , outcomeNonce = workflowNonce request
              , outcomeExperimentHash = workflowExperimentHash request
              , outcomeOutput = deterministicCpuDecode (readyArtifactPayload ready) (TextEncoding.encodeUtf8 normalized) (splitMixSeed (workflowSeed request))
              , outcomeEvent = eventForCommand command
              , outcomeEngine = engine
              , outcomeReadyHandle = ready
              }
          nextEffects =
            EffectCounts
              { effectWorkflows = effectWorkflows effects + 1
              , effectDispatches = effectDispatches effects + 1
              , effectArtifactReads = effectArtifactReads effects + 1
              , effectResultWrites = effectResultWrites effects + 1
              }
      Right (outcome, AdapterState (upsertCompactedView (KeyedEvent key (StoredOutcome identity outcome)) outcomes) nextEffects)

normalizeInput :: Text -> Text
normalizeInput = Text.unwords . Text.words

requestIdentity :: Text -> WorkflowRequest -> Text
requestIdentity normalized request =
  Text.intercalate
    "\NUL"
    [ normalized
    , readyArtifactBlobDigest (workflowArtifact request)
    , workflowExperimentHash request
    , Text.pack (show (workflowSeed request))
    , let Nonce value = workflowNonce request in value
    , let RunId value = workflowRunId request in value
    ]

commandIdText :: CommandId -> Text
commandIdText (CommandId value) = value
