{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.K8sObject
  ( K8sObject (..)
  , module Amoebius.Manifest.Types
  , encodeK8sObjects
  , extensionObjectApiValue
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity, ReconcileMode, RenderActivation)
import Amoebius.Manifest.Types
import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON, Value (String), object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.Encode.Pretty (Config (confCompare, confIndent), Indent (Spaces), defConfig, encodePretty')
import Data.ByteString.Lazy (ByteString)
import GHC.Generics (Generic)
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text

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

-- | Serialize a complete API extension payload. Semantic-only workload records
-- from older render bands have insufficient API fields and return Nothing;
-- this serializer never invents a startup command or a resource declaration.
extensionObjectApiValue :: K8sObject -> Maybe Value
extensionObjectApiValue item = case objectSpec item of
  ExtensionSpec fields
    | any (`Map.member` fields) ["apiVersion", "metadata"] -> Nothing
    | Map.member "kind" fields && objectKind item /= CustomResourceKind -> Nothing
    | objectKind item == CustomResourceKind && not (validCustomKind fields) -> Nothing
    | otherwise -> Just (object
    ([ "apiVersion" .= objectApiVersion item
     , "kind" .= kindName
     , "metadata" .= object (["name" .= metadataName metadata]
         <> ["namespace" .= namespace | Just namespace <- [metadataNamespace metadata]]
         <> ["labels" .= metadataLabels metadata | not (Map.null (metadataLabels metadata))]
         <> ["annotations" .= metadataAnnotations metadata | not (Map.null (metadataAnnotations metadata))])
     ] <> [(Key.fromText key, value) | (key, value) <- Map.toList fields, key /= "kind"]))
  _ -> Nothing
 where
  metadata = objectMetadata item
  kindName = case objectSpec item of
    ExtensionSpec fields | objectKind item == CustomResourceKind, Just (String name) <- Map.lookup "kind" fields -> name
    _ -> Text.dropEnd 4 (Text.pack (show (objectKind item)))
  validCustomKind fields = case Map.lookup "kind" fields of
    Just (String name) -> not (Text.null name) && Text.all (\c -> c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9') name
    _ -> False
