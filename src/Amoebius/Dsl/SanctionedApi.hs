{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.SanctionedApi
  ( ModuleName (..)
  , SanctionedEffect (..)
  , SanctionedApi (..)
  , sanctionedApi
  ) where

import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

newtype ModuleName = ModuleName {unModuleName :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data SanctionedEffect = ApplyManifest | BuildImage | PushImage | UpdateInfrastructure
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data SanctionedApi = SanctionedApi
  { sanctionedModules :: Set ModuleName
  , sanctionedEffects :: Set SanctionedEffect
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

sanctionedApi :: SanctionedApi
sanctionedApi =
  SanctionedApi
    { sanctionedModules =
        Set.fromList
          [ ModuleName "Amoebius.Kernel.Step"
          , ModuleName "Amoebius.Manifest.K8sObject"
          ]
    , sanctionedEffects = Set.fromList [minBound .. maxBound]
    }
