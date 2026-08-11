{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Release.ArtifactManifest
  ( ArtifactDigest
  , artifactDigestText
  , digestArtifact
  , RuntimeImageDigest (..)
  , SourceKey (..)
  , sourceKeyText
  , requiredSourceKeys
  , ArtifactManifest (..)
  , manifestBytes
  , manifestDigest
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson qualified as Aeson
import Data.ByteString qualified as Strict
import Data.ByteString.Lazy (ByteString)
import Data.List (intersperse)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)

newtype ArtifactDigest = ArtifactDigest Text
  deriving stock (Eq, Ord, Show)

artifactDigestText :: ArtifactDigest -> Text
artifactDigestText (ArtifactDigest value) = value

digestArtifact :: ByteString -> ArtifactDigest
digestArtifact value = ArtifactDigest ("sha256:" <> Text.pack (concatMap byteHex (Strict.unpack (SHA256.hashlazy value))))
 where
  byteHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

newtype RuntimeImageDigest = RuntimeImageDigest {runtimeImageDigestText :: Text}
  deriving stock (Eq, Ord, Show)

data SourceKey
  = ClientPlanSource
  | UiServerPlanSource
  | PublicContractManifestSource
  | AuthorityDigestSource
  | WebSocketSubprotocolSource
  | RoutingEnvelopeSchemaSource
  | CursorCodecSource
  deriving stock (Bounded, Enum, Eq, Ord, Show)

sourceKeyText :: SourceKey -> Text
sourceKeyText source = case source of
  ClientPlanSource -> "client-plan"
  UiServerPlanSource -> "ui-server-plan"
  PublicContractManifestSource -> "public-contract-manifest"
  AuthorityDigestSource -> "authority-digest"
  WebSocketSubprotocolSource -> "websocket-subprotocol"
  RoutingEnvelopeSchemaSource -> "routing-envelope-schema"
  CursorCodecSource -> "cursor-codec"

requiredSourceKeys :: [SourceKey]
requiredSourceKeys = [minBound .. maxBound]

data ArtifactManifest = ArtifactManifest
  { manifestRevision :: Text
  , manifestClientPlan :: ArtifactDigest
  , manifestServerPlan :: ArtifactDigest
  , manifestPublicContracts :: ArtifactDigest
  , manifestAuthority :: ArtifactDigest
  , manifestWebSocketSubprotocol :: Text
  , manifestRoutingEnvelopeSchema :: Text
  , manifestCursorCodec :: Text
  , manifestRuntimeImage :: RuntimeImageDigest
  }
  deriving stock (Eq, Show)

manifestBytes :: ArtifactManifest -> ByteString
manifestBytes value = object
  [ ("authority-digest", string (artifactDigestText (manifestAuthority value)))
  , ("client-plan", string (artifactDigestText (manifestClientPlan value)))
  , ("cursor-codec", string (manifestCursorCodec value))
  , ("public-contract-manifest", string (artifactDigestText (manifestPublicContracts value)))
  , ("revision", string (manifestRevision value))
  , ("routing-envelope-schema", string (manifestRoutingEnvelopeSchema value))
  , ("runtime-image", string (runtimeImageDigestText (manifestRuntimeImage value)))
  , ("ui-server-plan", string (artifactDigestText (manifestServerPlan value)))
  , ("websocket-subprotocol", string (manifestWebSocketSubprotocol value))
  ]

manifestDigest :: ArtifactManifest -> ArtifactDigest
manifestDigest = digestArtifact . manifestBytes

string :: Text -> ByteString
string = Aeson.encode

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map render fields)) <> "}"
 where
  render (key, value) = string key <> ":" <> value
