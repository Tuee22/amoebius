{-# LANGUAGE OverloadedStrings #-}

-- | Pure signal-to-node-set planning.  This module cannot call a provider; it
-- only produces a quota- and observation-bound decision.
module Amoebius.Cluster.NodeProvisioner
  ( Signal (..)
  , Capability (..)
  , ProviderNodeClass (..)
  , ObservedNodeLimits (..)
  , ProviderQuota (..)
  , NodeDemand (..)
  , NodeObservation (..)
  , NodePlan (..)
  , NodeProvisionError (..)
  , planNodeSet
  , cloudMutationPermitted
  , providerPhysicalIdentity
  ) where

import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data Signal = WorkflowCompletion Bool | Load Bool
  deriving stock (Eq, Show)

data Capability = Cpu | Cuda
  deriving stock (Eq, Show)

data ProviderNodeClass = ProviderNodeClass
  { nodeClassName :: Text
  , nodeClassVcpu :: Natural
  , nodeClassCpuMillis :: Natural
  , nodeClassMemoryBytes :: Natural
  , nodeClassPodEphemeralBytes :: Natural
  , nodeClassPodSlots :: Natural
  , nodeClassCniSlots :: Natural
  , nodeClassCsiAttachSlots :: Natural
  , nodeClassRootEbsBytes :: Natural
  , nodeClassHasCuda :: Bool
  , nodeClassBaseCount :: Natural
  , nodeClassMaximumCount :: Natural
  }
  deriving stock (Eq, Show)

data ObservedNodeLimits = ObservedNodeLimits
  { observedKubeletPodSlots :: Natural
  , observedCniSlots :: Natural
  , observedCsiAttachSlots :: Natural
  }
  deriving stock (Eq, Show)

data ProviderQuota = ProviderQuota
  { quotaInstances :: Natural
  , quotaVcpu :: Natural
  , quotaRootEbsBytes :: Natural
  , quotaRootEbsCount :: Natural
  }
  deriving stock (Eq, Show)

data NodeDemand = NodeDemand
  { demandCpuMillis :: Natural
  , demandMemoryBytes :: Natural
  , demandPodEphemeralBytes :: Natural
  , demandPods :: Natural
  , demandCsiClaims :: [Text]
  , demandCapability :: Capability
  }
  deriving stock (Eq, Show)

data NodeObservation = Present | Absent | Unreachable
  deriving stock (Eq, Show)

data NodePlan = NodeNoOp Natural | AddNode Natural | RemoveNode Natural
  deriving stock (Eq, Show)

data NodeProvisionError
  = InvalidElasticCount
  | ProviderInstanceQuotaExceeded
  | ProviderVcpuQuotaExceeded
  | ProviderRootEbsBytesExceeded
  | ProviderRootEbsCountExceeded
  | MissingCapability Capability
  | NoCpuCover
  | NoMemoryCover
  | NoPodEphemeralCover
  | NoPodSlotCover
  | NoCsiAttachSlotCover
  | RefuseOnUnreachable
  deriving stock (Eq, Show)

planNodeSet
  :: ProviderNodeClass
  -> ObservedNodeLimits
  -> ProviderQuota
  -> NodeDemand
  -> Signal
  -> Natural
  -> NodeObservation
  -> Either NodeProvisionError NodePlan
planNodeSet nodeClass observed quota demand signal current observation = do
  if nodeClassBaseCount nodeClass > nodeClassMaximumCount nodeClass then Left InvalidElasticCount else Right ()
  if nodeClassMaximumCount nodeClass > quotaInstances quota then Left ProviderInstanceQuotaExceeded else Right ()
  if nodeClassMaximumCount nodeClass * nodeClassVcpu nodeClass > quotaVcpu quota then Left ProviderVcpuQuotaExceeded else Right ()
  if nodeClassMaximumCount nodeClass * nodeClassRootEbsBytes nodeClass > quotaRootEbsBytes quota then Left ProviderRootEbsBytesExceeded else Right ()
  if nodeClassMaximumCount nodeClass > quotaRootEbsCount quota then Left ProviderRootEbsCountExceeded else Right ()
  case demandCapability demand of
    Cuda | not (nodeClassHasCuda nodeClass) -> Left (MissingCapability Cuda)
    _ -> Right ()
  if demandCpuMillis demand > nodeClassCpuMillis nodeClass then Left NoCpuCover else Right ()
  if demandMemoryBytes demand > nodeClassMemoryBytes nodeClass then Left NoMemoryCover else Right ()
  if demandPodEphemeralBytes demand > nodeClassPodEphemeralBytes nodeClass then Left NoPodEphemeralCover else Right ()
  if demandPods demand > podLimit then Left NoPodSlotCover else Right ()
  if requiredAttachments > attachLimit then Left NoCsiAttachSlotCover else Right ()
  case compare current target of
    LT -> Right (AddNode target)
    EQ -> Right (NodeNoOp target)
    GT -> case observation of
      Unreachable -> Left RefuseOnUnreachable
      Present -> Right (RemoveNode target)
      Absent -> Right (RemoveNode target)
 where
  active = case signal of WorkflowCompletion value -> value; Load value -> value
  target = min (nodeClassMaximumCount nodeClass) (nodeClassBaseCount nodeClass + if active then 1 else 0)
  podLimit = minimum [nodeClassPodSlots nodeClass, nodeClassCniSlots nodeClass, observedKubeletPodSlots observed, observedCniSlots observed]
  requiredAttachments = fromIntegral (Set.size (Set.fromList (demandCsiClaims demand)))
  attachLimit = min (nodeClassCsiAttachSlots nodeClass) (observedCsiAttachSlots observed)

cloudMutationPermitted :: Either NodeProvisionError NodePlan -> Bool
cloudMutationPermitted (Right (AddNode _)) = True
cloudMutationPermitted (Right (RemoveNode _)) = True
cloudMutationPermitted _ = False

providerPhysicalIdentity :: Text -> Text -> Text -> Natural -> Text -> Text
providerPhysicalIdentity account cluster nodeClass ordinal templatePath =
  Text.intercalate "/" [account, cluster, nodeClass, Text.pack (show ordinal), templatePath]
