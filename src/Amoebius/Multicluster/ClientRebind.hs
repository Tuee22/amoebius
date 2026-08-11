module Amoebius.Multicluster.ClientRebind
  ( EndpointState (..)
  , RebindPath (..)
  , chooseRebindPath
  ) where

data EndpointState = EndpointState
  { sourceServing :: Bool
  , sourceProxying :: Bool
  , targetServing :: Bool
  , dnsAtTarget :: Bool
  }
  deriving stock (Eq, Show)

data RebindPath
  = DirectSource
  | TransparentSourceProxy
  | DirectTarget
  | Redirect307
  | NoWorkingEndpoint
  deriving stock (Eq, Show)

chooseRebindPath :: EndpointState -> RebindPath
chooseRebindPath state
  | dnsAtTarget state && targetServing state = DirectTarget
  | sourceServing state = DirectSource
  | sourceProxying state && targetServing state = TransparentSourceProxy
  | targetServing state = Redirect307
  | otherwise = NoWorkingEndpoint
