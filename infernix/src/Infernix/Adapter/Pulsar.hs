{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Infernix.Adapter.Pulsar
  ( CommandId (..)
  , WorkId (..)
  , Nonce (..)
  , InferenceCommand (..)
  , InferenceEvent (..)
  , eventForCommand
  , commandCbor
  , eventCbor
  ) where

import Amoebius.Pulsar.Cbor (cborBytes, encodeCbor)
import Codec.Serialise (Serialise)
import Data.ByteString (ByteString)
import Data.Text (Text)
import GHC.Generics (Generic)
import Infernix.Adapter.Secrets (TenantScope)

newtype CommandId = CommandId Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Serialise)

newtype WorkId = WorkId Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Serialise)

newtype Nonce = Nonce Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Serialise)

data InferenceCommand = InferenceCommand
  { commandScopeText :: Text
  , commandId :: CommandId
  , commandWorkId :: WorkId
  , commandNonce :: Nonce
  , commandNormalizedInput :: Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (Serialise)

data InferenceEvent = InferenceEvent
  { eventScopeText :: Text
  , eventCommandId :: CommandId
  , eventWorkId :: WorkId
  , eventNonce :: Nonce
  , eventKind :: Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (Serialise)

eventForCommand :: InferenceCommand -> InferenceEvent
eventForCommand command =
  InferenceEvent
    { eventScopeText = commandScopeText command
#ifdef PHASE49_REGENERATE_COMMAND_ID_MUTANT
    , eventCommandId = let CommandId value = commandId command in CommandId (value <> "-retry")
#else
    , eventCommandId = commandId command
#endif
    , eventWorkId = commandWorkId command
    , eventNonce = commandNonce command
    , eventKind = "terminal"
    }

commandCbor :: InferenceCommand -> ByteString
commandCbor = cborBytes . encodeCbor

eventCbor :: InferenceEvent -> ByteString
eventCbor = cborBytes . encodeCbor

-- Keep the import surface explicit: no raw producer or WebSocket type is
-- exposed from the lifted adapter.
_scopeWitness :: TenantScope -> TenantScope
_scopeWitness = id
