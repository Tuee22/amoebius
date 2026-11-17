{-# LANGUAGE OverloadedStrings #-}

-- | Haskell-owned declarations of the Apache Pulsar wire schema formerly carried by
-- the maintained supernova fork. Derived from Apache Pulsar's PulsarApi.proto,
-- licensed under the Apache License, Version 2.0 (see LICENSE).
module Amoebius.Pulsar.Wire
  ( FieldCardinality (..), ProtocolField (..), ProtocolEnum (..), ProtocolMessage (..)
  , protocolDeclarations, protocolEnums, renderProtocol, renderProtocolFrom
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data FieldCardinality = Required | Optional | Repeated deriving stock (Eq, Ord, Show)
data ProtocolField = ProtocolField
  { protocolFieldName :: Text
  , protocolFieldNumber :: Natural
  , protocolFieldCardinality :: FieldCardinality
  , protocolFieldType :: Text
  , protocolFieldDefault :: Maybe Text
  } deriving stock (Eq, Ord, Show)
data ProtocolEnum = ProtocolEnum
  { protocolEnumName :: Text
  , protocolEnumValues :: [(Text, Int)]
  } deriving stock (Eq, Ord, Show)
data ProtocolMessage = ProtocolMessage
  { protocolMessageName :: Text
  , protocolMessageFields :: [ProtocolField]
  , protocolMessageEnums :: [ProtocolEnum]
  } deriving stock (Eq, Ord, Show)

protocolDeclarations :: [ProtocolMessage]
protocolDeclarations =
  [ ProtocolMessage "Schema"
      [ ProtocolField "name" 1 Required "string" Nothing
        , ProtocolField "schema_data" 3 Required "bytes" Nothing
        , ProtocolField "type" 4 Required "Type" Nothing
        , ProtocolField "properties" 5 Repeated "KeyValue" Nothing
      ]
      [ ProtocolEnum "Type" [ ("None", 0)
          , ("String", 1)
          , ("Json", 2)
          , ("Protobuf", 3)
          , ("Avro", 4)
          , ("Bool", 5)
          , ("Int8", 6)
          , ("Int16", 7)
          , ("Int32", 8)
          , ("Int64", 9)
          , ("Float", 10)
          , ("Double", 11)
          , ("Date", 12)
          , ("Time", 13)
          , ("Timestamp", 14)
          , ("KeyValue", 15)
        ]
      ]
    , ProtocolMessage "MessageIdData"
      [ ProtocolField "ledgerId" 1 Required "uint64" Nothing
        , ProtocolField "entryId" 2 Required "uint64" Nothing
        , ProtocolField "partition" 3 Optional "int32" (Just "-1")
        , ProtocolField "batch_index" 4 Optional "int32" (Just "-1")
        , ProtocolField "ack_set" 5 Repeated "int64" Nothing
      ]
      []
    , ProtocolMessage "KeyValue"
      [ ProtocolField "key" 1 Required "string" Nothing
        , ProtocolField "value" 2 Required "string" Nothing
      ]
      []
    , ProtocolMessage "KeyLongValue"
      [ ProtocolField "key" 1 Required "string" Nothing
        , ProtocolField "value" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "IntRange"
      [ ProtocolField "start" 1 Required "int32" Nothing
        , ProtocolField "end" 2 Required "int32" Nothing
      ]
      []
    , ProtocolMessage "EncryptionKeys"
      [ ProtocolField "key" 1 Required "string" Nothing
        , ProtocolField "value" 2 Required "bytes" Nothing
        , ProtocolField "metadata" 3 Repeated "KeyValue" Nothing
      ]
      []
    , ProtocolMessage "MessageMetadata"
      [ ProtocolField "producer_name" 1 Required "string" Nothing
        , ProtocolField "sequence_id" 2 Required "uint64" Nothing
        , ProtocolField "publish_time" 3 Required "uint64" Nothing
        , ProtocolField "properties" 4 Repeated "KeyValue" Nothing
        , ProtocolField "replicated_from" 5 Optional "string" Nothing
        , ProtocolField "partition_key" 6 Optional "string" Nothing
        , ProtocolField "replicate_to" 7 Repeated "string" Nothing
        , ProtocolField "compression" 8 Optional "CompressionType" (Just "NONE")
        , ProtocolField "uncompressed_size" 9 Optional "uint32" (Just "0")
        , ProtocolField "num_messages_in_batch" 11 Optional "int32" (Just "1")
        , ProtocolField "event_time" 12 Optional "uint64" (Just "0")
        , ProtocolField "encryption_keys" 13 Repeated "EncryptionKeys" Nothing
        , ProtocolField "encryption_algo" 14 Optional "string" Nothing
        , ProtocolField "encryption_param" 15 Optional "bytes" Nothing
        , ProtocolField "schema_version" 16 Optional "bytes" Nothing
        , ProtocolField "partition_key_b64_encoded" 17 Optional "bool" (Just "false")
        , ProtocolField "ordering_key" 18 Optional "bytes" Nothing
        , ProtocolField "deliver_at_time" 19 Optional "int64" Nothing
        , ProtocolField "marker_type" 20 Optional "int32" Nothing
        , ProtocolField "txnid_least_bits" 22 Optional "uint64" Nothing
        , ProtocolField "txnid_most_bits" 23 Optional "uint64" Nothing
        , ProtocolField "highest_sequence_id" 24 Optional "uint64" (Just "0")
        , ProtocolField "null_value" 25 Optional "bool" (Just "false")
        , ProtocolField "uuid" 26 Optional "string" Nothing
        , ProtocolField "num_chunks_from_msg" 27 Optional "int32" Nothing
        , ProtocolField "total_chunk_msg_size" 28 Optional "int32" Nothing
        , ProtocolField "chunk_id" 29 Optional "int32" Nothing
        , ProtocolField "null_partition_key" 30 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "SingleMessageMetadata"
      [ ProtocolField "properties" 1 Repeated "KeyValue" Nothing
        , ProtocolField "partition_key" 2 Optional "string" Nothing
        , ProtocolField "payload_size" 3 Required "int32" Nothing
        , ProtocolField "compacted_out" 4 Optional "bool" (Just "false")
        , ProtocolField "event_time" 5 Optional "uint64" (Just "0")
        , ProtocolField "partition_key_b64_encoded" 6 Optional "bool" (Just "false")
        , ProtocolField "ordering_key" 7 Optional "bytes" Nothing
        , ProtocolField "sequence_id" 8 Optional "uint64" Nothing
        , ProtocolField "null_value" 9 Optional "bool" (Just "false")
        , ProtocolField "null_partition_key" 10 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "CommandConnect"
      [ ProtocolField "client_version" 1 Required "string" Nothing
        , ProtocolField "auth_method" 2 Optional "AuthMethod" Nothing
        , ProtocolField "auth_method_name" 5 Optional "string" Nothing
        , ProtocolField "auth_data" 3 Optional "bytes" Nothing
        , ProtocolField "protocol_version" 4 Optional "int32" (Just "0")
        , ProtocolField "proxy_to_broker_url" 6 Optional "string" Nothing
        , ProtocolField "original_principal" 7 Optional "string" Nothing
        , ProtocolField "original_auth_data" 8 Optional "string" Nothing
        , ProtocolField "original_auth_method" 9 Optional "string" Nothing
        , ProtocolField "feature_flags" 10 Optional "FeatureFlags" Nothing
      ]
      []
    , ProtocolMessage "FeatureFlags"
      [ ProtocolField "supports_auth_refresh" 1 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "CommandConnected"
      [ ProtocolField "server_version" 1 Required "string" Nothing
        , ProtocolField "protocol_version" 2 Optional "int32" (Just "0")
        , ProtocolField "max_message_size" 3 Optional "int32" Nothing
      ]
      []
    , ProtocolMessage "CommandAuthResponse"
      [ ProtocolField "client_version" 1 Optional "string" Nothing
        , ProtocolField "response" 2 Optional "AuthData" Nothing
        , ProtocolField "protocol_version" 3 Optional "int32" (Just "0")
      ]
      []
    , ProtocolMessage "CommandAuthChallenge"
      [ ProtocolField "server_version" 1 Optional "string" Nothing
        , ProtocolField "challenge" 2 Optional "AuthData" Nothing
        , ProtocolField "protocol_version" 3 Optional "int32" (Just "0")
      ]
      []
    , ProtocolMessage "AuthData"
      [ ProtocolField "auth_method_name" 1 Optional "string" Nothing
        , ProtocolField "auth_data" 2 Optional "bytes" Nothing
      ]
      []
    , ProtocolMessage "KeySharedMeta"
      [ ProtocolField "keySharedMode" 1 Required "KeySharedMode" Nothing
        , ProtocolField "hashRanges" 3 Repeated "IntRange" Nothing
        , ProtocolField "allowOutOfOrderDelivery" 4 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "CommandSubscribe"
      [ ProtocolField "topic" 1 Required "string" Nothing
        , ProtocolField "subscription" 2 Required "string" Nothing
        , ProtocolField "subType" 3 Required "SubType" Nothing
        , ProtocolField "consumer_id" 4 Required "uint64" Nothing
        , ProtocolField "request_id" 5 Required "uint64" Nothing
        , ProtocolField "consumer_name" 6 Optional "string" Nothing
        , ProtocolField "priority_level" 7 Optional "int32" Nothing
        , ProtocolField "durable" 8 Optional "bool" (Just "true")
        , ProtocolField "start_message_id" 9 Optional "MessageIdData" Nothing
        , ProtocolField "metadata" 10 Repeated "KeyValue" Nothing
        , ProtocolField "read_compacted" 11 Optional "bool" Nothing
        , ProtocolField "schema" 12 Optional "Schema" Nothing
        , ProtocolField "initialPosition" 13 Optional "InitialPosition" (Just "Latest")
        , ProtocolField "replicate_subscription_state" 14 Optional "bool" Nothing
        , ProtocolField "force_topic_creation" 15 Optional "bool" (Just "true")
        , ProtocolField "start_message_rollback_duration_sec" 16 Optional "uint64" (Just "0")
        , ProtocolField "keySharedMeta" 17 Optional "KeySharedMeta" Nothing
      ]
      [ ProtocolEnum "SubType" [ ("Exclusive", 0)
          , ("Shared", 1)
          , ("Failover", 2)
          , ("Key_Shared", 3)
        ]
        , ProtocolEnum "InitialPosition" [ ("Latest", 0)
          , ("Earliest", 1)
        ]
      ]
    , ProtocolMessage "CommandPartitionedTopicMetadata"
      [ ProtocolField "topic" 1 Required "string" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
        , ProtocolField "original_principal" 3 Optional "string" Nothing
        , ProtocolField "original_auth_data" 4 Optional "string" Nothing
        , ProtocolField "original_auth_method" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandPartitionedTopicMetadataResponse"
      [ ProtocolField "partitions" 1 Optional "uint32" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
        , ProtocolField "response" 3 Optional "LookupType" Nothing
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      [ ProtocolEnum "LookupType" [ ("Success", 0)
          , ("Failed", 1)
        ]
      ]
    , ProtocolMessage "CommandLookupTopic"
      [ ProtocolField "topic" 1 Required "string" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
        , ProtocolField "authoritative" 3 Optional "bool" (Just "false")
        , ProtocolField "original_principal" 4 Optional "string" Nothing
        , ProtocolField "original_auth_data" 5 Optional "string" Nothing
        , ProtocolField "original_auth_method" 6 Optional "string" Nothing
        , ProtocolField "advertised_listener_name" 7 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandLookupTopicResponse"
      [ ProtocolField "brokerServiceUrl" 1 Optional "string" Nothing
        , ProtocolField "brokerServiceUrlTls" 2 Optional "string" Nothing
        , ProtocolField "response" 3 Optional "LookupType" Nothing
        , ProtocolField "request_id" 4 Required "uint64" Nothing
        , ProtocolField "authoritative" 5 Optional "bool" (Just "false")
        , ProtocolField "error" 6 Optional "ServerError" Nothing
        , ProtocolField "message" 7 Optional "string" Nothing
        , ProtocolField "proxy_through_service_url" 8 Optional "bool" (Just "false")
      ]
      [ ProtocolEnum "LookupType" [ ("Redirect", 0)
          , ("Connect", 1)
          , ("Failed", 2)
        ]
      ]
    , ProtocolMessage "CommandProducer"
      [ ProtocolField "topic" 1 Required "string" Nothing
        , ProtocolField "producer_id" 2 Required "uint64" Nothing
        , ProtocolField "request_id" 3 Required "uint64" Nothing
        , ProtocolField "producer_name" 4 Optional "string" Nothing
        , ProtocolField "encrypted" 5 Optional "bool" (Just "false")
        , ProtocolField "metadata" 6 Repeated "KeyValue" Nothing
        , ProtocolField "schema" 7 Optional "Schema" Nothing
        , ProtocolField "epoch" 8 Optional "uint64" (Just "0")
        , ProtocolField "user_provided_producer_name" 9 Optional "bool" (Just "true")
      ]
      []
    , ProtocolMessage "CommandSend"
      [ ProtocolField "producer_id" 1 Required "uint64" Nothing
        , ProtocolField "sequence_id" 2 Required "uint64" Nothing
        , ProtocolField "num_messages" 3 Optional "int32" (Just "1")
        , ProtocolField "txnid_least_bits" 4 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 5 Optional "uint64" (Just "0")
        , ProtocolField "highest_sequence_id" 6 Optional "uint64" (Just "0")
        , ProtocolField "is_chunk" 7 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "CommandSendReceipt"
      [ ProtocolField "producer_id" 1 Required "uint64" Nothing
        , ProtocolField "sequence_id" 2 Required "uint64" Nothing
        , ProtocolField "message_id" 3 Optional "MessageIdData" Nothing
        , ProtocolField "highest_sequence_id" 4 Optional "uint64" (Just "0")
      ]
      []
    , ProtocolMessage "CommandSendError"
      [ ProtocolField "producer_id" 1 Required "uint64" Nothing
        , ProtocolField "sequence_id" 2 Required "uint64" Nothing
        , ProtocolField "error" 3 Required "ServerError" Nothing
        , ProtocolField "message" 4 Required "string" Nothing
      ]
      []
    , ProtocolMessage "CommandMessage"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "message_id" 2 Required "MessageIdData" Nothing
        , ProtocolField "redelivery_count" 3 Optional "uint32" (Just "0")
        , ProtocolField "ack_set" 4 Repeated "int64" Nothing
      ]
      []
    , ProtocolMessage "CommandAck"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "ack_type" 2 Required "AckType" Nothing
        , ProtocolField "message_id" 3 Repeated "MessageIdData" Nothing
        , ProtocolField "validation_error" 4 Optional "ValidationError" Nothing
        , ProtocolField "properties" 5 Repeated "KeyLongValue" Nothing
        , ProtocolField "txnid_least_bits" 6 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 7 Optional "uint64" (Just "0")
      ]
      [ ProtocolEnum "AckType" [ ("Individual", 0)
          , ("Cumulative", 1)
        ]
        , ProtocolEnum "ValidationError" [ ("UncompressedSizeCorruption", 0)
          , ("DecompressionError", 1)
          , ("ChecksumMismatch", 2)
          , ("BatchDeSerializeError", 3)
          , ("DecryptionError", 4)
        ]
      ]
    , ProtocolMessage "CommandAckResponse"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandActiveConsumerChange"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "is_active" 2 Optional "bool" (Just "false")
      ]
      []
    , ProtocolMessage "CommandFlow"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "messagePermits" 2 Required "uint32" Nothing
      ]
      []
    , ProtocolMessage "CommandUnsubscribe"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandSeek"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
        , ProtocolField "message_id" 3 Optional "MessageIdData" Nothing
        , ProtocolField "message_publish_time" 4 Optional "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandReachedEndOfTopic"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandCloseProducer"
      [ ProtocolField "producer_id" 1 Required "uint64" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandCloseConsumer"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandRedeliverUnacknowledgedMessages"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "message_ids" 2 Repeated "MessageIdData" Nothing
      ]
      []
    , ProtocolMessage "CommandSuccess"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "schema" 2 Optional "Schema" Nothing
      ]
      []
    , ProtocolMessage "CommandProducerSuccess"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "producer_name" 2 Required "string" Nothing
        , ProtocolField "last_sequence_id" 3 Optional "int64" (Just "-1")
        , ProtocolField "schema_version" 4 Optional "bytes" Nothing
      ]
      []
    , ProtocolMessage "CommandError"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "error" 2 Required "ServerError" Nothing
        , ProtocolField "message" 3 Required "string" Nothing
      ]
      []
    , ProtocolMessage "CommandPing"
      []
      []
    , ProtocolMessage "CommandPong"
      []
      []
    , ProtocolMessage "CommandConsumerStats"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "consumer_id" 4 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandConsumerStatsResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "error_code" 2 Optional "ServerError" Nothing
        , ProtocolField "error_message" 3 Optional "string" Nothing
        , ProtocolField "msgRateOut" 4 Optional "double" Nothing
        , ProtocolField "msgThroughputOut" 5 Optional "double" Nothing
        , ProtocolField "msgRateRedeliver" 6 Optional "double" Nothing
        , ProtocolField "consumerName" 7 Optional "string" Nothing
        , ProtocolField "availablePermits" 8 Optional "uint64" Nothing
        , ProtocolField "unackedMessages" 9 Optional "uint64" Nothing
        , ProtocolField "blockedConsumerOnUnackedMsgs" 10 Optional "bool" Nothing
        , ProtocolField "address" 11 Optional "string" Nothing
        , ProtocolField "connectedSince" 12 Optional "string" Nothing
        , ProtocolField "type" 13 Optional "string" Nothing
        , ProtocolField "msgRateExpired" 14 Optional "double" Nothing
        , ProtocolField "msgBacklog" 15 Optional "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandGetLastMessageId"
      [ ProtocolField "consumer_id" 1 Required "uint64" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandGetLastMessageIdResponse"
      [ ProtocolField "last_message_id" 1 Required "MessageIdData" Nothing
        , ProtocolField "request_id" 2 Required "uint64" Nothing
      ]
      []
    , ProtocolMessage "CommandGetTopicsOfNamespace"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "namespace" 2 Required "string" Nothing
        , ProtocolField "mode" 3 Optional "Mode" (Just "PERSISTENT")
      ]
      [ ProtocolEnum "Mode" [ ("PERSISTENT", 0)
          , ("NON_PERSISTENT", 1)
          , ("ALL", 2)
        ]
      ]
    , ProtocolMessage "CommandGetTopicsOfNamespaceResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "topics" 2 Repeated "string" Nothing
      ]
      []
    , ProtocolMessage "CommandGetSchema"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "topic" 2 Required "string" Nothing
        , ProtocolField "schema_version" 3 Optional "bytes" Nothing
      ]
      []
    , ProtocolMessage "CommandGetSchemaResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "error_code" 2 Optional "ServerError" Nothing
        , ProtocolField "error_message" 3 Optional "string" Nothing
        , ProtocolField "schema" 4 Optional "Schema" Nothing
        , ProtocolField "schema_version" 5 Optional "bytes" Nothing
      ]
      []
    , ProtocolMessage "CommandGetOrCreateSchema"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "topic" 2 Required "string" Nothing
        , ProtocolField "schema" 3 Required "Schema" Nothing
      ]
      []
    , ProtocolMessage "CommandGetOrCreateSchemaResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "error_code" 2 Optional "ServerError" Nothing
        , ProtocolField "error_message" 3 Optional "string" Nothing
        , ProtocolField "schema_version" 4 Optional "bytes" Nothing
      ]
      []
    , ProtocolMessage "CommandNewTxn"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txn_ttl_seconds" 2 Optional "uint64" (Just "0")
        , ProtocolField "tc_id" 3 Optional "uint64" (Just "0")
      ]
      []
    , ProtocolMessage "CommandNewTxnResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandAddPartitionToTxn"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "partitions" 4 Repeated "string" Nothing
      ]
      []
    , ProtocolMessage "CommandAddPartitionToTxnResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "Subscription"
      [ ProtocolField "topic" 1 Required "string" Nothing
        , ProtocolField "subscription" 2 Required "string" Nothing
      ]
      []
    , ProtocolMessage "CommandAddSubscriptionToTxn"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "subscription" 4 Repeated "Subscription" Nothing
      ]
      []
    , ProtocolMessage "CommandAddSubscriptionToTxnResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxn"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "txn_action" 4 Optional "TxnAction" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxnResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxnOnPartition"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "topic" 4 Optional "string" Nothing
        , ProtocolField "txn_action" 5 Optional "TxnAction" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxnOnPartitionResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxnOnSubscription"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "subscription" 4 Optional "Subscription" Nothing
        , ProtocolField "txn_action" 5 Optional "TxnAction" Nothing
      ]
      []
    , ProtocolMessage "CommandEndTxnOnSubscriptionResponse"
      [ ProtocolField "request_id" 1 Required "uint64" Nothing
        , ProtocolField "txnid_least_bits" 2 Optional "uint64" (Just "0")
        , ProtocolField "txnid_most_bits" 3 Optional "uint64" (Just "0")
        , ProtocolField "error" 4 Optional "ServerError" Nothing
        , ProtocolField "message" 5 Optional "string" Nothing
      ]
      []
    , ProtocolMessage "BaseCommand"
      [ ProtocolField "type" 1 Required "Type" Nothing
        , ProtocolField "connect" 2 Optional "CommandConnect" Nothing
        , ProtocolField "connected" 3 Optional "CommandConnected" Nothing
        , ProtocolField "subscribe" 4 Optional "CommandSubscribe" Nothing
        , ProtocolField "producer" 5 Optional "CommandProducer" Nothing
        , ProtocolField "send" 6 Optional "CommandSend" Nothing
        , ProtocolField "send_receipt" 7 Optional "CommandSendReceipt" Nothing
        , ProtocolField "send_error" 8 Optional "CommandSendError" Nothing
        , ProtocolField "message" 9 Optional "CommandMessage" Nothing
        , ProtocolField "ack" 10 Optional "CommandAck" Nothing
        , ProtocolField "flow" 11 Optional "CommandFlow" Nothing
        , ProtocolField "unsubscribe" 12 Optional "CommandUnsubscribe" Nothing
        , ProtocolField "success" 13 Optional "CommandSuccess" Nothing
        , ProtocolField "error" 14 Optional "CommandError" Nothing
        , ProtocolField "close_producer" 15 Optional "CommandCloseProducer" Nothing
        , ProtocolField "close_consumer" 16 Optional "CommandCloseConsumer" Nothing
        , ProtocolField "producer_success" 17 Optional "CommandProducerSuccess" Nothing
        , ProtocolField "ping" 18 Optional "CommandPing" Nothing
        , ProtocolField "pong" 19 Optional "CommandPong" Nothing
        , ProtocolField "redeliverUnacknowledgedMessages" 20 Optional "CommandRedeliverUnacknowledgedMessages" Nothing
        , ProtocolField "partitionMetadata" 21 Optional "CommandPartitionedTopicMetadata" Nothing
        , ProtocolField "partitionMetadataResponse" 22 Optional "CommandPartitionedTopicMetadataResponse" Nothing
        , ProtocolField "lookupTopic" 23 Optional "CommandLookupTopic" Nothing
        , ProtocolField "lookupTopicResponse" 24 Optional "CommandLookupTopicResponse" Nothing
        , ProtocolField "consumerStats" 25 Optional "CommandConsumerStats" Nothing
        , ProtocolField "consumerStatsResponse" 26 Optional "CommandConsumerStatsResponse" Nothing
        , ProtocolField "reachedEndOfTopic" 27 Optional "CommandReachedEndOfTopic" Nothing
        , ProtocolField "seek" 28 Optional "CommandSeek" Nothing
        , ProtocolField "getLastMessageId" 29 Optional "CommandGetLastMessageId" Nothing
        , ProtocolField "getLastMessageIdResponse" 30 Optional "CommandGetLastMessageIdResponse" Nothing
        , ProtocolField "active_consumer_change" 31 Optional "CommandActiveConsumerChange" Nothing
        , ProtocolField "getTopicsOfNamespace" 32 Optional "CommandGetTopicsOfNamespace" Nothing
        , ProtocolField "getTopicsOfNamespaceResponse" 33 Optional "CommandGetTopicsOfNamespaceResponse" Nothing
        , ProtocolField "getSchema" 34 Optional "CommandGetSchema" Nothing
        , ProtocolField "getSchemaResponse" 35 Optional "CommandGetSchemaResponse" Nothing
        , ProtocolField "authChallenge" 36 Optional "CommandAuthChallenge" Nothing
        , ProtocolField "authResponse" 37 Optional "CommandAuthResponse" Nothing
        , ProtocolField "ackResponse" 38 Optional "CommandAckResponse" Nothing
        , ProtocolField "getOrCreateSchema" 39 Optional "CommandGetOrCreateSchema" Nothing
        , ProtocolField "getOrCreateSchemaResponse" 40 Optional "CommandGetOrCreateSchemaResponse" Nothing
        , ProtocolField "newTxn" 50 Optional "CommandNewTxn" Nothing
        , ProtocolField "newTxnResponse" 51 Optional "CommandNewTxnResponse" Nothing
        , ProtocolField "addPartitionToTxn" 52 Optional "CommandAddPartitionToTxn" Nothing
        , ProtocolField "addPartitionToTxnResponse" 53 Optional "CommandAddPartitionToTxnResponse" Nothing
        , ProtocolField "addSubscriptionToTxn" 54 Optional "CommandAddSubscriptionToTxn" Nothing
        , ProtocolField "addSubscriptionToTxnResponse" 55 Optional "CommandAddSubscriptionToTxnResponse" Nothing
        , ProtocolField "endTxn" 56 Optional "CommandEndTxn" Nothing
        , ProtocolField "endTxnResponse" 57 Optional "CommandEndTxnResponse" Nothing
        , ProtocolField "endTxnOnPartition" 58 Optional "CommandEndTxnOnPartition" Nothing
        , ProtocolField "endTxnOnPartitionResponse" 59 Optional "CommandEndTxnOnPartitionResponse" Nothing
        , ProtocolField "endTxnOnSubscription" 60 Optional "CommandEndTxnOnSubscription" Nothing
        , ProtocolField "endTxnOnSubscriptionResponse" 61 Optional "CommandEndTxnOnSubscriptionResponse" Nothing
      ]
      [ ProtocolEnum "Type" [ ("CONNECT", 2)
          , ("CONNECTED", 3)
          , ("SUBSCRIBE", 4)
          , ("PRODUCER", 5)
          , ("SEND", 6)
          , ("SEND_RECEIPT", 7)
          , ("SEND_ERROR", 8)
          , ("MESSAGE", 9)
          , ("ACK", 10)
          , ("FLOW", 11)
          , ("UNSUBSCRIBE", 12)
          , ("SUCCESS", 13)
          , ("ERROR", 14)
          , ("CLOSE_PRODUCER", 15)
          , ("CLOSE_CONSUMER", 16)
          , ("PRODUCER_SUCCESS", 17)
          , ("PING", 18)
          , ("PONG", 19)
          , ("REDELIVER_UNACKNOWLEDGED_MESSAGES", 20)
          , ("PARTITIONED_METADATA", 21)
          , ("PARTITIONED_METADATA_RESPONSE", 22)
          , ("LOOKUP", 23)
          , ("LOOKUP_RESPONSE", 24)
          , ("CONSUMER_STATS", 25)
          , ("CONSUMER_STATS_RESPONSE", 26)
          , ("REACHED_END_OF_TOPIC", 27)
          , ("SEEK", 28)
          , ("GET_LAST_MESSAGE_ID", 29)
          , ("GET_LAST_MESSAGE_ID_RESPONSE", 30)
          , ("ACTIVE_CONSUMER_CHANGE", 31)
          , ("GET_TOPICS_OF_NAMESPACE", 32)
          , ("GET_TOPICS_OF_NAMESPACE_RESPONSE", 33)
          , ("GET_SCHEMA", 34)
          , ("GET_SCHEMA_RESPONSE", 35)
          , ("AUTH_CHALLENGE", 36)
          , ("AUTH_RESPONSE", 37)
          , ("ACK_RESPONSE", 38)
          , ("GET_OR_CREATE_SCHEMA", 39)
          , ("GET_OR_CREATE_SCHEMA_RESPONSE", 40)
          , ("NEW_TXN", 50)
          , ("NEW_TXN_RESPONSE", 51)
          , ("ADD_PARTITION_TO_TXN", 52)
          , ("ADD_PARTITION_TO_TXN_RESPONSE", 53)
          , ("ADD_SUBSCRIPTION_TO_TXN", 54)
          , ("ADD_SUBSCRIPTION_TO_TXN_RESPONSE", 55)
          , ("END_TXN", 56)
          , ("END_TXN_RESPONSE", 57)
          , ("END_TXN_ON_PARTITION", 58)
          , ("END_TXN_ON_PARTITION_RESPONSE", 59)
          , ("END_TXN_ON_SUBSCRIPTION", 60)
          , ("END_TXN_ON_SUBSCRIPTION_RESPONSE", 61)
        ]
      ]
  ]

protocolEnums :: [ProtocolEnum]
protocolEnums =
  [ ProtocolEnum "CompressionType" [ ("NONE", 0)
          , ("LZ4", 1)
          , ("ZLIB", 2)
          , ("ZSTD", 3)
          , ("SNAPPY", 4)
        ]
    , ProtocolEnum "ServerError" [ ("UnknownError", 0)
          , ("MetadataError", 1)
          , ("PersistenceError", 2)
          , ("AuthenticationError", 3)
          , ("AuthorizationError", 4)
          , ("ConsumerBusy", 5)
          , ("ServiceNotReady", 6)
          , ("ProducerBlockedQuotaExceededError", 7)
          , ("ProducerBlockedQuotaExceededException", 8)
          , ("ChecksumError", 9)
          , ("UnsupportedVersionError", 10)
          , ("TopicNotFound", 11)
          , ("SubscriptionNotFound", 12)
          , ("ConsumerNotFound", 13)
          , ("TooManyRequests", 14)
          , ("TopicTerminatedError", 15)
          , ("ProducerBusy", 16)
          , ("InvalidTopicName", 17)
          , ("IncompatibleSchema", 18)
          , ("ConsumerAssignError", 19)
          , ("TransactionCoordinatorNotFound", 20)
          , ("InvalidTxnStatus", 21)
          , ("NotAllowedError", 22)
        ]
    , ProtocolEnum "AuthMethod" [ ("AuthMethodNone", 0)
          , ("AuthMethodYcaV1", 1)
          , ("AuthMethodAthens", 2)
        ]
    , ProtocolEnum "ProtocolVersion" [ ("v0", 0)
          , ("v1", 1)
          , ("v2", 2)
          , ("v3", 3)
          , ("v4", 4)
          , ("v5", 5)
          , ("v6", 6)
          , ("v7", 7)
          , ("v8", 8)
          , ("v9", 9)
          , ("v10", 10)
          , ("v11", 11)
          , ("v12", 12)
          , ("v13", 13)
          , ("v14", 14)
          , ("v15", 15)
        ]
    , ProtocolEnum "KeySharedMode" [ ("AUTO_SPLIT", 0)
          , ("STICKY", 1)
        ]
    , ProtocolEnum "TxnAction" [ ("COMMIT", 0)
          , ("ABORT", 1)
        ]
  ]

renderProtocol :: Text
renderProtocol = renderProtocolFrom protocolDeclarations

-- | Render an explicit declaration value using the shipped wire syntax.
renderProtocolFrom :: [ProtocolMessage] -> Text
renderProtocolFrom declarations = Text.unlines $
  ["syntax = \"proto2\";", "package pulsar.proto;", "option java_package = \"org.apache.pulsar.common.api.proto\";", "option optimize_for = LITE_RUNTIME;", ""]
  <> concatMap renderEnum protocolEnums <> concatMap renderMessage declarations
 where
  renderEnum e = ["enum " <> protocolEnumName e <> " {"]
    <> ["  " <> name <> " = " <> Text.pack (show number) <> ";" | (name, number) <- protocolEnumValues e]
    <> ["}", ""]
  renderMessage m = ["message " <> protocolMessageName m <> " {"]
    <> concatMap (map ("  " <>) . renderEnum) (protocolMessageEnums m)
    <> map renderField (protocolMessageFields m) <> ["}", ""]
  renderField f = "  " <> cardinality (protocolFieldCardinality f) <> " " <> protocolFieldType f <> " "
    <> protocolFieldName f <> " = " <> Text.pack (show (protocolFieldNumber f))
    <> maybe "" (\value -> " [default = " <> value <> "]") (protocolFieldDefault f) <> ";"
  cardinality Required = "required"
  cardinality Optional = "optional"
  cardinality Repeated = "repeated"
