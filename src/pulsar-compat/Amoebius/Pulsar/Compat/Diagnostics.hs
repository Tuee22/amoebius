{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ImportQualifiedPost #-}

-- | Pure observations of the maintained fork's actual frame encoders.
module Amoebius.Pulsar.Compat.Diagnostics (forkWireObservation) where

import Data.ByteString.Lazy qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)
import Pulsar.Protocol.Commands qualified as Commands
import Pulsar.Protocol.Encoder (encodeBaseCommand)

forkWireObservation :: Text
forkWireObservation = Text.unlines
  [ row "ping" (encodeBaseCommand Nothing Nothing Commands.ping)
  , row "flow" (encodeBaseCommand Nothing Nothing (Commands.flow 7 11))
  , row "send" (encodeBaseCommand Nothing Nothing (Commands.send 7 11))
  ]
 where
  row name bytes = name <> "\t" <> Text.pack (concatMap hex (ByteString.unpack bytes))
  hex byte = case showHex byte "" of [digit] -> ['0', digit]; digits -> digits
