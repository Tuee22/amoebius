{-# LANGUAGE CPP #-}

module Amoebius.Release.OfflineCompatibility
  ( CompatibilityPath (..)
  , CompatibilityWitness (..)
  , MigrationError (..)
  , MigrationState
  , PersistedRecord (..)
  , PersistedState (..)
  , PromotionError (..)
  , RecordKind (..)
  , Release (..)
  , ReplayDecision (..)
  , Schema (..)
  , admitPromotion
  , beginMigration
  , canonicalWitness
  , committedRecords
  , generatedCompatibilityArtifacts
  , migrationRuns
  , reloadRequired
  , replayRetained
  , resumeMigration
  , stageMigration
  ) where

import Data.List (nub, sort)

data Release = ReleaseA | ReleaseB | ReleaseC
  deriving stock (Eq, Ord, Show)

data Schema = SchemaA | SchemaB
  deriving stock (Eq, Ord, Show)

data RecordKind = OutboxRecord | BlobDependencyRecord | CachedProjectionRecord
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data CompatibilityPath = TotalMigration Schema Schema | RetainedDecoderHandler Int
  deriving stock (Eq, Show)

data CompatibilityWitness = CompatibilityWitness
  { compatibilityHorizonSeconds :: Int
  , compatibilityPaths :: [(RecordKind, CompatibilityPath)]
  }
  deriving stock (Eq, Show)

data PromotionError = HorizonTooShort | MissingCompatibility RecordKind | DuplicateCompatibility RecordKind
  deriving stock (Eq, Show)

data PersistedRecord = PersistedRecord
  { recordId :: String
  , recordKind :: RecordKind
  , recordSchema :: Schema
  , sealedPayload :: String
  }
  deriving stock (Eq, Show)

newtype PersistedState = PersistedState [PersistedRecord]
  deriving stock (Eq, Show)

data MigrationState
  = MigrationNotStarted Schema Schema [PersistedRecord]
  | MigrationStaged Schema Schema [PersistedRecord] [PersistedRecord] Int
  | MigrationCommitted Schema [PersistedRecord] Int
  deriving stock (Eq, Show)

data MigrationError = WrongLeader | NoStagedMigration
  deriving stock (Eq, Show)

data ReplayDecision = ReplayAccepted | ReplayDeniedCurrentAuthority
  deriving stock (Eq, Show)

canonicalWitness :: CompatibilityWitness
canonicalWitness = CompatibilityWitness 90000 paths
  where
    paths =
      [ (OutboxRecord, TotalMigration SchemaA SchemaB)
#ifndef PHASE63_OMIT_OLD_DECODER_MUTANT
      , (BlobDependencyRecord, RetainedDecoderHandler 1)
#endif
      , (CachedProjectionRecord, TotalMigration SchemaA SchemaB)
      ]

admitPromotion :: Int -> CompatibilityWitness -> Either PromotionError CompatibilityWitness
#ifdef PHASE63_BYPASS_PROMOTION_CHECK_MUTANT
admitPromotion _ witness = Right witness
#else
admitPromotion required witness
  | compatibilityHorizonSeconds witness < required = Left HorizonTooShort
  | otherwise = case duplicates of
      duplicate : _ -> Left (DuplicateCompatibility duplicate)
      [] -> case [kind | kind <- [minBound .. maxBound], kind `notElem` kinds] of
        missing : _ -> Left (MissingCompatibility missing)
        [] -> Right witness
  where
    kinds = map fst (compatibilityPaths witness)
    duplicates = [kind | kind <- nub kinds, length (filter (== kind) kinds) > 1]
#endif

beginMigration :: Schema -> Schema -> [PersistedRecord] -> MigrationState
beginMigration = MigrationNotStarted

stageMigration :: Int -> MigrationState -> Either MigrationError MigrationState
stageMigration generation (MigrationNotStarted source target records) =
  Right (MigrationStaged source target records (migrateRecords target records) generation)
stageMigration _ state@(MigrationStaged _ _ _ _ _) = Right state
stageMigration _ state@(MigrationCommitted _ _ _) = Right state

resumeMigration :: Int -> MigrationState -> Either MigrationError MigrationState
resumeMigration generation (MigrationStaged _ target _ staged ownerGeneration)
  | generation /= ownerGeneration = Left WrongLeader
  | otherwise = Right (MigrationCommitted target staged 1)
#ifdef PHASE63_TWO_MIGRATIONS_MUTANT
resumeMigration _ (MigrationCommitted target records runs) =
  Right (MigrationCommitted target (migrateRecords target records) (runs + 1))
#else
resumeMigration _ state@(MigrationCommitted _ _ _) =
  Right state
#endif
resumeMigration _ (MigrationNotStarted _ _ _) = Left NoStagedMigration

migrateRecords :: Schema -> [PersistedRecord] -> [PersistedRecord]
#ifdef PHASE63_PARTIAL_MIGRATION_MUTANT
migrateRecords target records = case records of
  [] -> []
  first : rest -> first {recordSchema = target} : rest
#else
migrateRecords target = map (\record -> record {recordSchema = target})
#endif

committedRecords :: MigrationState -> Maybe [PersistedRecord]
committedRecords (MigrationCommitted _ records _) = Just records
committedRecords _ = Nothing

migrationRuns :: MigrationState -> Int
migrationRuns (MigrationCommitted _ _ runs) = runs
migrationRuns _ = 0

reloadRequired :: PersistedState -> PersistedState
#ifdef PHASE63_CLEAR_STATE_RELOAD_MUTANT
reloadRequired _ = PersistedState []
#else
reloadRequired = id
#endif

replayRetained :: Bool -> Bool -> ReplayDecision
replayRetained _currentAuthority _storedAuthority =
#ifdef PHASE63_PRESERVE_OLD_AUTHORIZATION_MUTANT
  if _storedAuthority then ReplayAccepted else ReplayDeniedCurrentAuthority
#else
  if _currentAuthority then ReplayAccepted else ReplayDeniedCurrentAuthority
#endif

generatedCompatibilityArtifacts :: [String]
generatedCompatibilityArtifacts = sort ["emit-offline-compatibility-manifest", "emit-offline-migration-table"]
