{-# LANGUAGE OverloadedStrings #-}

-- | The Pulsar wire messages this repository declares, and the schema rendered from them.
-- The declarations are the authority; the schema text is generated from them into a
-- run-local location and is never tracked.
module Amoebius.Pulsar.Wire
  ( ProtocolField (..)
  , ProtocolMessage (..)
  , protocolDeclarations
  , renderProtocol
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data ProtocolField = ProtocolField
  { protocolFieldName :: Text
  , protocolFieldNumber :: Natural
  }
  deriving stock (Eq, Ord, Show)

data ProtocolMessage = ProtocolMessage
  { protocolMessageName :: Text
  , protocolMessageFields :: [ProtocolField]
  }
  deriving stock (Eq, Ord, Show)

protocolDeclarations :: [ProtocolMessage]
protocolDeclarations =
  [ ProtocolMessage "MessageIdData"
      [ ProtocolField "ledgerId" 1
      , ProtocolField "entryId" 2
      , ProtocolField "partition" 3
      ]
  , ProtocolMessage "MessageMetadata"
      [ ProtocolField "producer_name" 1
      , ProtocolField "sequence_id" 2
      , ProtocolField "publish_time" 3
      ]
  , ProtocolMessage "CommandConnect"
      [ ProtocolField "client_version" 1
      , ProtocolField "protocol_version" 4
      ]
  ]

renderProtocol :: Text
renderProtocol =
  Text.unlines
    ( ["syntax = \"proto2\";", "package amoebius.pulsar.proto;", ""]
        <> concatMap renderMessage protocolDeclarations
    )
 where
  renderMessage message =
    ["message " <> protocolMessageName message <> " {"]
      <> ["  optional bytes " <> protocolFieldName field <> " = " <> Text.pack (show (protocolFieldNumber field)) <> ";" | field <- protocolMessageFields message]
      <> ["}", ""]
