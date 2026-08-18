module Amoebius.Pulsar.Internal.Types
  ( Broker (..)
  , NativeClient (..)
  , Topic (..)
  , Producer (..)
  , Consumer (..)
  , MessageId (..)
  , Received (..)
  , WireFrame (..)
  ) where

import Proto.PulsarApi (BaseCommand, MessageIdData, MessageMetadata)
import Control.Concurrent.MVar (MVar)
import Data.ByteString (ByteString)
import Data.IORef (IORef)
import Data.Text (Text)
import Data.Word (Word64)
import Network.Socket (Socket)

data Broker = Broker
  { brokerHost :: String
  , brokerPort :: String
  }
  deriving stock (Eq, Show)

data WireFrame = WireFrame
  { wireCommand :: BaseCommand
  , wireMetadata :: Maybe MessageMetadata
  , wirePayload :: Maybe ByteString
  }

data NativeClient = NativeClient
  { nativeSocket :: Socket
  , nativeRequestCounter :: IORef Word64
  , nativeEntityCounter :: IORef Word64
  , nativePendingFrames :: IORef [WireFrame]
  , nativeSendLock :: MVar ()
  }

newtype Topic = Topic Text
  deriving stock (Eq, Ord, Show)

data Producer = Producer
  { producerClient :: NativeClient
  , producerId :: Word64
  , producerName :: Text
  , producerNextSequence :: IORef Word64
  }

data Consumer a = Consumer
  { consumerClient :: NativeClient
  , consumerId :: Word64
  }

data MessageId = MessageId
  { messageLedgerId :: Word64
  , messageEntryId :: Word64
  , messagePartition :: Int
  , messageBatchIndex :: Int
  , messageProto :: MessageIdData
  }

instance Eq MessageId where
  left == right =
    (messageLedgerId left, messageEntryId left, messagePartition left, messageBatchIndex left)
      == (messageLedgerId right, messageEntryId right, messagePartition right, messageBatchIndex right)

instance Show MessageId where
  show value =
    show (messageLedgerId value)
      <> ":" <> show (messageEntryId value)
      <> ":" <> show (messagePartition value)
      <> ":" <> show (messageBatchIndex value)

data Received a = Received
  { receivedMessageId :: MessageId
  , receivedRedeliveryCount :: Int
  , receivedKey :: Maybe Text
  , receivedValue :: a
  }
  deriving stock (Eq, Show)
