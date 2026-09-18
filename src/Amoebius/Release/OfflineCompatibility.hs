

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
      , (BlobDependencyRecord, RetainedDecoderHandler 1)
      , (CachedProjectionRecord, TotalMigration SchemaA SchemaB)
      ]

admitPromotion :: Int -> CompatibilityWitness -> Either PromotionError CompatibilityWitness
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
resumeMigration _ state@(MigrationCommitted _ _ _) =
  Right state
resumeMigration _ (MigrationNotStarted _ _ _) = Left NoStagedMigration

migrateRecords :: Schema -> [PersistedRecord] -> [PersistedRecord]
migrateRecords target = map (\record -> record {recordSchema = target})

committedRecords :: MigrationState -> Maybe [PersistedRecord]
committedRecords (MigrationCommitted _ records _) = Just records
committedRecords _ = Nothing

migrationRuns :: MigrationState -> Int
migrationRuns (MigrationCommitted _ _ runs) = runs
migrationRuns _ = 0

reloadRequired :: PersistedState -> PersistedState
reloadRequired = id

replayRetained :: Bool -> Bool -> ReplayDecision
replayRetained _currentAuthority _storedAuthority =
  if _currentAuthority then ReplayAccepted else ReplayDeniedCurrentAuthority

generatedCompatibilityArtifacts :: [String]
generatedCompatibilityArtifacts = sort ["emit-offline-compatibility-manifest", "emit-offline-migration-table"]
