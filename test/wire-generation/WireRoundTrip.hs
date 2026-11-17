{-# LANGUAGE OverloadedStrings #-}

-- | Run against freshly generated bindings. Each row reports actual encoded bytes
-- and whether decoding recovers the value. The independent oracle judges these rows.
module WireRoundTrip (main) where

import Data.ByteString qualified as ByteString
import Data.Function ((&))
import Data.ProtoLens qualified as Proto
import Lens.Family ((.~))
import Numeric (showHex)
import Proto.PulsarApi qualified as P
import Proto.PulsarApi_Fields qualified as F

one :: (Proto.Message a, Eq a) => String -> a -> IO ()
one name value = do
  let bytes = Proto.encodeMessage value
      recovered = Proto.decodeMessage bytes == Right value
      hex byte = case showHex byte "" of [digit] -> ['0', digit]; digits -> digits
  putStrLn (name <> "\t" <> concatMap hex (ByteString.unpack bytes) <> "\t" <> show recovered)

main :: IO ()
main = do
  one "Schema" (Proto.defMessage :: P.Schema)
  one "MessageIdData" (Proto.defMessage :: P.MessageIdData)
  one "KeyValue" (Proto.defMessage :: P.KeyValue)
  one "KeyLongValue" (Proto.defMessage :: P.KeyLongValue)
  one "IntRange" (Proto.defMessage :: P.IntRange)
  one "EncryptionKeys" (Proto.defMessage :: P.EncryptionKeys)
  one "MessageMetadata" (Proto.defMessage :: P.MessageMetadata)
  one "SingleMessageMetadata" (Proto.defMessage :: P.SingleMessageMetadata)
  one "CommandConnect" (Proto.defMessage :: P.CommandConnect)
  one "FeatureFlags" (Proto.defMessage :: P.FeatureFlags)
  one "CommandConnected" (Proto.defMessage :: P.CommandConnected)
  one "CommandAuthResponse" (Proto.defMessage :: P.CommandAuthResponse)
  one "CommandAuthChallenge" (Proto.defMessage :: P.CommandAuthChallenge)
  one "AuthData" (Proto.defMessage :: P.AuthData)
  one "KeySharedMeta" (Proto.defMessage :: P.KeySharedMeta)
  one "CommandSubscribe" (Proto.defMessage :: P.CommandSubscribe)
  one "CommandPartitionedTopicMetadata" (Proto.defMessage :: P.CommandPartitionedTopicMetadata)
  one "CommandPartitionedTopicMetadataResponse" (Proto.defMessage :: P.CommandPartitionedTopicMetadataResponse)
  one "CommandLookupTopic" (Proto.defMessage :: P.CommandLookupTopic)
  one "CommandLookupTopicResponse" (Proto.defMessage :: P.CommandLookupTopicResponse)
  one "CommandProducer" (Proto.defMessage :: P.CommandProducer)
  one "CommandSend" (Proto.defMessage :: P.CommandSend)
  one "CommandSendReceipt" (Proto.defMessage :: P.CommandSendReceipt)
  one "CommandSendError" (Proto.defMessage :: P.CommandSendError)
  one "CommandMessage" (Proto.defMessage :: P.CommandMessage)
  one "CommandAck" (Proto.defMessage :: P.CommandAck)
  one "CommandAckResponse" (Proto.defMessage :: P.CommandAckResponse)
  one "CommandActiveConsumerChange" (Proto.defMessage :: P.CommandActiveConsumerChange)
  one "CommandFlow" (Proto.defMessage :: P.CommandFlow)
  one "CommandUnsubscribe" (Proto.defMessage :: P.CommandUnsubscribe)
  one "CommandSeek" (Proto.defMessage :: P.CommandSeek)
  one "CommandReachedEndOfTopic" (Proto.defMessage :: P.CommandReachedEndOfTopic)
  one "CommandCloseProducer" (Proto.defMessage :: P.CommandCloseProducer)
  one "CommandCloseConsumer" (Proto.defMessage :: P.CommandCloseConsumer)
  one "CommandRedeliverUnacknowledgedMessages" (Proto.defMessage :: P.CommandRedeliverUnacknowledgedMessages)
  one "CommandSuccess" (Proto.defMessage :: P.CommandSuccess)
  one "CommandProducerSuccess" (Proto.defMessage :: P.CommandProducerSuccess)
  one "CommandError" (Proto.defMessage :: P.CommandError)
  one "CommandPing" (Proto.defMessage :: P.CommandPing)
  one "CommandPong" (Proto.defMessage :: P.CommandPong)
  one "CommandConsumerStats" (Proto.defMessage :: P.CommandConsumerStats)
  one "CommandConsumerStatsResponse" (Proto.defMessage :: P.CommandConsumerStatsResponse)
  one "CommandGetLastMessageId" (Proto.defMessage :: P.CommandGetLastMessageId)
  one "CommandGetLastMessageIdResponse" (Proto.defMessage :: P.CommandGetLastMessageIdResponse)
  one "CommandGetTopicsOfNamespace" (Proto.defMessage :: P.CommandGetTopicsOfNamespace)
  one "CommandGetTopicsOfNamespaceResponse" (Proto.defMessage :: P.CommandGetTopicsOfNamespaceResponse)
  one "CommandGetSchema" (Proto.defMessage :: P.CommandGetSchema)
  one "CommandGetSchemaResponse" (Proto.defMessage :: P.CommandGetSchemaResponse)
  one "CommandGetOrCreateSchema" (Proto.defMessage :: P.CommandGetOrCreateSchema)
  one "CommandGetOrCreateSchemaResponse" (Proto.defMessage :: P.CommandGetOrCreateSchemaResponse)
  one "CommandNewTxn" (Proto.defMessage :: P.CommandNewTxn)
  one "CommandNewTxnResponse" (Proto.defMessage :: P.CommandNewTxnResponse)
  one "CommandAddPartitionToTxn" (Proto.defMessage :: P.CommandAddPartitionToTxn)
  one "CommandAddPartitionToTxnResponse" (Proto.defMessage :: P.CommandAddPartitionToTxnResponse)
  one "Subscription" (Proto.defMessage :: P.Subscription)
  one "CommandAddSubscriptionToTxn" (Proto.defMessage :: P.CommandAddSubscriptionToTxn)
  one "CommandAddSubscriptionToTxnResponse" (Proto.defMessage :: P.CommandAddSubscriptionToTxnResponse)
  one "CommandEndTxn" (Proto.defMessage :: P.CommandEndTxn)
  one "CommandEndTxnResponse" (Proto.defMessage :: P.CommandEndTxnResponse)
  one "CommandEndTxnOnPartition" (Proto.defMessage :: P.CommandEndTxnOnPartition)
  one "CommandEndTxnOnPartitionResponse" (Proto.defMessage :: P.CommandEndTxnOnPartitionResponse)
  one "CommandEndTxnOnSubscription" (Proto.defMessage :: P.CommandEndTxnOnSubscription)
  one "CommandEndTxnOnSubscriptionResponse" (Proto.defMessage :: P.CommandEndTxnOnSubscriptionResponse)
  one "BaseCommand" (Proto.defMessage :: P.BaseCommand)
  one "MessageIdData-populated" ((Proto.defMessage :: P.MessageIdData) & F.ledgerId .~ 7 & F.entryId .~ 11)
