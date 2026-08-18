module Amoebius.Pulsar.Connection
  ( Broker (..)
  , NativeClient
  , withNativeClient
  , lookupTopic
  ) where

import Amoebius.Pulsar.Internal.Protocol
  ( awaitFrame
  , commandLookup
  , connectHandshake
  , freshRequestId
  , isType
  , sendCommand
  )
import Amoebius.Pulsar.Internal.Types (Broker (..), NativeClient (..), Topic)
import Proto.PulsarApi (BaseCommand'Type (..))
import Control.Concurrent.MVar (newMVar)
import Control.Exception (bracket)
import Data.IORef (newIORef)
import Network.Socket qualified as Socket

withNativeClient :: Broker -> (NativeClient -> IO a) -> IO a
withNativeClient broker = bracket (open broker) close
  where
    open target = do
      addresses <- Socket.getAddrInfo (Just Socket.defaultHints {Socket.addrSocketType = Socket.Stream}) (Just (brokerHost target)) (Just (brokerPort target))
      address <- case addresses of
        [] -> ioError (userError "pulsar-broker-address-not-found")
        firstAddress : _ -> pure firstAddress
      socket <- Socket.socket (Socket.addrFamily address) (Socket.addrSocketType address) (Socket.addrProtocol address)
      Socket.connect socket (Socket.addrAddress address)
      client <- NativeClient socket <$> newIORef 1 <*> newIORef 1 <*> newIORef [] <*> newMVar ()
      connectHandshake client
      pure client
    close = Socket.close . nativeSocket

lookupTopic :: NativeClient -> Topic -> IO ()
lookupTopic client topic = do
  requestId <- freshRequestId client
  sendCommand client (commandLookup requestId topic)
  _ <- awaitFrame client (isType BaseCommand'LOOKUP_RESPONSE)
  pure ()
