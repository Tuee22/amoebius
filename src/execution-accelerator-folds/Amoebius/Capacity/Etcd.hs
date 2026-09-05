{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Desired/live API-object transition and the separate etcd physical
-- WAL/snapshot/defrag high-water derivation.
module Amoebius.Capacity.Etcd
  ( EtcdLogicalDemand (..)
  , EtcdStorageModel (..)
  , ProvisionedEtcdLogicalDemand (..)
  , ProvisionedEtcdDemand (..)
  , EtcdError (..)
  , provisionEtcdDemand
  ) where

import Amoebius.Capacity.Phase29Mutation (phase29MutationTargets)
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data EtcdLogicalDemand = EtcdLogicalDemand
  { etcdDesiredObjectBytes :: Natural
  , etcdLiveOldObjectBytes :: Natural
  , etcdApplyObjectBytes :: Natural
  , etcdRevisionChurnBytes :: Natural
  , etcdLeaseBytes :: Natural
  , etcdEventBytes :: Natural
  , etcdBackendQuotaBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EtcdStorageModel = EtcdStorageModel
  { etcdWalSegmentBytes :: Natural
  , etcdMaxWalFiles :: Natural
  , etcdWalOvershootBytes :: Natural
  , etcdPreallocatedNextWalBytes :: Natural
  , etcdRetainedSnapshots :: Natural
  , etcdSnapshotBytes :: Natural
  , etcdSnapshotSaveTemporaryBytes :: Natural
  , etcdDefragOldBytes :: Natural
  , etcdDefragNewBytes :: Natural
  , etcdMaxBackups :: Natural
  , etcdMaxLogBytesPerFile :: Natural
  , etcdSystemCarveBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedEtcdLogicalDemand = ProvisionedEtcdLogicalDemand
  { provisionedEtcdLogicalPeakBytes :: Natural
  , provisionedEtcdLogicalResidualBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedEtcdDemand = ProvisionedEtcdDemand
  { provisionedEtcdLogical :: ProvisionedEtcdLogicalDemand
  , provisionedEtcdPhysicalPeakBytes :: Natural
  , provisionedEtcdPhysicalResidualBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EtcdError
  = EtcdLogicalQuotaExceeded Natural Natural
  | EngineStorageOvercommit Text Natural Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionEtcdDemand :: EtcdLogicalDemand -> EtcdStorageModel -> Either EtcdError ProvisionedEtcdDemand
provisionEtcdDemand logical model = mutateEtcdResult original
 where
  original
    | logicalPeak > etcdBackendQuotaBytes logical = Left (EtcdLogicalQuotaExceeded logicalPeak (etcdBackendQuotaBytes logical))
    | physicalPeak > etcdSystemCarveBytes model = Left (EngineStorageOvercommit "etcd" physicalPeak (etcdSystemCarveBytes model))
    | otherwise =
      Right
        ProvisionedEtcdDemand
          { provisionedEtcdLogical =
              ProvisionedEtcdLogicalDemand
                { provisionedEtcdLogicalPeakBytes = logicalPeak
                , provisionedEtcdLogicalResidualBytes = etcdBackendQuotaBytes logical - logicalPeak
                }
          , provisionedEtcdPhysicalPeakBytes = physicalPeak
          , provisionedEtcdPhysicalResidualBytes = etcdSystemCarveBytes model - physicalPeak
          }
  logicalPeak =
    etcdDesiredObjectBytes logical
      + etcdLiveOldObjectBytes logical
      + etcdApplyObjectBytes logical
      + etcdRevisionChurnBytes logical
      + etcdLeaseBytes logical
      + etcdEventBytes logical
  wal =
    etcdWalSegmentBytes model * etcdMaxWalFiles model
      + etcdWalOvershootBytes model
      + etcdPreallocatedNextWalBytes model
  snapshots = etcdRetainedSnapshots model * etcdSnapshotBytes model + etcdSnapshotSaveTemporaryBytes model
  defrag = etcdDefragOldBytes model + etcdDefragNewBytes model
  logs = (etcdMaxBackups model + 1) * etcdMaxLogBytesPerFile model
  physicalPeak = etcdBackendQuotaBytes logical + wal + snapshots + defrag + logs

mutateEtcdResult :: Either EtcdError ProvisionedEtcdDemand -> Either EtcdError ProvisionedEtcdDemand
mutateEtcdResult outcome = case outcome of
  Left EngineStorageOvercommit {}
    | phase29MutationTargets "etcd-transition-physical" ->
        Left (EtcdLogicalQuotaExceeded 1 0)
  _ -> outcome
