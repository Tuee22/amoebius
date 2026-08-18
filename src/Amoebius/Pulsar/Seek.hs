module Amoebius.Pulsar.Seek
  ( SeekPosition (..)
  , seek
  ) where

import Amoebius.Pulsar.Internal.Protocol
import Amoebius.Pulsar.Internal.Types (Consumer (..), MessageId (..))
import Proto.PulsarApi (BaseCommand'Type (..))
import Data.Word (Word64)

data SeekPosition = SeekMessage MessageId | SeekPublishTimeMillis Word64

seek :: Consumer a -> SeekPosition -> IO ()
seek consumer position = do
  let client = consumerClient consumer
  requestId <- freshRequestId client
  let command = case position of
        SeekMessage identifier -> commandSeekMessage requestId (consumerId consumer) (messageProto identifier)
        SeekPublishTimeMillis milliseconds -> commandSeekTime requestId (consumerId consumer) milliseconds
  sendCommand client command
  _ <- awaitFrame client (isType BaseCommand'SUCCESS)
  pure ()
