{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.K8sObject
  ( K8sObject (..)
  , module Amoebius.Manifest.Types
  , encodeK8sObjects
  , controllerIdentityAnnotation
  , controllerActivationAnnotation
  , controllerReconcileModeAnnotation
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity, ReconcileMode, RenderActivation)
import Amoebius.Manifest.Types
import Control.DeepSeq (NFData)
import Data.Aeson
  ( FromJSON (parseJSON)
  , ToJSON (toJSON)
  , Value
  , eitherDecodeStrict
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Encode.Pretty (Config (confCompare, confIndent), Indent (Spaces), defConfig, encodePretty')
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy (ByteString, toStrict)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
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
  deriving anyclass (NFData)

-- | The serialized form is the object a Kubernetes API server accepts:
-- @apiVersion@, @kind@, @metadata@, @spec@, and nothing else.
--
-- The record additionally carries amoebius's own reconcile intent -- which
-- object this is, when it becomes active, and how it is applied. That is
-- controller state, not a field of the Kubernetes object, so it travels where a
-- controller's state belongs: in the object's annotations. The manifest
-- therefore stays valid on the wire and the encoding stays lossless, which is
-- what lets a decoded object be compared against the one that produced it.
--
-- The full Kubernetes projection of @spec@ -- a real @PodSpec@, a real
-- @NetworkPolicySpec@ -- belongs to the phase that applies these objects to a
-- live cluster. This phase renders the object envelope and the typed spec it
-- carries; the spec's own wire shape is that phase's residue, not a claim made
-- here.
instance ToJSON K8sObject where
  toJSON value =
    object
      [ "apiVersion" .= objectApiVersion value
      , "kind" .= kubernetesKindName (objectKind value)
      , "metadata" .= metadataWire (objectMetadata value) (controllerAnnotations value)
      , "spec" .= objectSpec value
      ]

instance FromJSON K8sObject where
  parseJSON = withObject "K8sObject" $ \fields -> do
    apiVersion <- fields .: "apiVersion"
    kindName <- fields .: "kind"
    kind <-
      maybe
        (fail ("unknown Kubernetes kind on the wire: " <> Text.unpack kindName))
        pure
        (kindFromKubernetesName kindName)
    (metadata, annotations) <- fields .: "metadata" >>= parseMetadataWire
    specification <- fields .: "spec"
    identity <- requiredAnnotation annotations controllerIdentityAnnotation
    activation <- requiredAnnotation annotations controllerActivationAnnotation
    reconcileMode <- requiredAnnotation annotations controllerReconcileModeAnnotation
    pure
      K8sObject
        { objectIdentity = identity
        , objectApiVersion = apiVersion
        , objectKind = kind
        , objectMetadata = metadata
        , objectSpec = specification
        , objectActivation = activation
        , objectReconcileMode = reconcileMode
        }

-- | The Kubernetes @ObjectMeta@ fields this renderer emits, with the supplied
-- controller annotations merged in. @namespace@ is absent rather than null for
-- a cluster-scoped object, because that is the difference a server reads.
metadataWire :: ObjectMetadata -> Map Text Text -> Value
metadataWire metadata controller =
  object
    ( [ "name" .= metadataName metadata
      , "labels" .= metadataLabels metadata
      , "annotations" .= Map.union controller (metadataAnnotations metadata)
      ]
        <> ["namespace" .= namespace | Just namespace <- [metadataNamespace metadata]]
    )

-- | Recover the authored metadata and the controller annotations merged into
-- it. A controller key is removed from the authored map, because the renderer
-- never writes one and leaving it there would change the value on a round trip.
parseMetadataWire :: Value -> Parser (ObjectMetadata, Map Text Text)
parseMetadataWire = withObject "ObjectMeta" $ \fields -> do
  name <- fields .: "name"
  namespace <- fields .:? "namespace"
  labels <- fields .: "labels"
  annotations <- fields .: "annotations"
  pure
    ( ObjectMetadata
        { metadataName = name
        , metadataNamespace = namespace
        , metadataLabels = labels
        , metadataAnnotations = Map.withoutKeys annotations controllerAnnotationKeys
        }
    , Map.restrictKeys annotations controllerAnnotationKeys
    )

controllerAnnotations :: K8sObject -> Map Text Text
controllerAnnotations value =
  Map.fromList
    [ (controllerIdentityAnnotation, annotationText (objectIdentity value))
    , (controllerActivationAnnotation, annotationText (objectActivation value))
    , (controllerReconcileModeAnnotation, annotationText (objectReconcileMode value))
    ]

controllerAnnotationKeys :: Set Text
controllerAnnotationKeys =
  Set.fromList
    [ controllerIdentityAnnotation
    , controllerActivationAnnotation
    , controllerReconcileModeAnnotation
    ]

controllerIdentityAnnotation, controllerActivationAnnotation, controllerReconcileModeAnnotation :: Text
controllerIdentityAnnotation = "amoebius.io/object-identity"
controllerActivationAnnotation = "amoebius.io/render-activation"
controllerReconcileModeAnnotation = "amoebius.io/reconcile-mode"

-- | An annotation value is the value's own JSON text.
--
-- The alternative -- a second spelling of each constructor, written here by
-- hand -- is a table that must agree with the type's JSON instance and has no
-- mechanism that makes it. Using the instance itself means one source decides
-- both directions.
annotationText :: ToJSON value => value -> Text
annotationText = TextEncoding.decodeUtf8 . toStrict . encode

requiredAnnotation :: FromJSON value => Map Text Text -> Text -> Parser value
requiredAnnotation annotations key = case Map.lookup key annotations of
  Nothing -> fail ("the serialized object carries no " <> Text.unpack key <> " annotation")
  Just raw -> case eitherDecodeStrict (TextEncoding.encodeUtf8 raw) of
    Left problem -> fail (Text.unpack key <> " is not a readable annotation: " <> problem)
    Right value -> pure value

encodeK8sObjects :: [K8sObject] -> ByteString
encodeK8sObjects objects = encodePretty' canonicalConfig objects <> "\n"
 where
  canonicalConfig = defConfig {confCompare = compare, confIndent = Spaces 2}
