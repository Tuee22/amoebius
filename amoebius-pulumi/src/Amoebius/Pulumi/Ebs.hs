{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure admission model for one durable provider volume per claim.  The
-- constructors that represent a promised or materialized volume remain
-- private so a provider id can enter only through checked receipt readback.
module Amoebius.Pulumi.Ebs
  ( AllocationPolicy (..)
  , ProviderVolumeDemand (..)
  , ProviderVolumeRequest (..)
  , ProviderQuotaSnapshot (..)
  , ProviderVolumeError (..)
  , ValidatedProviderVolumeAction
  , ProviderCreateReceipt (..)
  , MaterializedProviderVolume
  , DurableCheckpointNamespace
  , CopyExecution (..)
  , StorageMigrationDemand (..)
  , MigrationSupply (..)
  , MigrationError (..)
  , ProvisionedStorageMigration
  , validateProviderVolume
  , validatedRequest
  , promisedSlotId
  , materializeProviderVolume
  , materializedVolumeId
  , materializedRequest
  , mkDurableCheckpointNamespace
  , durableCheckpointKey
  , durableCheckpointProtected
  , durableCheckpointRetained
  , provisionStorageMigration
  , migrationDurableBytes
  , migrationVolumeCount
  , migrationAttachmentCount
  , migrationCopyExecutionPresent
  , migrationOldRemainsCharged
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

gib :: Natural
gib = 1073741824

data AllocationPolicy = AllocationPolicy
  { allocationMinimumBytes :: Natural
  , allocationQuantumBytes :: Natural
  }
  deriving stock (Eq, Show)

data ProviderVolumeDemand = ProviderVolumeDemand
  { demandAccountFingerprint :: Text
  , demandCluster :: Text
  , demandClaim :: Text
  , demandVolumeType :: Text
  , demandZone :: Text
  , demandRequiredUsableBytes :: Natural
  , demandPresentation :: Text
  , demandAllocation :: AllocationPolicy
  }
  deriving stock (Eq, Show)

data ProviderVolumeRequest = ProviderVolumeRequest
  { requestVolumeType :: Text
  , requestZone :: Text
  , requestRequiredUsableBytes :: Natural
  , requestSizeGiB :: Natural
  , requestProvisionedBytes :: Natural
  , requestPresentation :: Text
  }
  deriving stock (Eq, Show)

data ProviderQuotaSnapshot = ProviderQuotaSnapshot
  { quotaAccountFingerprint :: Text
  , quotaDurableResidualBytes :: Natural
  , quotaDurableResidualVolumes :: Natural
  }
  deriving stock (Eq, Show)

data ProviderVolumeError
  = EmptyProviderVolumeIdentity
  | InvalidAllocationQuantum
  | ProviderAccountSnapshotChanged
  | DurableProviderBytesInsufficient
  | DurableProviderVolumeCountInsufficient
  | ProviderCreateReceiptMismatch
  | ProviderVolumeIdEmpty
  | CheckpointClassCollapsed
  deriving stock (Eq, Show)

data ValidatedProviderVolumeAction = ValidatedProviderVolumeAction
  { actionRequest :: ProviderVolumeRequest
  , actionSlot :: Text
  , actionAccountFingerprint :: Text
  }
  deriving stock (Eq, Show)

data ProviderCreateReceipt = ProviderCreateReceipt
  { receiptAccountFingerprint :: Text
  , receiptSlotId :: Text
  , receiptVolumeId :: Text
  , receiptProvisionedBytes :: Natural
  , receiptZone :: Text
  }
  deriving stock (Eq, Show)

data MaterializedProviderVolume = MaterializedProviderVolume
  { materializedId :: Text
  , materializedSlot :: Text
  , materializedProviderRequest :: ProviderVolumeRequest
  }
  deriving stock (Eq, Show)

data DurableCheckpointNamespace = DurableCheckpointNamespace
  { checkpointObjectKey :: Text
  , checkpointProtect :: Bool
  , checkpointRetain :: Bool
  }
  deriving stock (Eq, Show)

data CopyExecution = CopyExecution
  { copyCpuMillis :: Natural
  , copyMemoryBytes :: Natural
  , copyPodEphemeralBytes :: Natural
  , copyPodSlots :: Natural
  }
  deriving stock (Eq, Show)

data StorageMigrationDemand = StorageMigrationDemand
  { migrationOldBytesDemand :: Natural
  , migrationReplacementBytesDemand :: Natural
  , migrationWorkspaceBytesDemand :: Natural
  , migrationCopyExecutionDemand :: CopyExecution
  , migrationAttachmentDemand :: Natural
  }
  deriving stock (Eq, Show)

data MigrationSupply = MigrationSupply
  { supplyDurableBytes :: Natural
  , supplyDurableVolumeCount :: Natural
  , supplyWorkspaceBytes :: Natural
  , supplyCopyCpuMillis :: Natural
  , supplyCopyMemoryBytes :: Natural
  , supplyCopyPodEphemeralBytes :: Natural
  , supplyPodSlots :: Natural
  , supplyCsiAttachSlots :: Natural
  }
  deriving stock (Eq, Show)

data MigrationError
  = DurableBytesOneShort
  | DurableVolumeCountOneShort
  | WorkspaceOneShort
  | CopyCpuOneShort
  | CopyMemoryOneShort
  | CopyPodEphemeralOneShort
  | PodSlotsOneShort
  | CsiAttachSlotsOneShort
  deriving stock (Eq, Show)

data ProvisionedStorageMigration = ProvisionedStorageMigration
  { provisionedMigrationDurableBytes :: Natural
  , provisionedMigrationVolumeCount :: Natural
  , provisionedMigrationAttachments :: Natural
  , provisionedMigrationCopyExecution :: Maybe CopyExecution
  , provisionedMigrationOldCharged :: Bool
  }
  deriving stock (Eq, Show)

validateProviderVolume
  :: ProviderQuotaSnapshot
  -> ProviderVolumeDemand
  -> Either ProviderVolumeError ValidatedProviderVolumeAction
validateProviderVolume snapshot demand
  | any Text.null [demandCluster demand, demandClaim demand, demandVolumeType demand, demandZone demand, demandPresentation demand] =
      Left EmptyProviderVolumeIdentity
  | allocationQuantumBytes policy == 0 = Left InvalidAllocationQuantum
  | quotaAccountFingerprint snapshot /= demandAccountFingerprint demand = Left ProviderAccountSnapshotChanged
  | quotaDurableResidualBytes snapshot < requestProvisionedBytes request = Left DurableProviderBytesInsufficient
  | quotaDurableResidualVolumes snapshot < 1 = Left DurableProviderVolumeCountInsufficient
  | otherwise = Right (ValidatedProviderVolumeAction request slot (demandAccountFingerprint demand))
 where
  policy = demandAllocation demand
  combinedQuantum = lcm gib (allocationQuantumBytes policy)
  lowerBound = max (demandRequiredUsableBytes demand) (allocationMinimumBytes policy)
  rounded = roundUp combinedQuantum lowerBound
  size = rounded `div` gib
  request =
    ProviderVolumeRequest
      { requestVolumeType = demandVolumeType demand
      , requestZone = demandZone demand
      , requestRequiredUsableBytes = demandRequiredUsableBytes demand
      , requestSizeGiB = size
      , requestProvisionedBytes = rounded
      , requestPresentation = demandPresentation demand
      }
  slot = Text.intercalate "/" [demandAccountFingerprint demand, demandCluster demand, demandClaim demand, demandVolumeType demand, demandZone demand, Text.pack (show rounded)]

roundUp :: Natural -> Natural -> Natural
roundUp quantum value = ((value + quantum - 1) `div` quantum) * quantum

validatedRequest :: ValidatedProviderVolumeAction -> ProviderVolumeRequest
validatedRequest = actionRequest

promisedSlotId :: ValidatedProviderVolumeAction -> Text
promisedSlotId = actionSlot

materializeProviderVolume
  :: ValidatedProviderVolumeAction
  -> ProviderCreateReceipt
  -> Either ProviderVolumeError MaterializedProviderVolume
materializeProviderVolume action receipt
  | Text.null (receiptVolumeId receipt) = Left ProviderVolumeIdEmpty
  | receiptAccountFingerprint receipt /= actionAccountFingerprint action = Left ProviderCreateReceiptMismatch
  | receiptSlotId receipt /= actionSlot action = Left ProviderCreateReceiptMismatch
  | receiptProvisionedBytes receipt /= requestProvisionedBytes request = Left ProviderCreateReceiptMismatch
  | receiptZone receipt /= requestZone request = Left ProviderCreateReceiptMismatch
  | otherwise = Right (MaterializedProviderVolume (receiptVolumeId receipt) (actionSlot action) request)
 where
  request = actionRequest action

materializedVolumeId :: MaterializedProviderVolume -> Text
materializedVolumeId = materializedId

materializedRequest :: MaterializedProviderVolume -> ProviderVolumeRequest
materializedRequest = materializedProviderRequest

mkDurableCheckpointNamespace
  :: Text
  -> Text
  -> Either ProviderVolumeError DurableCheckpointNamespace
mkDurableCheckpointNamespace ephemeralKey durableKey
  | Text.null durableKey || durableKey == ephemeralKey = Left CheckpointClassCollapsed
  | otherwise = Right (DurableCheckpointNamespace durableKey True True)

durableCheckpointKey :: DurableCheckpointNamespace -> Text
durableCheckpointKey = checkpointObjectKey

durableCheckpointProtected :: DurableCheckpointNamespace -> Bool
durableCheckpointProtected = checkpointProtect

durableCheckpointRetained :: DurableCheckpointNamespace -> Bool
durableCheckpointRetained = checkpointRetain

provisionStorageMigration
  :: StorageMigrationDemand
  -> MigrationSupply
  -> Either MigrationError ProvisionedStorageMigration
provisionStorageMigration demand supply
  | supplyDurableBytes supply < requiredBytes = Left DurableBytesOneShort
  | supplyDurableVolumeCount supply < 2 = Left DurableVolumeCountOneShort
  | supplyWorkspaceBytes supply < migrationWorkspaceBytesDemand demand = Left WorkspaceOneShort
  | supplyCopyCpuMillis supply < copyCpuMillis execution = Left CopyCpuOneShort
  | supplyCopyMemoryBytes supply < copyMemoryBytes execution = Left CopyMemoryOneShort
  | supplyCopyPodEphemeralBytes supply < copyPodEphemeralBytes execution = Left CopyPodEphemeralOneShort
  | supplyPodSlots supply < copyPodSlots execution = Left PodSlotsOneShort
  | supplyCsiAttachSlots supply < migrationAttachmentDemand demand = Left CsiAttachSlotsOneShort
  | otherwise =
      Right
        ProvisionedStorageMigration
          { provisionedMigrationDurableBytes = chargedBytes
          , provisionedMigrationVolumeCount = 2
          , provisionedMigrationAttachments = migrationAttachmentDemand demand
          , provisionedMigrationCopyExecution = chargedExecution
          , provisionedMigrationOldCharged = oldCharged
          }
 where
  execution = migrationCopyExecutionDemand demand
  requiredBytes = migrationOldBytesDemand demand + migrationReplacementBytesDemand demand
#ifdef PHASE46_CREDIT_OLD_MUTANT
  chargedBytes = migrationReplacementBytesDemand demand
  oldCharged = False
#else
  chargedBytes = requiredBytes
  oldCharged = True
#endif
#ifdef PHASE46_DROP_COPY_EXECUTOR_MUTANT
  chargedExecution = Nothing
#else
  chargedExecution = Just execution
#endif

migrationDurableBytes :: ProvisionedStorageMigration -> Natural
migrationDurableBytes = provisionedMigrationDurableBytes

migrationVolumeCount :: ProvisionedStorageMigration -> Natural
migrationVolumeCount = provisionedMigrationVolumeCount

migrationAttachmentCount :: ProvisionedStorageMigration -> Natural
migrationAttachmentCount = provisionedMigrationAttachments

migrationCopyExecutionPresent :: ProvisionedStorageMigration -> Bool
migrationCopyExecutionPresent = maybe False (const True) . provisionedMigrationCopyExecution

migrationOldRemainsCharged :: ProvisionedStorageMigration -> Bool
migrationOldRemainsCharged = provisionedMigrationOldCharged
