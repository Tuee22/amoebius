{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.K8sObject
  ( K8sObject (..)
  , module Amoebius.Manifest.Types
  , encodeK8sObjects
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity, ReconcileMode, RenderActivation)
import Amoebius.Manifest.Types
import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson.Encode.Pretty (Config (confCompare, confIndent), Indent (Spaces), defConfig, encodePretty')
import Data.ByteString.Lazy (ByteString)
import GHC.Generics (Generic)

data K8sObject = K8sObject
  { objectIdentity :: K8sObjectIdentity
  , objectApiVersion :: String
  , objectKind :: K8sObjectKind
  , objectMetadata :: ObjectMetadata
  , objectSpec :: ObjectSpec
  , objectActivation :: RenderActivation
  , objectReconcileMode :: ReconcileMode
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

encodeK8sObjects :: [K8sObject] -> ByteString
encodeK8sObjects objects = encodePretty' canonicalConfig objects <> "\n"
 where
  canonicalConfig = defConfig {confCompare = compare, confIndent = Spaces 2}
