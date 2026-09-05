{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Provider per-instance root-disk instantiation.  Root EBS is charged to a
-- distinct byte/volume quota and concrete identities include the cover slot.
module Amoebius.Capacity.ProviderRoot
  ( ProviderUsableDiskCarveTemplate (..)
  , NodeRootQuota (..)
  , ProviderRootPolicy (..)
  , PerInstanceDiskDemand (..)
  , ProvisionedNodeRootVolumeRequest (..)
  , ProvisionedPerInstanceDiskTemplate (..)
  , ProviderRootError (..)
  , provisionPerInstanceDiskTemplate
  ) where

import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy
  , FilesystemPresentation
  , presentBytes
  , roundAllocation
  )
import Amoebius.Capacity.Phase29Mutation (phase29MutationTargets)
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ProviderUsableDiskCarveTemplate = ProviderUsableDiskCarveTemplate
  { providerCarveTemplateId :: Text
  , providerCarveRequiredUsableBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeRootQuota = NodeRootQuota
  { nodeRootQuotaBytes :: Natural
  , nodeRootQuotaVolumes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProviderRootPolicy
  = InstanceStore
      { instanceStoreProvisionedRawBytes :: Natural
      , instanceStorePresentation :: FilesystemPresentation
      , instanceStoreAllocation :: BackingAllocationPolicy
      }
  | EphemeralRootEbs
      { rootEbsVolumeType :: Text
      , rootEbsPresentation :: FilesystemPresentation
      , rootEbsAllocation :: BackingAllocationPolicy
      , rootEbsQuota :: NodeRootQuota
      }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PerInstanceDiskDemand = PerInstanceDiskDemand
  { perInstanceSystemReserveUsableBytes :: Natural
  , perInstanceCarves :: [ProviderUsableDiskCarveTemplate]
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedNodeRootVolumeRequest = ProvisionedNodeRootVolumeRequest
  { provisionedRootVolumeType :: Text
  , provisionedRootRequiredUsableBytes :: Natural
  , provisionedRootBytes :: Natural
  , provisionedRootSizeGiB :: Natural
  , provisionedRootPresentation :: FilesystemPresentation
  , provisionedRootAllocation :: BackingAllocationPolicy
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedPerInstanceDiskTemplate = ProvisionedPerInstanceDiskTemplate
  { provisionedPerInstanceIdentity :: Text
  , provisionedPerInstanceMountedUsableBytes :: Natural
  , provisionedPerInstanceRequiredUsableBytes :: Natural
  , provisionedPerInstanceCarves :: Map Text Natural
  , provisionedPerInstanceRootRequest :: Maybe ProvisionedNodeRootVolumeRequest
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProviderRootError
  = ProviderRootCarveAlias Text
  | ProviderInstanceStoreRootUnderprovisioned Natural Natural
  | ProviderNodeRootQuotaExceeded Natural Natural Natural Natural
  | ProviderRootIdentityInvalid Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionPerInstanceDiskTemplate
  :: Text
  -> Text
  -> Natural
  -> PerInstanceDiskDemand
  -> ProviderRootPolicy
  -> Either ProviderRootError ProvisionedPerInstanceDiskTemplate
provisionPerInstanceDiskTemplate clusterId classId coverSlot demand policy = mutateProviderResult $ do
  if Text.null clusterId || Text.null classId
    then Left (ProviderRootIdentityInvalid (clusterId <> ":" <> classId))
    else Right ()
  carveMap <- uniqueCarves (perInstanceCarves demand)
  let required = perInstanceSystemReserveUsableBytes demand + sum (Map.elems carveMap)
      identity = Text.intercalate "/" [clusterId, classId, Text.pack (show coverSlot), "root"]
  case policy of
    InstanceStore raw presentation allocation -> do
      let requiredRaw = roundAllocation allocation (presentBytes presentation required)
      if requiredRaw > raw
        then Left (ProviderInstanceStoreRootUnderprovisioned requiredRaw raw)
        else
          Right
            ProvisionedPerInstanceDiskTemplate
              { provisionedPerInstanceIdentity = identity
              , provisionedPerInstanceMountedUsableBytes = required + (raw - requiredRaw)
              , provisionedPerInstanceRequiredUsableBytes = required
              , provisionedPerInstanceCarves = qualifyCarves identity carveMap
              , provisionedPerInstanceRootRequest = Nothing
              }
    EphemeralRootEbs volumeType presentation allocation quota -> do
      let bytes = roundAllocation allocation (presentBytes presentation required)
          sizeGiB = ceilDiv bytes gibibyte
          volumes = 1
      if bytes > nodeRootQuotaBytes quota || volumes > nodeRootQuotaVolumes quota
        then Left (ProviderNodeRootQuotaExceeded bytes (nodeRootQuotaBytes quota) volumes (nodeRootQuotaVolumes quota))
        else
          let request =
                ProvisionedNodeRootVolumeRequest
                  { provisionedRootVolumeType = volumeType
                  , provisionedRootRequiredUsableBytes = required
                  , provisionedRootBytes = bytes
                  , provisionedRootSizeGiB = sizeGiB
                  , provisionedRootPresentation = presentation
                  , provisionedRootAllocation = allocation
                  }
           in Right
                ProvisionedPerInstanceDiskTemplate
                  { provisionedPerInstanceIdentity = identity
                  , provisionedPerInstanceMountedUsableBytes = required
                  , provisionedPerInstanceRequiredUsableBytes = required
                  , provisionedPerInstanceCarves = qualifyCarves identity carveMap
                  , provisionedPerInstanceRootRequest = Just request
                  }

mutateProviderResult
  :: Either ProviderRootError ProvisionedPerInstanceDiskTemplate
  -> Either ProviderRootError ProvisionedPerInstanceDiskTemplate
mutateProviderResult outcome = case outcome of
  Left ProviderInstanceStoreRootUnderprovisioned {}
    | phase29MutationTargets "instance-store-root" -> changed
  Left (ProviderNodeRootQuotaExceeded requiredBytes availableBytes requiredVolumes availableVolumes)
    | phase29MutationTargets "root-ebs-bytes-quota" && requiredBytes > availableBytes -> changed
    | phase29MutationTargets "root-ebs-volume-quota" && requiredVolumes > availableVolumes -> changed
  _ -> outcome
 where
  changed = Left (ProviderRootIdentityInvalid "phase-29 changed-production provider mutation")

uniqueCarves :: [ProviderUsableDiskCarveTemplate] -> Either ProviderRootError (Map Text Natural)
uniqueCarves carves
  | length carves /= Set.size (Set.fromList (fmap providerCarveTemplateId carves)) =
      Left (ProviderRootCarveAlias (duplicateId (sortOn providerCarveTemplateId carves)))
  | otherwise = Right (Map.fromList [(providerCarveTemplateId carve, providerCarveRequiredUsableBytes carve) | carve <- carves])

duplicateId :: [ProviderUsableDiskCarveTemplate] -> Text
duplicateId carves = go "duplicate" carves
 where
  go fallback remaining = case remaining of
    first : second : rest
      | providerCarveTemplateId first == providerCarveTemplateId second -> providerCarveTemplateId first
      | otherwise -> go fallback (second : rest)
    _ -> fallback

qualifyCarves :: Text -> Map Text Natural -> Map Text Natural
qualifyCarves prefix = Map.fromList . fmap (\(identity, bytes) -> (prefix <> "/" <> identity, bytes)) . Map.toList

gibibyte :: Natural
gibibyte = 1024 * 1024 * 1024

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator
  | denominator == 0 = 0
  | otherwise = (numerator + denominator - 1) `div` denominator
