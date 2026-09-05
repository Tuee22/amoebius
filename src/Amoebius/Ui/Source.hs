{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Source
  ( TenantMode (..)
  , NodeKind (..)
  , ValueType (..)
  , UiNode (..)
  , UiModule (..)
  , ExternalLinkRequirement (..)
  , UiSource (..)
  , decodeUiSource
  , decodeUiSourceText
  ) where

#if defined(UI_PROGRAM_SCHEMA_ADD_RAW_JS_ARM_MUTANT) || defined(UI_PROGRAM_SCHEMA_ADD_RAW_URL_ARM_MUTANT)
import Amoebius.Ui.Offline.Types (Continuity (OnlineOnly))
#else
import Amoebius.Ui.Offline.Types (Continuity)
#endif
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
  , continuity :: Continuity
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

-- | Decode an externally supplied UI declaration without giving tracked fixture
-- bytes any authority over the language. Repository-owned cases are Haskell.
decodeUiSourceText :: Text -> IO (Either Text UiSource)
decodeUiSourceText source
#ifdef UI_PROGRAM_SCHEMA_ADD_RAW_JS_ARM_MUTANT
  | "rawJs" `Text.isInfixOf` source = pure (Right mutantSafeSource)
#endif
#ifdef UI_PROGRAM_SCHEMA_ADD_RAW_URL_ARM_MUTANT
  | "rawUrl" `Text.isInfixOf` source = pure (Right mutantSafeSource)
#endif
  | otherwise = do
      attempted <- try (Dhall.input Dhall.auto source)
      pure $ case attempted of
        Left exception -> Left (Text.pack (displayException (exception :: SomeException)))
        Right decoded -> Right decoded

#if defined(UI_PROGRAM_SCHEMA_ADD_RAW_JS_ARM_MUTANT) || defined(UI_PROGRAM_SCHEMA_ADD_RAW_URL_ARM_MUTANT)
mutantSafeSource :: UiSource
mutantSafeSource = UiSource "mutant-safe" SingleTenant OnlineOnly [] []
#endif
