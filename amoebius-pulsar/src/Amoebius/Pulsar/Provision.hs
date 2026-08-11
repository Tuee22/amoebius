{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Provision
  ( PulsarClientExecutionDemand (..)
  , ClientRunnerEnvelope (..)
  , PulsarTopicDemand (..)
  , PulsarClientProvision (..)
  , ProvisionError (..)
  , ProvisionedPulsarClient
  , provisionTerms
  , provisionPulsarClient
  , provisionedTerms
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Numeric.Natural (Natural)

data PulsarClientExecutionDemand = PulsarClientExecutionDemand
  { clientBrokerConnections :: Natural
  , clientProducers :: Natural
  , clientConsumers :: Natural
  , clientOutstandingRequests :: Natural
  , clientInflightFrames :: Natural
  , clientFrameBytes :: Natural
  , clientPayloadBytes :: Natural
  , clientFlowPermits :: Natural
  , clientRedeliveryWindowBytes :: Natural
  , clientCborWorkspaceBytes :: Natural
  , clientReconnectBurstBytes :: Natural
  }
  deriving stock (Eq, Show)

data ClientRunnerEnvelope = ClientRunnerEnvelope
  { runnerCpuMillis :: Natural
  , runnerMemoryBytes :: Natural
  , runnerEphemeralBytes :: Natural
  , runnerImageImportBytes :: Natural
  , runnerWritableRootBytes :: Natural
  , runnerLogBytes :: Natural
  , runnerCredentialBytes :: Natural
  , runnerConfigBytes :: Natural
  , runnerServiceAccountTokenBytes :: Natural
  , runnerLocalVolumeBytes :: Natural
  , runnerPodSlots :: Natural
  , runnerNetworkAttachmentIdentities :: Natural
  , runnerContainerVolumeMountIdentities :: Natural
  , runnerRuntimeMetadataPrimaryBytes :: Natural
  , runnerRuntimeMetadataSecondaryBytes :: Natural
  , runnerHasCache :: Bool
  , runnerHasAccelerator :: Bool
  }
  deriving stock (Eq, Show)

data PulsarTopicDemand = PulsarTopicDemand
  { topicCount :: Natural
  , subscriptionCursorCount :: Natural
  , hotLedgerBytes :: Natural
  , backlogBytes :: Natural
  , offloadObjectCount :: Natural
  , offloadSegmentBytes :: Natural
  , offloadConcurrentBytes :: Natural
  , offloadFailureOrphanBytes :: Natural
  , apiObjectRevisionBytes :: Natural
  , apiEventBytes :: Natural
  , etcdBackendPeakBytes :: Natural
  }
  deriving stock (Eq, Show)

data PulsarClientProvision = PulsarClientProvision
  { provisionClientDemand :: PulsarClientExecutionDemand
  , provisionRunnerEnvelope :: ClientRunnerEnvelope
  , provisionTopicDemand :: PulsarTopicDemand
  }
  deriving stock (Eq, Show)

data ProvisionError
  = ProvisionDeficit Text Natural Natural
  | RunnerCacheForbidden
  | RunnerAcceleratorForbidden
  | RunnerJobShapeInvalid
  deriving stock (Eq, Show)

newtype ProvisionedPulsarClient = ProvisionedPulsarClient (Map Text Natural)
  deriving stock (Eq, Show)

provisionTerms :: PulsarClientProvision -> Map Text Natural
provisionTerms provision = Map.fromList
  [ ("client.broker-connections", clientBrokerConnections client)
  , ("client.producers", clientProducers client)
  , ("client.consumers", clientConsumers client)
  , ("client.outstanding-requests", clientOutstandingRequests client)
  , ("client.inflight-frames", clientInflightFrames client)
  , ("client.frame-bytes", clientFrameBytes client)
  , ("client.payload-bytes", clientPayloadBytes client)
  , ("client.flow-permits", clientFlowPermits client)
  , ("client.redelivery-window-bytes", clientRedeliveryWindowBytes client)
  , ("client.cbor-workspace-bytes", clientCborWorkspaceBytes client)
  , ("client.reconnect-burst-bytes", clientReconnectBurstBytes client)
  , ("runner.cpu-millis", runnerCpuMillis runner)
  , ("runner.memory-bytes", runnerMemoryBytes runner)
  , ("runner.ephemeral-bytes", runnerEphemeralBytes runner)
  , ("runner.image-import-bytes", runnerImageImportBytes runner)
  , ("runner.writable-root-bytes", runnerWritableRootBytes runner)
  , ("runner.log-bytes", runnerLogBytes runner)
  , ("runner.credential-bytes", runnerCredentialBytes runner)
  , ("runner.config-bytes", runnerConfigBytes runner)
  , ("runner.service-account-token-bytes", runnerServiceAccountTokenBytes runner)
  , ("runner.local-volume-bytes", runnerLocalVolumeBytes runner)
  , ("runner.pod-slots", runnerPodSlots runner)
  , ("runner.network-attachment-identities", runnerNetworkAttachmentIdentities runner)
  , ("runner.container-volume-mount-identities", runnerContainerVolumeMountIdentities runner)
  , ("runner.runtime-metadata-primary-bytes", runnerRuntimeMetadataPrimaryBytes runner)
  , ("runner.runtime-metadata-secondary-bytes", runnerRuntimeMetadataSecondaryBytes runner)
  , ("topic.count", topicCount topic)
  , ("topic.subscription-cursors", subscriptionCursorCount topic)
  , ("topic.hot-ledger-bytes", hotLedgerBytes topic)
  , ("topic.backlog-bytes", backlogBytes topic)
  , ("topic.offload-object-count", offloadObjectCount topic)
  , ("topic.offload-segment-bytes", offloadSegmentBytes topic)
  , ("topic.offload-concurrent-bytes", offloadConcurrentBytes topic)
  , ("topic.offload-failure-orphan-bytes", offloadFailureOrphanBytes topic)
  , ("topic.api-object-revision-bytes", apiObjectRevisionBytes topic)
  , ("topic.api-event-bytes", apiEventBytes topic)
  , ("topic.etcd-backend-peak-bytes", etcdBackendPeakBytes topic)
  ]
  where
    client = provisionClientDemand provision
    runner = provisionRunnerEnvelope provision
    topic = provisionTopicDemand provision

provisionPulsarClient :: PulsarClientProvision -> Map Text Natural -> Either [ProvisionError] ProvisionedPulsarClient
provisionPulsarClient provision capacity
  | runnerHasCache runner = Left [RunnerCacheForbidden]
  | runnerHasAccelerator runner = Left [RunnerAcceleratorForbidden]
  | runnerPodSlots runner /= 1 = Left [RunnerJobShapeInvalid]
  | null deficits = Right (ProvisionedPulsarClient required)
  | otherwise = Left deficits
  where
    runner = provisionRunnerEnvelope provision
    required = provisionTerms provision
    deficits =
      [ ProvisionDeficit term demand (Map.findWithDefault 0 term capacity)
      | (term, demand) <- Map.toAscList required
      , Map.findWithDefault 0 term capacity < demand
      ]

provisionedTerms :: ProvisionedPulsarClient -> Map Text Natural
provisionedTerms (ProvisionedPulsarClient terms) = terms
