{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostComms.NodePort
  ( HostService (..)
  , HostCommsSpec (..)
  , ProvisionedHostComms
  , HostCommsError (..)
  , provisionHostComms
  , provisionedServices
  , provisionedBindAddress
  , renderServiceType
  ) where

import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

data HostService = ContentMutationGateway | Pulsar
  deriving stock (Eq, Ord, Show)

data HostCommsSpec = HostCommsSpec
  { hostServiceType :: Text
  , hostBindAddress :: Text
  , hostEnvoyRoute :: Bool
  , hostDaemonWildIngress :: Bool
  , hostRawMinioNodePort :: Bool
  , hostServices :: Set HostService
  }
  deriving stock (Eq, Show)

data ProvisionedHostComms = ProvisionedHostComms (Set HostService) Text
  deriving stock (Eq, Show)

data HostCommsError
  = NodePortRequired
  | LoopbackRequired
  | EnvoyRouteForbidden
  | DaemonWildIngressForbidden
  | RawMinioMutationEndpointForbidden
  | HostServiceInventoryMismatch
  deriving stock (Eq, Show)

renderServiceType :: Text
#ifdef PHASE53_LB_NODEPORT_MUTANT
renderServiceType = "LoadBalancer"
#else
renderServiceType = "NodePort"
#endif

provisionHostComms :: HostCommsSpec -> Either HostCommsError ProvisionedHostComms
provisionHostComms spec
  | hostServiceType spec /= renderServiceType = Left NodePortRequired
  | renderServiceType /= "NodePort" = Left NodePortRequired
  | hostBindAddress spec /= "127.0.0.1" = Left LoopbackRequired
  | hostEnvoyRoute spec = Left EnvoyRouteForbidden
  | hostDaemonWildIngress spec = Left DaemonWildIngressForbidden
  | hostRawMinioNodePort spec = Left RawMinioMutationEndpointForbidden
  | hostServices spec /= Set.fromList [ContentMutationGateway, Pulsar] = Left HostServiceInventoryMismatch
  | otherwise = Right (ProvisionedHostComms (hostServices spec) (hostBindAddress spec))

provisionedServices :: ProvisionedHostComms -> Set HostService
provisionedServices (ProvisionedHostComms services _) = services

provisionedBindAddress :: ProvisionedHostComms -> Text
provisionedBindAddress (ProvisionedHostComms _ address) = address
