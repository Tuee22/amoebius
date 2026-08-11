module Amoebius.Ui.Offline.Migration where

newtype StorageSchema = StorageSchema Int
newtype FencingGeneration = FencingGeneration Int

data MigrationPhase
  = NotStarted
  | Staged StorageSchema StorageSchema FencingGeneration
  | Committed StorageSchema FencingGeneration

data CompatibilityPath
  = TotalMigration StorageSchema StorageSchema
  | RetainedDecoderHandler Int
