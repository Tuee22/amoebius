{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Fabric.WgReconcile
  ( FabricSystemDemand (..)
  , FabricNodeDemand (..)
  , LogPolicy (..)
  , FabricCapacity (..)
  , ProvisionError (..)
  , ProvisionedFabricDemand
  , ValidatedFabricEnactment
  , EnactmentState (..)
  , KernelObservation (..)
  , FabricAction (..)
  , representativeDemand
  , provisionFabricDemand
  , provisionedDemandJson
  , validateSnapshot
  , authorizeEnactment
  , reconcileActions
  , replacementActions
  ) where

import Amoebius.Fabric.WgRender
import Data.Aeson (Value, object, (.=))
import Data.List (sort, sortOn)
import Data.Text (Text)

data LogPolicy = LogPolicy
  { logMaxBytesPerFile :: Integer
  , logMaxBackups :: Int
  , logRetentionSeconds :: Integer
  }
  deriving stock (Eq, Show)

data FabricSystemDemand = FabricSystemDemand
  { demandCostModel :: Text
  , demandMaxPacketsPerSecond :: Integer
  , demandMaxPacketBytes :: Integer
  , demandMaxQueuedBytes :: Integer
  , demandLogPolicy :: LogPolicy
  , demandCpuReservationMilli :: Integer
  , demandCpuCeilingMilli :: Integer
  , demandMemoryReservationBytes :: Integer
  , demandMemoryCeilingBytes :: Integer
  , demandWritableBytes :: Integer
  , demandHostProcessSlots :: Integer
  , demandListenerPort :: Int
  }
  deriving stock (Eq, Show)

data FabricNodeDemand = FabricNodeDemand
  { nodeDemandNodeId :: Text
  , nodeDemandPeerIds :: [Text]
  , nodeDemandCpuReservationMilli :: Integer
  , nodeDemandCpuCeilingMilli :: Integer
  , nodeDemandMemoryReservationBytes :: Integer
  , nodeDemandMemoryCeilingBytes :: Integer
  , nodeDemandNodeFsBytes :: Integer
  , nodeDemandHostProcessSlots :: Integer
  , nodeDemandListenerPort :: Int
  }
  deriving stock (Eq, Show)

data FabricCapacity = FabricCapacity
  { capacityCpuReservationMilli :: Integer
  , capacityCpuCeilingMilli :: Integer
  , capacityMemoryReservationBytes :: Integer
  , capacityMemoryCeilingBytes :: Integer
  , capacityNodeFsBytes :: Integer
  , capacityQueueBytes :: Integer
  , capacityHostProcessSlots :: Integer
  }
  deriving stock (Eq, Show)

data ProvisionError
  = UnlimitedFabricOperand Text
  | TopologyPeerMismatch Text
  | CpuReservationShort
  | CpuCeilingShort
  | MemoryReservationShort
  | MemoryCeilingShort
  | NodeFsShort
  | QueueShort
  | HostProcessSlotShort
  | SnapshotChanged
  | MissingEnactmentToken
  | EnactmentAlreadyConsumed
  deriving stock (Eq, Show)

data ProvisionedFabricDemand = ProvisionedFabricDemand FabricInventory FabricSystemDemand [FabricNodeDemand]
  deriving stock (Eq, Show)

data ValidatedFabricEnactment = ValidatedFabricEnactment Text ProvisionedFabricDemand
  deriving stock (Eq, Show)

data EnactmentState = Fresh ValidatedFabricEnactment | Consumed
  deriving stock (Eq, Show)

data KernelObservation = KernelObservation
  { observedInterfacePresent :: Bool
  , observedPeerIds :: [Text]
  , observedQueueConfigured :: Bool
  , observedListenerReady :: Bool
  }
  deriving stock (Eq, Show)

data FabricAction
  = CreateInterface
  | SetPrivateKeyByReference
  | SetPeers [Text]
  | SetQueueBounds
  | StartListener
  | ObserveOldListenerExit
  | StartReplacementListener
  deriving stock (Eq, Show)

representativeDemand :: FabricSystemDemand
representativeDemand = FabricSystemDemand
  { demandCostModel = "network-fabric-v1"
  , demandMaxPacketsPerSecond = 2000
  , demandMaxPacketBytes = 1280
  , demandMaxQueuedBytes = 65536
  , demandLogPolicy = LogPolicy 65536 2 86400
  , demandCpuReservationMilli = 25
  , demandCpuCeilingMilli = 100
  , demandMemoryReservationBytes = 8388608
  , demandMemoryCeilingBytes = 33554432
  , demandWritableBytes = 1048576
  , demandHostProcessSlots = 1
  , demandListenerPort = 19410
  }

provisionFabricDemand :: FabricInventory -> FabricSystemDemand -> Either ProvisionError ProvisionedFabricDemand
provisionFabricDemand inventory demand = do
  requirePositive "maxPacketsPerSecond" (demandMaxPacketsPerSecond demand)
  requirePositive "maxPacketBytes" (demandMaxPacketBytes demand)
  requirePositive "maxQueuedBytes" (demandMaxQueuedBytes demand)
  requirePositive "logMaxBytesPerFile" (logMaxBytesPerFile (demandLogPolicy demand))
  if logMaxBackups (demandLogPolicy demand) < 0
    then Left (UnlimitedFabricOperand "logMaxBackups")
    else Right ()
  rendered <- either (const (Left (TopologyPeerMismatch "render-failed"))) Right (renderFabric inventory)
  let rows = map (nodeRow demand) rendered
  if sort (map nodeDemandNodeId rows) == sort (map peerNodeId (fabricPeers inventory))
    then Right (ProvisionedFabricDemand inventory demand rows)
    else Left (TopologyPeerMismatch "node-set")

nodeRow :: FabricSystemDemand -> RenderedNode -> FabricNodeDemand
nodeRow demand node = FabricNodeDemand
  { nodeDemandNodeId = renderedNodeId node
  , nodeDemandPeerIds = sort (map renderedPeerNodeId (renderedPeers node))
  , nodeDemandCpuReservationMilli = demandCpuReservationMilli demand
  , nodeDemandCpuCeilingMilli = demandCpuCeilingMilli demand
  , nodeDemandMemoryReservationBytes = demandMemoryReservationBytes demand
  , nodeDemandMemoryCeilingBytes = demandMemoryCeilingBytes demand
  , nodeDemandNodeFsBytes = demandWritableBytes demand + rotationBytes (demandLogPolicy demand)
  , nodeDemandHostProcessSlots = demandHostProcessSlots demand
  , nodeDemandListenerPort = demandListenerPort demand
  }

rotationBytes :: LogPolicy -> Integer
rotationBytes policy = fromIntegral (logMaxBackups policy + 1) * logMaxBytesPerFile policy

provisionedDemandJson :: ProvisionedFabricDemand -> Value
provisionedDemandJson (ProvisionedFabricDemand inventory demand rows) = object
  [ "costModel" .= demandCostModel demand
  , "fabricCidr" .= fabricCidr inventory
  , "interfaceName" .= fabricInterfaceName inventory
  , "maxPacketBytes" .= demandMaxPacketBytes demand
  , "maxPacketsPerSecond" .= demandMaxPacketsPerSecond demand
  , "maxQueuedBytes" .= demandMaxQueuedBytes demand
  , "logPolicy" .= object
      [ "maxBackups" .= logMaxBackups (demandLogPolicy demand)
      , "maxBytesPerFile" .= logMaxBytesPerFile (demandLogPolicy demand)
      , "retentionSeconds" .= logRetentionSeconds (demandLogPolicy demand)
      ]
  , "nodes" .= map rowJson (sortOn nodeDemandNodeId rows)
  ]
 where
  rowJson row = object
    [ "cpuCeilingMilli" .= nodeDemandCpuCeilingMilli row
    , "cpuReservationMilli" .= nodeDemandCpuReservationMilli row
    , "hostProcessSlots" .= nodeDemandHostProcessSlots row
    , "listenerPort" .= nodeDemandListenerPort row
    , "memoryCeilingBytes" .= nodeDemandMemoryCeilingBytes row
    , "memoryReservationBytes" .= nodeDemandMemoryReservationBytes row
    , "nodeFsBytes" .= nodeDemandNodeFsBytes row
    , "nodeId" .= nodeDemandNodeId row
    , "peerIds" .= nodeDemandPeerIds row
    ]

validateSnapshot :: Text -> FabricCapacity -> ProvisionedFabricDemand -> Either ProvisionError ValidatedFabricEnactment
validateSnapshot fingerprint capacity provisioned@(ProvisionedFabricDemand _ demand rows) = do
  mapM_ (fitRow capacity demand) rows
  pure (ValidatedFabricEnactment fingerprint provisioned)

fitRow :: FabricCapacity -> FabricSystemDemand -> FabricNodeDemand -> Either ProvisionError ()
fitRow capacity demand row
  | capacityCpuReservationMilli capacity < nodeDemandCpuReservationMilli row = Left CpuReservationShort
  | capacityCpuCeilingMilli capacity < nodeDemandCpuCeilingMilli row = Left CpuCeilingShort
  | capacityMemoryReservationBytes capacity < nodeDemandMemoryReservationBytes row = Left MemoryReservationShort
  | capacityMemoryCeilingBytes capacity < nodeDemandMemoryCeilingBytes row = Left MemoryCeilingShort
  | capacityNodeFsBytes capacity < nodeDemandNodeFsBytes row = Left NodeFsShort
  | capacityQueueBytes capacity < demandMaxQueuedBytes demand = Left QueueShort
  | capacityHostProcessSlots capacity < nodeDemandHostProcessSlots row = Left HostProcessSlotShort
  | otherwise = Right ()

authorizeEnactment :: Text -> Maybe EnactmentState -> Either ProvisionError EnactmentState
authorizeEnactment currentFingerprint maybeState =
#ifdef NETWORK_FABRIC_WIREGUARD_DROP_RESOURCE_ENVELOPE_MUTANT
  case maybeState of
    Nothing -> Right Consumed
    Just _ -> Right Consumed
#else
  case maybeState of
    Nothing -> Left MissingEnactmentToken
    Just Consumed -> Left EnactmentAlreadyConsumed
    Just (Fresh (ValidatedFabricEnactment fingerprint _))
      | fingerprint /= currentFingerprint -> Left SnapshotChanged
      | otherwise -> Right Consumed
#endif

reconcileActions :: [RenderedNode] -> KernelObservation -> [FabricAction]
reconcileActions desired observed =
  let peers = sort (concatMap (map renderedPeerNodeId . renderedPeers) desired)
  in concat
    [ [CreateInterface | not (observedInterfacePresent observed)]
    , [SetPrivateKeyByReference | not (observedInterfacePresent observed)]
    , [SetPeers peers | sort (observedPeerIds observed) /= peers]
    , [SetQueueBounds | not (observedQueueConfigured observed)]
    , [StartListener | not (observedListenerReady observed)]
    ]

replacementActions :: Bool -> [FabricAction]
replacementActions oldProcessPresent =
#ifdef NETWORK_FABRIC_WIREGUARD_EARLY_LISTENER_REPLACEMENT_MUTANT
  if oldProcessPresent then [StartReplacementListener] else [StartReplacementListener]
#else
  if oldProcessPresent then [ObserveOldListenerExit] else [StartReplacementListener]
#endif

requirePositive :: Text -> Integer -> Either ProvisionError ()
requirePositive label value
  | value > 0 = Right ()
  | otherwise = Left (UnlimitedFabricOperand label)
