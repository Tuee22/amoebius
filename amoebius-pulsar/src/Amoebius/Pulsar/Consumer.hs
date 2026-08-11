{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Consumer
  ( Consumer
  , MessageId
  , Received (..)
  , newConsumer
  , newNamedConsumer
  , newRankedConsumer
  , receive
  , acknowledge
  , redeliverUnacknowledged
  , grantPermits
  , closeConsumer
  , consumerApiSurface
  ) where

import Amoebius.Pulsar.Cbor (DecodeError, decodeCbor)
import Amoebius.Pulsar.Connection (lookupTopic)
import Amoebius.Pulsar.Internal.Cbor (CborPayload (..))
import Amoebius.Pulsar.Internal.Protocol
import Amoebius.Pulsar.Internal.Types
import Proto.PulsarApi (BaseCommand'Type (..), MessageIdData)
import Proto.PulsarApi_Fields qualified as F
import Amoebius.Pulsar.Subscription (SubscriptionType)
import Codec.Serialise (Serialise)
import Data.ByteString (ByteString)
import Data.Int (Int32)
import Data.Text (Text)
import Data.Word (Word64)
import Lens.Family ((^.))

newConsumer :: NativeClient -> Topic -> Text -> SubscriptionType -> IO (Consumer a)
newConsumer client topic subscription subscriptionType =
  newNamedConsumer client topic subscription ("amoebius-" <> subscription) subscriptionType

newNamedConsumer :: NativeClient -> Topic -> Text -> Text -> SubscriptionType -> IO (Consumer a)
newNamedConsumer client topic subscription consumerName subscriptionType =
  newRankedConsumer client topic subscription consumerName 0 subscriptionType

newRankedConsumer :: NativeClient -> Topic -> Text -> Text -> Int32 -> SubscriptionType -> IO (Consumer a)
newRankedConsumer client topic subscription consumerName priorityLevel subscriptionType = do
  lookupTopic client topic
  requestId <- freshRequestId client
  entityId <- freshEntityId client
  sendCommand client (commandSubscribeRanked requestId entityId subscription consumerName priorityLevel subscriptionType topic)
  _ <- awaitFrame client (isType BaseCommand'SUCCESS)
  let consumer = Consumer client entityId
  grantPermits consumer 32
  pure consumer

grantPermits :: Consumer a -> Word64 -> IO ()
grantPermits consumer permits =
  sendCommand (consumerClient consumer) (commandFlow (consumerId consumer) permits)

receive :: Serialise a => Consumer a -> IO (Either DecodeError (Received a))
receive consumer = do
  frame <- awaitFrame (consumerClient consumer) consumerFrame
  case wireCommand frame ^. F.maybe'activeConsumerChange of
    Just change | change ^. F.consumerId == consumerId consumer -> do
      if change ^. F.isActive
        then do
          sendCommand (consumerClient consumer) (commandRedeliverUnacknowledged (consumerId consumer))
          grantPermits consumer 32
        else pure ()
      receive consumer
    _ -> decodeMessage frame
  where
    consumerFrame frame = messageForConsumer frame || activeChangeForConsumer frame
    decodeMessage frame = do
      commandMessage <- case wireCommand frame ^. F.maybe'message of
        Nothing -> ioError (userError "pulsar-message-body-missing")
        Just value -> pure value
      let identifier = commandMessage ^. F.messageId
      payload <- case wirePayload frame of
        Nothing -> ioError (userError "pulsar-message-payload-missing")
        Just value -> pure value
      pure $ do
        decoded <- decodeCbor (payloadFromBytes payload)
        Right
          Received
            { receivedMessageId = fromProto identifier
            , receivedRedeliveryCount = fromIntegral (commandMessage ^. F.redeliveryCount)
            , receivedKey = wireMetadata frame >>= (^. F.maybe'partitionKey)
            , receivedValue = decoded
            }
    messageForConsumer frame = case wireCommand frame ^. F.maybe'message of
      Just message -> message ^. F.consumerId == consumerId consumer
      Nothing -> False
    activeChangeForConsumer frame = case wireCommand frame ^. F.maybe'activeConsumerChange of
      Just change -> change ^. F.consumerId == consumerId consumer
      Nothing -> False

acknowledge :: Consumer a -> MessageId -> IO ()
acknowledge consumer identifier =
  sendCommand (consumerClient consumer) (commandAck (consumerId consumer) (messageProto identifier))

redeliverUnacknowledged :: Consumer a -> IO ()
redeliverUnacknowledged consumer =
  sendCommand (consumerClient consumer) (commandRedeliverUnacknowledged (consumerId consumer))

closeConsumer :: Consumer a -> IO ()
closeConsumer consumer = do
  requestId <- freshRequestId (consumerClient consumer)
  sendCommand (consumerClient consumer) (commandCloseConsumer requestId (consumerId consumer))
  _ <- awaitFrame (consumerClient consumer) (isType BaseCommand'SUCCESS)
  pure ()

consumerApiSurface :: [Text]
consumerApiSurface =
  [ "newConsumer :: NativeClient -> Topic -> Text -> SubscriptionType -> IO (Consumer a)"
  , "receive :: Serialise a => Consumer a -> IO (Either DecodeError (Received a))"
  , "acknowledge :: Consumer a -> MessageId -> IO ()"
  ]

payloadFromBytes :: ByteString -> CborPayload
payloadFromBytes = CborPayload

fromProto :: MessageIdData -> MessageId
fromProto identifier =
  MessageId
    { messageLedgerId = identifier ^. F.ledgerId
    , messageEntryId = identifier ^. F.entryId
    , messagePartition = fromIntegral (identifier ^. F.partition)
    , messageBatchIndex = fromIntegral (identifier ^. F.batchIndex)
    , messageProto = identifier
    }
