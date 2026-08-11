{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Service-specific storage peaks.  Inputs remain logical declarations;
-- successful results carry the backing fit that a later provision seal can
-- retain without re-authoring the byte total.
module Amoebius.Capacity.ServiceStorage
  ( CacheAsset (..)
  , CachePopulationDemand (..)
  , CachePlacement (..)
  , ProvisionedCacheDemand (..)
  , RegistryStorageDemand (..)
  , ZooKeeperMetadataStoreDemand (..)
  , PatroniSqlDemand (..)
  , VaultStorageDemand (..)
  , ControlPlaneStorageDemand (..)
  , ProvisionedServiceStorage (..)
  , provisionCacheDemand
  , registryStoragePeak
  , provisionZooKeeperMetadataStore
  , provisionPatroniSql
  , vaultStoragePeak
  , provisionControlPlaneStorage
  ) where

import Amoebius.Capacity.Storage
  ( StorageBacking
  , StorageError (..)
  , StorageWitness
  , fitBacking
  )
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data CacheAsset = CacheAsset
  { cacheAssetIdentity :: Text
  , cacheAssetDigest :: Text
  , cacheResidentBytes :: Natural
  , cacheTemporaryBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data CachePopulationDemand = CachePopulationDemand
  { cachePopulationName :: Text
  , cachePopulationAssets :: [CacheAsset]
  , cacheFirstMissConcurrency :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data CachePlacement
  = InClusterCache
      { cacheBudgetBytes :: Natural
      , cacheEmptyDirBytes :: Natural
      }
  | NativeCache
      { cacheBudgetBytes :: Natural
      , cacheBacking :: StorageBacking
      }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedCacheDemand = ProvisionedCacheDemand
  { provisionedCacheName :: Text
  , provisionedCacheDerivedPeak :: Natural
  , provisionedCacheBackingWitness :: Maybe StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RegistryStorageDemand = RegistryStorageDemand
  { registryName :: Text
  , registryObjects :: [(Text, Natural)]
  , registryConcurrentUploads :: Natural
  , registryMaximumUploadBytes :: Natural
  , registryFailedUploadsPerWindow :: Natural
  , registryBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ZooKeeperMetadataStoreDemand = ZooKeeperMetadataStoreDemand
  { zooKeeperName :: Text
  , zooKeeperMembers :: Natural
  , zooKeeperPathsBytesPerMember :: Natural
  , zooKeeperTransactionLogBytesPerMember :: Natural
  , zooKeeperSnapshotBytesPerMember :: Natural
  , zooKeeperRecoveryBytesPerMember :: Natural
  , zooKeeperBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PatroniSqlDemand = PatroniSqlDemand
  { patroniName :: Text
  , patroniDataBytes :: Natural
  , patroniWalBytes :: Natural
  , patroniCheckpointBytes :: Natural
  , patroniFailoverReplayBytes :: Natural
  , patroniRecoveryWorkspaceBytes :: Natural
  , patroniBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data VaultStorageDemand = VaultStorageDemand
  { vaultName :: Text
  , vaultPersistedVersionBytes :: Natural
  , vaultLiveLeaseBytes :: Natural
  , vaultRaftWalBytes :: Natural
  , vaultSnapshotBytes :: Natural
  , vaultCompactionBytes :: Natural
  , vaultRecoveryBytes :: Natural
  , vaultAuditMaximumFileBytes :: Natural
  , vaultAuditBackups :: Natural
  , vaultBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ControlPlaneStorageDemand = ControlPlaneStorageDemand
  { controlPlaneName :: Text
  , controlPlaneMvccBytes :: Natural
  , controlPlaneWalSegmentBytes :: Natural
  , controlPlaneMaxWalFiles :: Natural
  , controlPlaneWalOvershootBytes :: Natural
  , controlPlaneRetainedSnapshots :: Natural
  , controlPlaneSnapshotBytes :: Natural
  , controlPlaneDefragBytes :: Natural
  , controlPlaneAuditMaximumFileBytes :: Natural
  , controlPlaneAuditBackups :: Natural
  , controlPlaneBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedServiceStorage = ProvisionedServiceStorage
  { serviceStorageName :: Text
  , serviceStoragePeakBytes :: Natural
  , serviceStorageWitness :: StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionCacheDemand :: CachePopulationDemand -> CachePlacement -> Either StorageError ProvisionedCacheDemand
provisionCacheDemand demand placement =
  let peak = cachePeak demand
   in case placement of
        InClusterCache budget emptyDir
          | peak > budget -> Left (CacheBudgetNestingViolation (cachePopulationName demand) peak budget)
          | budget > emptyDir -> Left (CacheBudgetNestingViolation (cachePopulationName demand) budget emptyDir)
          | otherwise -> Right (ProvisionedCacheDemand (cachePopulationName demand) peak Nothing)
        NativeCache budget backing
          | peak > budget -> Left (CacheBudgetNestingViolation (cachePopulationName demand) peak budget)
          | otherwise -> do
              witness <- fitBacking backing budget
              pure (ProvisionedCacheDemand (cachePopulationName demand) peak (Just witness))

registryStoragePeak :: RegistryStorageDemand -> Either StorageError ProvisionedServiceStorage
registryStoragePeak demand = provisionService (registryName demand) peak (registryBacking demand)
 where
  residents = sum (Map.elems (Map.fromListWith max (registryObjects demand)))
  uploads = registryConcurrentUploads demand * registryMaximumUploadBytes demand
  failed = registryFailedUploadsPerWindow demand * registryMaximumUploadBytes demand
  peak = residents + uploads + failed

provisionZooKeeperMetadataStore :: ZooKeeperMetadataStoreDemand -> Either StorageError ProvisionedServiceStorage
provisionZooKeeperMetadataStore demand = provisionService (zooKeeperName demand) peak (zooKeeperBacking demand)
 where
  perMember =
    zooKeeperPathsBytesPerMember demand
      + zooKeeperTransactionLogBytesPerMember demand
      + zooKeeperSnapshotBytesPerMember demand
      + zooKeeperRecoveryBytesPerMember demand
  peak = zooKeeperMembers demand * perMember

provisionPatroniSql :: PatroniSqlDemand -> Either StorageError ProvisionedServiceStorage
provisionPatroniSql demand = provisionService (patroniName demand) peak (patroniBacking demand)
 where
  peak =
    patroniDataBytes demand
      + patroniWalBytes demand
      + patroniCheckpointBytes demand
      + patroniFailoverReplayBytes demand
      + patroniRecoveryWorkspaceBytes demand

vaultStoragePeak :: VaultStorageDemand -> Either StorageError ProvisionedServiceStorage
vaultStoragePeak demand = provisionService (vaultName demand) peak (vaultBacking demand)
 where
  raftPeak =
    vaultPersistedVersionBytes demand
      + vaultLiveLeaseBytes demand
      + vaultRaftWalBytes demand
      + vaultSnapshotBytes demand
      + vaultCompactionBytes demand
      + vaultRecoveryBytes demand
  auditPeak = (vaultAuditBackups demand + 1) * vaultAuditMaximumFileBytes demand
  peak = raftPeak + auditPeak

provisionControlPlaneStorage :: ControlPlaneStorageDemand -> Either StorageError ProvisionedServiceStorage
provisionControlPlaneStorage demand = provisionService (controlPlaneName demand) peak (controlPlaneBacking demand)
 where
  walPeak =
    (controlPlaneMaxWalFiles demand + 1) * controlPlaneWalSegmentBytes demand
      + controlPlaneWalOvershootBytes demand
  snapshots =
    (controlPlaneRetainedSnapshots demand + 1) * controlPlaneSnapshotBytes demand
  defragOldAndNew = controlPlaneMvccBytes demand + controlPlaneDefragBytes demand
  audit = (controlPlaneAuditBackups demand + 1) * controlPlaneAuditMaximumFileBytes demand
  peak = controlPlaneMvccBytes demand + walPeak + snapshots + defragOldAndNew + audit

cachePeak :: CachePopulationDemand -> Natural
cachePeak demand = residents + sumLargest (cacheFirstMissConcurrency demand) temporaries
 where
  byDigest =
    Map.fromListWith
      combine
      [ (cacheAssetDigest asset, (cacheResidentBytes asset, cacheTemporaryBytes asset))
      | asset <- cachePopulationAssets demand
      ]
  combine (residentA, temporaryA) (residentB, temporaryB) = (max residentA residentB, max temporaryA temporaryB)
  residents = sum [resident | (resident, _) <- Map.elems byDigest]
  temporaries = [temporary | (_, temporary) <- Map.elems byDigest]

sumLargest :: Natural -> [Natural] -> Natural
sumLargest count values = sum (take (fromIntegral count) (reverse (sortOn id values)))

provisionService :: Text -> Natural -> StorageBacking -> Either StorageError ProvisionedServiceStorage
provisionService name peak backing = do
  witness <- fitBacking backing peak
  pure (ProvisionedServiceStorage name peak witness)
