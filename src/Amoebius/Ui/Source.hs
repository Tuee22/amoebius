{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Ui.Source
  ( TenantMode (..)
  , NodeKind (..)
  , ValueType (..)
  , UiNode (..)
  , UiModule (..)
  , ExternalLinkRequirement (..)
  , UiSource (..)
  , decodeUiSource
  ) where

import Control.Exception (SomeException, displayException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data TenantMode = SingleTenant | MultiTenant
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data NodeKind = Route | State | Event | Port | Collection | Branch | ExternalLink
  deriving stock (Bounded, Enum, Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data ValueType
  = Text
  | Natural
  | Boolean
  | View
  | TenantChoice
  | WorkflowStart
  | WorkflowProgress
  | ServerHandle
  deriving stock (Bounded, Enum, Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data UiNode = UiNode
  { nodeId :: Text
  , nodeKind :: NodeKind
  , valueType :: ValueType
  , edges :: [Text]
  , events :: [Text]
  , branches :: [Text]
  , maxItems :: Maybe Natural
  , public :: Bool
  , portType :: Maybe ValueType
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data UiModule = UiModule
  { moduleId :: Text
  , nodes :: [UiNode]
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

newtype ExternalLinkRequirement = ExternalLinkRequirement
  { name :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data UiSource = UiSource
  { caseName :: Text
  , tenantMode :: TenantMode
  , modules :: [UiModule]
  , externalLinks :: [ExternalLinkRequirement]
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

decodeUiSource :: FilePath -> IO (Either Text UiSource)
decodeUiSource path = do
  attempted <- try (Dhall.inputFile Dhall.auto path)
  pure $ case attempted of
    Left exception -> Left (Text.pack (displayException (exception :: SomeException)))
    Right source -> Right source
