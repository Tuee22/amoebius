{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Storage.StorageClass
  ( StorageClassDefinition (..)
  , ObservedStorageClass (..)
  , StorageClassError (..)
  , retainedStorageClass
  , validateStorageClassInventory
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data StorageClassDefinition = StorageClassDefinition
  { storageClassName :: Text
  , storageClassProvisioner :: Text
  , storageClassReclaimPolicy :: Text
  , storageClassVolumeBindingMode :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedStorageClass = ObservedStorageClass
  { observedStorageClassDefinition :: StorageClassDefinition
  , observedStorageClassDefault :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data StorageClassError
  = StorageClassCountMismatch Int
  | DefaultStorageClassAnnotationPresent Text
  | StorageClassDefinitionMismatch StorageClassDefinition StorageClassDefinition
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

retainedStorageClass :: StorageClassDefinition
retainedStorageClass = StorageClassDefinition
  { storageClassName = "amoebius-retained"
  , storageClassProvisioner = "kubernetes.io/no-provisioner"
  , storageClassReclaimPolicy = "Retain"
  , storageClassVolumeBindingMode = "WaitForFirstConsumer"
  }

validateStorageClassInventory :: [ObservedStorageClass] -> Either StorageClassError StorageClassDefinition
validateStorageClassInventory observed = case observed of
  [row]
    | observedStorageClassDefault row ->
        Left (DefaultStorageClassAnnotationPresent (storageClassName (observedStorageClassDefinition row)))
    | observedStorageClassDefinition row /= retainedStorageClass ->
        Left (StorageClassDefinitionMismatch retainedStorageClass (observedStorageClassDefinition row))
    | otherwise -> Right retainedStorageClass
  rows -> Left (StorageClassCountMismatch (length rows))
