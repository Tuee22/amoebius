{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Pulsar
  ( PulsarBackboneDemand (..)
  , ProvisionedPulsarBackbone (..)
  , Segment (..)
  , OffloadResult (..)
  , provisionPulsarBackbone
  , applySizeTriggeredOffload
  , deduplicateMessages
  , renderPulsar
  ) where

import Amoebius.Capacity.ServiceStorage
import Amoebius.Capacity.StorageGeometry
import Amoebius.Platform.Types
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data PulsarBackboneDemand = PulsarBackboneDemand
  { pulsarImage :: Text
  , pulsarBrokerReplicas :: Natural
  , pulsarBookieReplicas :: Natural
  , pulsarZooKeeperReplicas :: Natural
  , pulsarStorage :: PulsarDemand
  , pulsarMetadata :: ZooKeeperMetadataStoreDemand
  , pulsarHotTierCapBytes :: Natural
  , pulsarSizeTriggerBytes :: Maybe Natural
  , pulsarZooKeeperResources :: ResourceEnvelope
  , pulsarMetadataResources :: ResourceEnvelope
  , pulsarBookieResources :: ResourceEnvelope
  , pulsarBrokerResources :: ResourceEnvelope
  , pulsarToolResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

data ProvisionedPulsarBackbone = ProvisionedPulsarBackbone
  { provisionedPulsarDemand :: PulsarBackboneDemand
  , provisionedPulsarStorage :: PulsarStorageWitness
  , provisionedPulsarMetadata :: ProvisionedServiceStorage
  }
  deriving stock (Eq, Show)

data Segment = Segment
  { segmentIdentity :: Text
  , segmentBytes :: Natural
  }
  deriving stock (Eq, Ord, Show)

data OffloadResult = OffloadResult
  { hotSegments :: [Segment]
  , offloadedSegments :: [Segment]
  , hotBytes :: Natural
  }
  deriving stock (Eq, Show)

provisionPulsarBackbone :: PulsarBackboneDemand -> Either Text ProvisionedPulsarBackbone
provisionPulsarBackbone demand = do
  _ <- traverse validateResourceEnvelope
    [ pulsarZooKeeperResources demand
    , pulsarMetadataResources demand
    , pulsarBookieResources demand
    , pulsarBrokerResources demand
    , pulsarToolResources demand
    ]
  storage <- either (Left . Text.pack . show) Right (provisionPulsar (pulsarStorage demand))
  metadata <- either (Left . Text.pack . show) Right (provisionZooKeeperMetadataStore (pulsarMetadata demand))
  let trigger = effectiveTrigger demand
  if pulsarBrokerReplicas demand < 2 || pulsarBookieReplicas demand < 3 || pulsarZooKeeperReplicas demand < 3
    then Left "pulsar-ha-topology-required"
    else case trigger of
      Nothing -> Left "size-triggered-offload-required"
      Just value
        | value == 0 || value > pulsarHotTierCapBytes demand -> Left "size-trigger-outside-hot-tier-cap"
        | otherwise -> Right (ProvisionedPulsarBackbone demand storage metadata)
 where
#ifdef PLATFORM_BACKBONE_OFFLOAD_TIME_ONLY_MUTANT
  effectiveTrigger _ = Nothing
#else
  effectiveTrigger = pulsarSizeTriggerBytes
#endif

applySizeTriggeredOffload :: Natural -> [Segment] -> OffloadResult
applySizeTriggeredOffload cap segments = go [] segments (sum (fmap segmentBytes segments))
 where
  go moved remaining total
    | total <= cap = OffloadResult remaining (reverse moved) total
    | otherwise = case remaining of
        [] -> OffloadResult [] (reverse moved) 0
        segment : rest -> go (segment : moved) rest (total - segmentBytes segment)

deduplicateMessages :: [(Text, Natural, Text)] -> [(Text, Natural, Text)]
deduplicateMessages = go Set.empty
 where
  go _ [] = []
  go seen (message@(producer, sequenceId, _) : rest)
    | (producer, sequenceId) `Set.member` seen = go seen rest
    | otherwise = message : go (Set.insert (producer, sequenceId) seen) rest

renderPulsar :: ProvisionedPulsarBackbone -> [PlatformObject]
renderPulsar provision =
  [ object "StatefulSet" "zookeeper" (pulsarZooKeeperReplicas demand)
      [ "/bin/bash", "-ec"
      , "ordinal=${HOSTNAME##*-}; printf '%s\\n' \"$((ordinal + 1))\" > /pulsar/data/zookeeper/myid; exec /pulsar/bin/pulsar zookeeper"
      ] (pulsarZooKeeperResources demand)
  , object "Job" "pulsar-metadata" 1
      [ "/pulsar/bin/pulsar", "initialize-cluster-metadata", "--cluster", "phase30", "--zookeeper", "zookeeper:2181"
      , "--configuration-store", "zookeeper:2181", "--web-service-url", "http://broker.pulsar-system.svc.cluster.local:8080"
      , "--broker-service-url", "pulsar://broker.pulsar-system.svc.cluster.local:6650"
      ] (pulsarMetadataResources demand)
  , object "StatefulSet" "bookkeeper" (pulsarBookieReplicas demand)
      [ "/bin/bash", "-ec"
      , "cp /phase30-config/bookkeeper.conf /tmp/bookkeeper.conf; printf 'advertisedAddress=%s.bookkeeper.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/bookkeeper.conf; exec /pulsar/bin/pulsar bookie"
      ] (pulsarBookieResources demand)
  , object "StatefulSet" "broker" (pulsarBrokerReplicas demand)
      [ "/bin/bash", "-ec"
      , "cp /phase30-config/broker.conf /tmp/broker.conf; printf 'advertisedAddress=%s.broker-headless.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/broker.conf; exec /pulsar/bin/pulsar broker"
      ] (pulsarBrokerResources demand)
  , object "Deployment" "pulsar-tool" 1
      ["/bin/bash", "-ec", "exec /usr/bin/tail -f /dev/null"] (pulsarToolResources demand)
  ]
 where
  demand = provisionedPulsarDemand provision
  object kind name replicas arguments resources = PlatformObject kind "pulsar-system" name replicas (pulsarImage demand) arguments (Just resources) Nothing Nothing
