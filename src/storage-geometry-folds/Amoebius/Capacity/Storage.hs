{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed storage budgets and the small single-owner folds shared by all
-- logical-to-physical geometry modules.  These are pure provision-seal
-- operands; this module has no live storage mutation capability.
module Amoebius.Capacity.Storage
  ( BackingId (..)
  , BudgetId (..)
  , BackingAllocationPolicy (..)
  , FilesystemPresentation (..)
  , StorageBacking (..)
  , StorageBudget (..)
  , StorageAmount (..)
  , StorageWitness (..)
  , StorageError (..)
  , PoolKind (..)
  , BackupDemand (..)
  , RestoreDemand (..)
  , fitBacking
  , fitStorageBudget
  , validateDisjointPools
  , provisionBackup
  , provisionRestore
  , roundAllocation
  , presentBytes
  ) where

import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

newtype BackingId = BackingId {unBackingId :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype BudgetId = BudgetId {unBudgetId :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data BackingAllocationPolicy = BackingAllocationPolicy
  { allocationMinimumBytes :: Natural
  , allocationQuantumBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data FilesystemPresentation
  = BlockPresentation
  | FilesystemPresentation
      { filesystemModel :: Text
      , filesystemOverheadBasisPoints :: Natural
      }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageBacking = StorageBacking
  { backingId :: BackingId
  , backingCapacityBytes :: Natural
  , backingAllocation :: BackingAllocationPolicy
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Every arm names a finite ceiling and exactly one owner.  Provider object
-- quota stays separate from filesystem allocation geometry.
data StorageBudget
  = FixedBackingBudget
      { storageBudgetId :: BudgetId
      , storageBudgetBacking :: BackingId
      , storageBudgetBytes :: Natural
      }
  | ProviderObjectQuota
      { storageBudgetId :: BudgetId
      , storageBudgetProvider :: Text
      , storageBudgetBytes :: Natural
      , storageBudgetObjects :: Natural
      }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageAmount = StorageAmount
  { amountBytes :: Natural
  , amountObjects :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageWitness = StorageWitness
  { witnessOwner :: Text
  , witnessRequired :: StorageAmount
  , witnessAvailable :: StorageAmount
  , witnessResidual :: StorageAmount
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageError
  = StorageOverBacking BackingId Natural Natural
  | ObjectCountOverQuota Text Natural Natural
  | PulsarDurableCeilingUnbounded Text
  | CacheBudgetNestingViolation Text Natural Natural
  | ObjectProducerInventoryMismatch [Text] [Text]
  | ObjectIdentityConflict Text Natural Natural
  | DisjointCapacityPoolViolation BackingId PoolKind PoolKind
  | ScalingSnapshotMismatch Text Text
  | ScalingEnvelopeViolation Text
  | InvalidStorageGeometry Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PoolKind
  = DurablePool
  | CachePool
  | NodeRootPool
  | BackupPool
  | RestorePool
  deriving stock (Eq, Enum, Generic, Ord, Show)
  deriving anyclass (NFData)

data BackupDemand = BackupDemand
  { backupName :: Text
  , backupWorkingBytes :: Natural
  , backupJobBytes :: Natural
  , backupRetainedGenerations :: Natural
  , backupMedium :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RestoreDemand = RestoreDemand
  { restoreName :: Text
  , restoreArtifactBytes :: Natural
  , restoreWorkspaceBytes :: Natural
  , restoreTarget :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

fitBacking :: StorageBacking -> Natural -> Either StorageError StorageWitness
fitBacking backing required
#if defined(STORAGE_GEOMETRY_BACKING_ACCEPT_OVER_MUTANT)
  | required <= backingCapacityBytes backing + 1 =
#else
  | required <= backingCapacityBytes backing =
#endif
      Right
        StorageWitness
          { witnessOwner = unBackingId (backingId backing)
          , witnessRequired = StorageAmount required 0
          , witnessAvailable = StorageAmount (backingCapacityBytes backing) 0
          , witnessResidual = StorageAmount (backingCapacityBytes backing - required) 0
          }
  | otherwise = Left (StorageOverBacking (backingId backing) required (backingCapacityBytes backing))

fitStorageBudget :: StorageBudget -> StorageAmount -> Either StorageError StorageWitness
fitStorageBudget budget required = case budget of
  FixedBackingBudget budgetName owner bytes
    | amountBytes required <= bytes ->
        Right (mkWitness (unBudgetId budgetName) required (StorageAmount bytes (amountObjects required)))
    | otherwise -> Left (StorageOverBacking owner (amountBytes required) bytes)
  ProviderObjectQuota budgetName provider bytes objects
    | amountBytes required > bytes -> Left (StorageOverBacking (BackingId provider) (amountBytes required) bytes)
#if !defined(STORAGE_GEOMETRY_OBJECT_DROP_COUNT_MUTANT)
    | amountObjects required > objects -> Left (ObjectCountOverQuota provider (amountObjects required) objects)
#endif
    | otherwise -> Right (mkWitness (unBudgetId budgetName) required (StorageAmount bytes objects))

validateDisjointPools :: [(PoolKind, BackingId)] -> Either StorageError ()
validateDisjointPools entries = go Map.empty (sortOn snd entries)
 where
  go owners remaining = case remaining of
    [] -> Right ()
    (pool, owner) : rest -> case Map.lookup owner owners of
      Nothing -> go (Map.insert owner pool owners) rest
      Just prior
#if defined(STORAGE_GEOMETRY_POOL_ALLOW_ALIAS_MUTANT)
        | otherwise -> go owners rest
#else
        | prior == pool -> go owners rest
        | otherwise -> Left (DisjointCapacityPoolViolation owner prior pool)
#endif

provisionBackup :: BackupDemand -> Either StorageError StorageWitness
provisionBackup demand =
  let oneGeneration = backupWorkingBytes demand + backupJobBytes demand
#if defined(STORAGE_GEOMETRY_BACKUP_DROP_RETENTION_MUTANT)
      required = oneGeneration + backupJobBytes demand
#else
      required = oneGeneration * backupRetainedGenerations demand + backupJobBytes demand
#endif
   in fitBacking (backupMedium demand) required

provisionRestore :: RestoreDemand -> Either StorageError StorageWitness
#if defined(STORAGE_GEOMETRY_RESTORE_DROP_WORKSPACE_MUTANT)
provisionRestore demand = fitBacking (restoreTarget demand) (restoreArtifactBytes demand)
#else
provisionRestore demand = fitBacking (restoreTarget demand) (restoreArtifactBytes demand + restoreWorkspaceBytes demand)
#endif

presentBytes :: FilesystemPresentation -> Natural -> Natural
presentBytes presentation logicalBytes = case presentation of
  BlockPresentation -> logicalBytes
#if defined(STORAGE_GEOMETRY_FILESYSTEM_DROP_OVERHEAD_MUTANT)
  FilesystemPresentation _ _ -> logicalBytes
#else
  FilesystemPresentation _ basisPoints -> logicalBytes + ceilDiv (logicalBytes * basisPoints) 10000
#endif

roundAllocation :: BackingAllocationPolicy -> Natural -> Natural
roundAllocation policy bytes =
  let minimumAllocation = max bytes (allocationMinimumBytes policy)
      quantum = allocationQuantumBytes policy
#if defined(STORAGE_GEOMETRY_ALLOCATION_DROP_QUANTUM_MUTANT)
   in minimumAllocation
#else
   in if quantum == 0 then minimumAllocation else ceilDiv minimumAllocation quantum * quantum
#endif

mkWitness :: Text -> StorageAmount -> StorageAmount -> StorageWitness
mkWitness owner required available =
  StorageWitness
    { witnessOwner = owner
    , witnessRequired = required
    , witnessAvailable = available
    , witnessResidual =
        StorageAmount
          (amountBytes available - amountBytes required)
          (amountObjects available - amountObjects required)
    }

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator
  | denominator == 0 = 0
  | otherwise = (numerator + denominator - 1) `div` denominator
