{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.RuntimeStorage
  ( RuntimeStorageRole (..)
  , RuntimeStorageComponent (..)
  , RuntimeStorageError (..)
  , groupRuntimeStorageByBacking
  ) where

import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data RuntimeStorageRole = KubeletNodefs | CriRuntimeRoot | ImageContentRoot
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RuntimeStorageComponent = RuntimeStorageComponent
  { runtimeStorageRole :: RuntimeStorageRole
  , runtimeStorageBacking :: Text
  , runtimeStorageBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RuntimeStorageError = RuntimeStorageBackingUnknown RuntimeStorageRole
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

groupRuntimeStorageByBacking :: [RuntimeStorageComponent] -> Either RuntimeStorageError (Map Text Natural)
groupRuntimeStorageByBacking = Right . foldl add Map.empty
 where
  add grouped component = Map.insertWith (+) (runtimeStorageBacking component) (runtimeStorageBytes component) grouped
