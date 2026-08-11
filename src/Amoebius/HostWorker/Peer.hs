{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostWorker.Peer
  ( PeerSpec (..)
  , ProvisionedPeer
  , PeerError (..)
  , provisionPeer
  , renderGeneratedGateDhall
  ) where

import Amoebius.HostComms.NodePort
import Amoebius.HostWorker.Auth (ResolvedWorkerAuth)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word16)

data PeerSpec = PeerSpec
  { peerPulsarPort :: Word16
  , peerGatewayPort :: Word16
  , peerNativePulsar :: Bool
  , peerWebSocket :: Bool
  , peerMtls :: Bool
  , peerBespokeRpc :: Bool
  , peerRawMinioMutation :: Bool
  }
  deriving stock (Eq, Show)

data ProvisionedPeer = ProvisionedPeer Word16 Word16
  deriving stock (Eq, Show)

data PeerError
  = NativePulsarRequired
  | WebSocketForbidden
  | MtlsForbidden
  | BespokeRpcForbidden
  | RawMinioMutationForbidden
  | MissingLoopbackService
  | InvalidPeerPort
  deriving stock (Eq, Show)

provisionPeer :: ProvisionedHostComms -> ResolvedWorkerAuth -> PeerSpec -> Either PeerError ProvisionedPeer
provisionPeer comms _ spec
  | not (peerNativePulsar spec) = Left NativePulsarRequired
  | peerWebSocket spec = Left WebSocketForbidden
  | peerMtls spec = Left MtlsForbidden
  | peerBespokeRpc spec = Left BespokeRpcForbidden
  | peerRawMinioMutation spec = Left RawMinioMutationForbidden
  | peerPulsarPort spec == 0 || peerGatewayPort spec == 0 = Left InvalidPeerPort
  | ContentMutationGateway `notElem` provisionedServices comms || Pulsar `notElem` provisionedServices comms = Left MissingLoopbackService
  | otherwise = Right (ProvisionedPeer (peerPulsarPort spec) (peerGatewayPort spec))

renderGeneratedGateDhall :: ProvisionedPeer -> Text
renderGeneratedGateDhall (ProvisionedPeer pulsar gateway) = Text.unlines
  [ "{ bindAddress = \"127.0.0.1\""
  , ", pulsarProtocol = \"native-tcp\""
  , ", pulsarPort = " <> Text.pack (show pulsar)
  , ", contentMutationGatewayPort = " <> Text.pack (show gateway)
  , ", mTLS = False"
  , ", bespokeRPC = False"
  , ", rawMinioMutation = False"
  , "}"
  ]
