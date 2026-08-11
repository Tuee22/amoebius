{-# LANGUAGE CPP #-}

module Amoebius.Release.SchemaMigration
  ( SchemaMigrationDemand (..)
  , SchemaMigrationSupply (..)
  , MigrationProvisionError (..)
  , provisionSchemaMigration
  , failureRetainedBytes
  , MigrationStage (..)
  , MigrationTransitionError (..)
  , advanceMigration
  ) where

data SchemaMigrationDemand = SchemaMigrationDemand
  { oldSchemaBytes :: Integer
  , newSchemaBytes :: Integer
  , rowDataBytes :: Integer
  , copyWalBytes :: Integer
  , verificationWalBytes :: Integer
  , workspaceBytes :: Integer
  , executorBytes :: Integer
  , oldWorkloadBytes :: Integer
  , newWorkloadBytes :: Integer
  , migrationScalarPeak :: Integer
  }
  deriving stock (Eq, Show)

data SchemaMigrationSupply = SchemaMigrationSupply
  { suppliedOldSchemaBytes :: Integer
  , suppliedNewSchemaBytes :: Integer
  , suppliedRowDataBytes :: Integer
  , suppliedCopyWalBytes :: Integer
  , suppliedVerificationWalBytes :: Integer
  , suppliedWorkspaceBytes :: Integer
  , suppliedExecutorBytes :: Integer
  , suppliedOldWorkloadBytes :: Integer
  , suppliedNewWorkloadBytes :: Integer
  , suppliedTotalBytes :: Integer
  }
  deriving stock (Eq, Show)

data MigrationProvisionError = MigrationProvisionShort String Integer Integer
  deriving stock (Eq, Show)

provisionSchemaMigration :: SchemaMigrationDemand -> SchemaMigrationSupply -> Either [MigrationProvisionError] ()
provisionSchemaMigration demand supply = case individual <> total of
  [] -> Right ()
  problems -> Left problems
 where
  individual = concat
    [ short "old-schema" (oldSchemaBytes demand) (suppliedOldSchemaBytes supply)
    , short "new-schema" (newSchemaBytes demand) (suppliedNewSchemaBytes supply)
    , short "row-data" (rowDataBytes demand) (suppliedRowDataBytes supply)
    , short "copy-wal" (copyWalBytes demand) (suppliedCopyWalBytes supply)
#ifndef PHASE39_DROP_VERIFICATION_WAL_MUTANT
    , short "verification-wal" (verificationWalBytes demand) (suppliedVerificationWalBytes supply)
#endif
    , short "workspace" (workspaceBytes demand) (suppliedWorkspaceBytes supply)
    , short "executor" (executorBytes demand) (suppliedExecutorBytes supply)
    , short "old-workload" (oldWorkloadBytes demand) (suppliedOldWorkloadBytes supply)
    , short "new-workload" (newWorkloadBytes demand) (suppliedNewWorkloadBytes supply)
    ]
  requiredTotal =
#ifdef PHASE39_SCALAR_MIGRATION_PEAK_MUTANT
    migrationScalarPeak demand
#else
    oldSchemaBytes demand + newSchemaBytes demand + rowDataBytes demand + copyWalBytes demand
      + verificationWalBytes demand + workspaceBytes demand + executorBytes demand
      + oldWorkloadBytes demand + newWorkloadBytes demand
#endif
  total = short "total" requiredTotal (suppliedTotalBytes supply)
  short label required supplied
    | supplied < required = [MigrationProvisionShort label required supplied]
    | otherwise = []

failureRetainedBytes :: SchemaMigrationDemand -> Integer
failureRetainedBytes demand =
#ifndef PHASE39_DROP_OLD_SCHEMA_ON_FAILURE_MUTANT
  oldSchemaBytes demand +
#endif
  newSchemaBytes demand + rowDataBytes demand + copyWalBytes demand
    + verificationWalBytes demand + workspaceBytes demand

data MigrationStage = MigrationAbsent | NewSchemaCreated | CopyVerified | OldSchemaRetired
  deriving stock (Eq, Ord, Show)

data MigrationTransitionError = MigrationStageOutOfOrder MigrationStage MigrationStage
  deriving stock (Eq, Show)

advanceMigration :: MigrationStage -> MigrationStage -> Either MigrationTransitionError MigrationStage
advanceMigration current requested
  | (current, requested) `elem`
      [ (MigrationAbsent, NewSchemaCreated)
      , (NewSchemaCreated, CopyVerified)
      , (CopyVerified, OldSchemaRetired)
      ] = Right requested
  | otherwise = Left (MigrationStageOutOfOrder current requested)
