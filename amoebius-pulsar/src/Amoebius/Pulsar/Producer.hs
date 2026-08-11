{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Producer
  ( Producer
  , newProducer
  , produce
  , produceAtSequence
  , produceKeyedAtSequence
  , closeProducer
  , producerApiSurface
#ifdef PHASE35_PRODUCE_RAW_MUTANT
  , produceRaw
#endif
  ) where

import Amoebius.Pulsar.Cbor (cborBytes, encodeCbor)
import Amoebius.Pulsar.Connection (lookupTopic)
import Amoebius.Pulsar.Internal.Protocol
import Amoebius.Pulsar.Internal.Types
import Proto.PulsarApi (BaseCommand'Type (..), MessageIdData, MessageMetadata)
import Proto.PulsarApi_Fields qualified as F
import Codec.Serialise (Serialise)
#ifdef PHASE35_PRODUCE_RAW_MUTANT
import Data.ByteString (ByteString)
#endif
import Data.IORef (atomicModifyIORef', newIORef)
import Data.Function ((&))
import Data.Text (Text)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.Word (Word64)
import Lens.Family ((.~), (^.))

newProducer :: NativeClient -> Topic -> Text -> IO Producer
newProducer client topic requestedName = do
  lookupTopic client topic
  requestId <- freshRequestId client
  entityId <- freshEntityId client
  sendCommand client (commandProducer requestId entityId requestedName topic)
  frame <- awaitFrame client (isType BaseCommand'PRODUCER_SUCCESS)
  name <- case wireCommand frame ^. F.maybe'producerSuccess of
    Nothing -> ioError (userError "pulsar-producer-success-body-missing")
    Just value -> pure (value ^. F.producerName)
  Producer client entityId name <$> newIORef 0

produce :: Serialise a => Producer -> a -> IO MessageId
produce producer value = do
  sequenceId <- atomicModifyIORef' (producerNextSequence producer) (\current -> (current + 1, current))
  produceAtSequence producer sequenceId value

produceAtSequence :: Serialise a => Producer -> Word64 -> a -> IO MessageId
produceAtSequence producer sequenceId value = do
  publish producer sequenceId (messageMetadataFor producer sequenceId) value

produceKeyedAtSequence :: Serialise a => Producer -> Word64 -> Text -> a -> IO MessageId
produceKeyedAtSequence producer sequenceId key value =
  publish producer sequenceId (messageMetadataFor producer sequenceId & F.partitionKey .~ key) value

messageMetadataFor :: Producer -> Word64 -> MessageMetadata
messageMetadataFor producer sequenceId =
  messageMetadata (producerName producer) sequenceId 0

publish :: Serialise a => Producer -> Word64 -> MessageMetadata -> a -> IO MessageId
publish producer sequenceId metadata value = do
  publishTime <- round . (* 1000) <$> getPOSIXTime
  let client = producerClient producer
      stamped = metadata & F.publishTime .~ publishTime
  sendPayloadCommand client (commandSend (producerId producer) sequenceId) stamped (cborBytes (encodeCbor value))
  frame <- awaitFrame client matchesReceipt
  if isType BaseCommand'SEND_ERROR frame
    then ioError (userError ("pulsar-send-error:" <> show (wireCommand frame ^. F.maybe'sendError)))
    else case wireCommand frame ^. F.maybe'sendReceipt >>= (^. F.maybe'messageId) of
      Nothing -> ioError (userError "pulsar-send-receipt-message-id-missing")
      Just identifier -> pure (fromProto identifier)
  where
    matchesReceipt frame =
      let command = wireCommand frame
          receiptMatches = case command ^. F.maybe'sendReceipt of
            Just receipt -> receipt ^. F.producerId == producerId producer && receipt ^. F.sequenceId == sequenceId
            Nothing -> False
          errorMatches = case command ^. F.maybe'sendError of
            Just sendError -> sendError ^. F.producerId == producerId producer && sendError ^. F.sequenceId == sequenceId
            Nothing -> False
       in receiptMatches || errorMatches

closeProducer :: Producer -> IO ()
closeProducer producer = do
  requestId <- freshRequestId (producerClient producer)
  sendCommand (producerClient producer) (commandCloseProducer requestId (producerId producer))
  _ <- awaitFrame (producerClient producer) (isType BaseCommand'SUCCESS)
  pure ()

producerApiSurface :: [Text]
producerApiSurface =
  [ "newProducer :: NativeClient -> Topic -> Text -> IO Producer"
  , "produce :: Serialise a => Producer -> a -> IO MessageId"
  , "produceAtSequence :: Serialise a => Producer -> Word64 -> a -> IO MessageId"
  , "produceKeyedAtSequence :: Serialise a => Producer -> Word64 -> Text -> a -> IO MessageId"
  ]
#ifdef PHASE35_PRODUCE_RAW_MUTANT
  <> ["produceRaw :: Producer -> ByteString -> IO MessageId"]

produceRaw :: Producer -> ByteString -> IO MessageId
produceRaw producer bytes = produceAtSequence producer 0 bytes
#endif

fromProto :: MessageIdData -> MessageId
fromProto identifier =
  MessageId
    { messageLedgerId = identifier ^. F.ledgerId
    , messageEntryId = identifier ^. F.entryId
    , messagePartition = fromIntegral (identifier ^. F.partition)
    , messageBatchIndex = fromIntegral (identifier ^. F.batchIndex)
    , messageProto = identifier
    }
