

module Amoebius.Ui.Live.SingleTenant
  ( NetworkEdge (..)
  , SingleTenantResult (..)
  , runSingleTenant
  , networkEdgeAllowed
  ) where

import Amoebius.Ui.Realtime.RedisCoordination
import Amoebius.Ui.Server.Dispatch
import Amoebius.Ui.Server.Security

data NetworkEdge = BrowserEnvoy | BrowserUiDirect | BrowserProvider | UiBoundProvider | ForeignPodProvider
  deriving stock (Eq, Show)

data SingleTenantResult = SingleTenantResult String DispatchTrace CoordinationResult
  deriving stock (Eq, Show)

runSingleTenant :: String -> RequestContext -> CoordinationResult -> Either SecurityError SingleTenantResult
runSingleTenant nonce request coordinated = SingleTenantResult nonce <$> dispatchAuthorized request <*> pure coordinated

networkEdgeAllowed :: NetworkEdge -> Bool
networkEdgeAllowed edge = case edge of
  BrowserEnvoy -> True
  BrowserUiDirect -> False
  BrowserProvider -> False
  UiBoundProvider -> True
  ForeignPodProvider -> False
