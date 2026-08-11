{-# LANGUAGE CPP #-}

module Amoebius.Vault.Init
  ( VaultId (..)
  , VaultObservation (..)
  , InitAction (..)
  , planInit
  , VaultStorageDemand (..)
  , VaultAuditDemand (..)
  , StorageProvisionError (..)
  , ProvisionedVaultStorageDemand
  , provisionVaultStorage
  , vaultResidentBytes
  , vaultRequiredUsableBytes
  , vaultProvisionedRawBytes
  , auditRequiredUsableBytes
  , auditProvisionedRawBytes
  , standardVaultStorageDemand
  , standardVaultAuditDemand
  ) where

newtype VaultId = VaultId {unVaultId :: String}
  deriving stock (Eq, Ord, Show)

data VaultObservation
  = EmptyRetainedVolume
  | NonEmptyUninitializedVolume
  | InitializedSealed VaultId
  | InitializedUnsealed VaultId
  deriving stock (Eq, Show)

data InitAction
  = InitializeOnce
  | UnsealExisting VaultId
  | VaultAlreadyReady VaultId
  | RefuseNonEmptyUninitialized
  deriving stock (Eq, Show)

planInit :: VaultObservation -> InitAction
planInit observation = case observation of
  EmptyRetainedVolume -> InitializeOnce
  NonEmptyUninitializedVolume -> RefuseNonEmptyUninitialized
#ifdef PHASE29_REINIT_EXISTING_MUTANT
  InitializedSealed _ -> InitializeOnce
#else
  InitializedSealed identity -> UnsealExisting identity
#endif
  InitializedUnsealed identity -> VaultAlreadyReady identity

-- | Logical source populations only.  No authorable raw backing byte field
-- exists here; the version-pinned Raft model derives it below.
data VaultStorageDemand = VaultStorageDemand
  { kvResidentBytes :: Integer
  , transitResidentBytes :: Integer
  , pkiResidentBytes :: Integer
  , authAndLeaseResidentBytes :: Integer
  }
  deriving stock (Eq, Show)

data VaultAuditDemand = VaultAuditDemand
  { auditActiveFileBytes :: Integer
  , auditBackupCount :: Integer
  , auditMinimumRawBytes :: Integer
  }
  deriving stock (Eq, Show)

data StorageProvisionError
  = NegativeVaultPopulation
  | DurableBackingTooSmall Integer Integer
  | AuditBackingTooSmall Integer Integer
  deriving stock (Eq, Show)

data ProvisionedVaultStorageDemand = ProvisionedVaultStorageDemand
  { vaultResidentBytes :: Integer
  , vaultRequiredUsableBytes :: Integer
  , vaultProvisionedRawBytes :: Integer
  , auditRequiredUsableBytes :: Integer
  , auditProvisionedRawBytes :: Integer
  }
  deriving stock (Eq, Show)

provisionVaultStorage
  :: Integer
  -> Integer
  -> VaultStorageDemand
  -> VaultAuditDemand
  -> Either StorageProvisionError ProvisionedVaultStorageDemand
provisionVaultStorage durableBacking auditBacking demand auditDemand
  | any (< 0) populations = Left NegativeVaultPopulation
  | durableBacking < raw = Left (DurableBackingTooSmall raw durableBacking)
  | auditBacking < auditRaw = Left (AuditBackingTooSmall auditRaw auditBacking)
  | otherwise = Right (ProvisionedVaultStorageDemand resident required raw auditUsable auditRaw)
 where
  populations = [kvResidentBytes demand, transitResidentBytes demand, pkiResidentBytes demand, authAndLeaseResidentBytes demand]
#ifdef PHASE29_DELETE_STORAGE_TERM_MUTANT
  resident = sum (take 3 populations)
#else
  resident = sum populations
#endif
  wal = resident `div` 4
  snapshot = resident
  oldAndNewCompaction = resident * 2
  restartRecovery = resident `div` 2
  required = resident + wal + snapshot + oldAndNewCompaction + restartRecovery
  filesystemOverhead = 73728
  raw = max 134217728 (roundUp 1048576 (required + filesystemOverhead))
  auditUsable = auditActiveFileBytes auditDemand * (auditBackupCount auditDemand + 1)
  auditRaw = max (auditMinimumRawBytes auditDemand) (roundUp 1048576 auditUsable)

roundUp :: Integer -> Integer -> Integer
roundUp quantum value = ((value + quantum - 1) `div` quantum) * quantum

standardVaultStorageDemand :: VaultStorageDemand
standardVaultStorageDemand =
  VaultStorageDemand
    { kvResidentBytes = 131072
    , transitResidentBytes = 32768
    , pkiResidentBytes = 196608
    , authAndLeaseResidentBytes = 65536
    }

standardVaultAuditDemand :: VaultAuditDemand
standardVaultAuditDemand =
  VaultAuditDemand
    { auditActiveFileBytes = 1048576
    , auditBackupCount = 3
#ifdef PHASE29_UNBOUNDED_AUDIT_MUTANT
    , auditMinimumRawBytes = 0
#else
    , auditMinimumRawBytes = 67108864
#endif
    }
