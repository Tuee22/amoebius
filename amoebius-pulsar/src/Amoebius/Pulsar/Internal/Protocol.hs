{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Internal.Protocol
  ( connectHandshake
  , freshEntityId
  , freshRequestId
  , awaitFrame
  , sendCommand
  , sendPayloadCommand
  , commandConnect
  , commandLookup
  , commandProducer
  , commandSend
  , commandSubscribe
  , commandSubscribeNamed
  , commandSubscribeRanked
  , commandFlow
  , commandAck
  , commandRedeliverUnacknowledged
  , commandSeekMessage
  , commandSeekTime
  , commandCloseProducer
  , commandCloseConsumer
  , messageMetadata
  , isType
  ) where

import Amoebius.Pulsar.Internal.Frame (encodePayload, encodeSimple, receiveWireFrame, sendWireFrame)
import Amoebius.Pulsar.Internal.Types (NativeClient (..), Topic (..), WireFrame (..))
import Proto.PulsarApi
import Proto.PulsarApi_Fields qualified as F
import Amoebius.Pulsar.Subscription (SubscriptionType (..))
import Control.Concurrent.MVar (withMVar)
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.Function ((&))
import Data.Int (Int32)
import Data.IORef (atomicModifyIORef', readIORef, writeIORef)
import Data.List (findIndex)
import Data.ProtoLens (defMessage)
import Data.Text (Text)
import Data.Word (Word64)
import Lens.Family ((.~), (^.))

freshRequestId :: NativeClient -> IO Word64
freshRequestId client = atomicModifyIORef' (nativeRequestCounter client) (\value -> (value + 1, value))

freshEntityId :: NativeClient -> IO Word64
freshEntityId client = atomicModifyIORef' (nativeEntityCounter client) (\value -> (value + 1, value))

sendCommand :: NativeClient -> BaseCommand -> IO ()
sendCommand client command =
  withMVar (nativeSendLock client) $ \() -> sendWireFrame (nativeSocket client) (encodeSimple command)

sendPayloadCommand :: NativeClient -> BaseCommand -> MessageMetadata -> ByteString -> IO ()
sendPayloadCommand client command metadata payload =
  withMVar (nativeSendLock client) $ \() -> sendWireFrame (nativeSocket client) (encodePayload command metadata payload)

isType :: BaseCommand'Type -> WireFrame -> Bool
isType expected frame = wireCommand frame ^. F.type' == expected

takePending :: NativeClient -> (WireFrame -> Bool) -> IO (Maybe WireFrame)
takePending client predicate = do
  pending <- readIORef (nativePendingFrames client)
  case findIndex predicate pending of
    Nothing -> pure Nothing
    Just index -> do
      case splitAt index pending of
        (before, selected : after) -> do
          writeIORef (nativePendingFrames client) (before <> after)
          pure (Just selected)
        (_, []) -> ioError (userError "pulsar-pending-frame-index-invariant")

awaitFrame :: NativeClient -> (WireFrame -> Bool) -> IO WireFrame
awaitFrame client predicate = do
  cached <- takePending client predicate
  maybe receiveLoop pure cached
  where
    receiveLoop = do
      frame <- receiveWireFrame (nativeSocket client)
      let command = wireCommand frame
      if command ^. F.type' == BaseCommand'PING
        then sendCommand client (defMessage & F.type' .~ BaseCommand'PONG & F.pong .~ defMessage) >> receiveLoop
        else
          if command ^. F.type' == BaseCommand'ERROR
            then ioError (userError ("pulsar-command-error:" <> show (command ^. F.maybe'error)))
            else
              if predicate frame
                then pure frame
                else atomicModifyIORef' (nativePendingFrames client) (\frames -> (frames <> [frame], ())) >> receiveLoop

connectHandshake :: NativeClient -> IO ()
connectHandshake client = do
  sendCommand client commandConnect
  frame <- awaitFrame client (isType BaseCommand'CONNECTED)
  unless (wireCommand frame ^. F.maybe'connected /= Nothing) (ioError (userError "pulsar-connected-body-missing"))

commandConnect :: BaseCommand
commandConnect =
  defMessage
    & F.type' .~ BaseCommand'CONNECT
    & F.connect .~ (defMessage & F.clientVersion .~ "amoebius-pulsar/0.1" & F.protocolVersion .~ 15)

commandLookup :: Word64 -> Topic -> BaseCommand
commandLookup requestId (Topic topic) =
  defMessage
    & F.type' .~ BaseCommand'LOOKUP
    & F.lookupTopic .~ (defMessage & F.topic .~ topic & F.requestId .~ requestId)

commandProducer :: Word64 -> Word64 -> Text -> Topic -> BaseCommand
commandProducer requestId entityId name (Topic topic) =
  defMessage
    & F.type' .~ BaseCommand'PRODUCER
    & F.producer .~
      ( defMessage
          & F.topic .~ topic
          & F.producerId .~ entityId
          & F.requestId .~ requestId
          & F.producerName .~ name
          & F.userProvidedProducerName .~ True
      )

commandSend :: Word64 -> Word64 -> BaseCommand
commandSend entityId sequenceId =
  defMessage
    & F.type' .~ BaseCommand'SEND
    & F.send .~ (defMessage & F.producerId .~ entityId & F.sequenceId .~ sequenceId)

commandSubscribe :: Word64 -> Word64 -> Text -> SubscriptionType -> Topic -> BaseCommand
commandSubscribe requestId entityId subscription subscriptionType (Topic topic) =
  commandSubscribeNamed requestId entityId subscription ("amoebius-" <> subscription) subscriptionType (Topic topic)

commandSubscribeNamed :: Word64 -> Word64 -> Text -> Text -> SubscriptionType -> Topic -> BaseCommand
commandSubscribeNamed requestId entityId subscription consumerName subscriptionType (Topic topic) =
  commandSubscribeRanked requestId entityId subscription consumerName 0 subscriptionType (Topic topic)

commandSubscribeRanked :: Word64 -> Word64 -> Text -> Text -> Int32 -> SubscriptionType -> Topic -> BaseCommand
commandSubscribeRanked requestId entityId subscription consumerName priorityLevel subscriptionType (Topic topic) =
  defMessage
    & F.type' .~ BaseCommand'SUBSCRIBE
    & F.subscribe .~
      ( defMessage
          & F.topic .~ topic
          & F.subscription .~ subscription
          & F.subType .~ nativeSubscription subscriptionType
          & F.consumerId .~ entityId
          & F.requestId .~ requestId
          & F.consumerName .~ consumerName
          & F.priorityLevel .~ priorityLevel
          & F.durable .~ True
          & F.initialPosition .~ CommandSubscribe'Earliest
      )
  where
    nativeSubscription Exclusive = CommandSubscribe'Exclusive
    nativeSubscription Failover = CommandSubscribe'Failover
    nativeSubscription Shared = CommandSubscribe'Shared
    nativeSubscription KeyShared = CommandSubscribe'Key_Shared

commandFlow :: Word64 -> Word64 -> BaseCommand
commandFlow entityId permits =
  defMessage
    & F.type' .~ BaseCommand'FLOW
    & F.flow .~ (defMessage & F.consumerId .~ entityId & F.messagePermits .~ fromIntegral permits)

commandAck :: Word64 -> MessageIdData -> BaseCommand
commandAck entityId messageId =
  defMessage
    & F.type' .~ BaseCommand'ACK
    & F.ack .~
      ( defMessage
          & F.consumerId .~ entityId
          & F.ackType .~ CommandAck'Individual
          & F.messageId .~ [messageId]
      )

commandRedeliverUnacknowledged :: Word64 -> BaseCommand
commandRedeliverUnacknowledged entityId =
  defMessage
    & F.type' .~ BaseCommand'REDELIVER_UNACKNOWLEDGED_MESSAGES
    & F.redeliverUnacknowledgedMessages .~ (defMessage & F.consumerId .~ entityId)

commandSeekMessage :: Word64 -> Word64 -> MessageIdData -> BaseCommand
commandSeekMessage requestId entityId messageId =
  defMessage
    & F.type' .~ BaseCommand'SEEK
    & F.seek .~ (defMessage & F.consumerId .~ entityId & F.requestId .~ requestId & F.messageId .~ messageId)

commandSeekTime :: Word64 -> Word64 -> Word64 -> BaseCommand
commandSeekTime requestId entityId milliseconds =
  defMessage
    & F.type' .~ BaseCommand'SEEK
    & F.seek .~ (defMessage & F.consumerId .~ entityId & F.requestId .~ requestId & F.messagePublishTime .~ milliseconds)

commandCloseProducer :: Word64 -> Word64 -> BaseCommand
commandCloseProducer requestId entityId =
  defMessage
    & F.type' .~ BaseCommand'CLOSE_PRODUCER
    & F.closeProducer .~ (defMessage & F.producerId .~ entityId & F.requestId .~ requestId)

commandCloseConsumer :: Word64 -> Word64 -> BaseCommand
commandCloseConsumer requestId entityId =
  defMessage
    & F.type' .~ BaseCommand'CLOSE_CONSUMER
    & F.closeConsumer .~ (defMessage & F.consumerId .~ entityId & F.requestId .~ requestId)

messageMetadata :: Text -> Word64 -> Word64 -> MessageMetadata
messageMetadata name sequenceId publishTime =
  defMessage
    & F.producerName .~ name
    & F.sequenceId .~ sequenceId
    & F.publishTime .~ publishTime
