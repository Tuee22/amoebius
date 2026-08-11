{-# LANGUAGE CPP #-}

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
#ifdef PHASE55_CANNED_RESPONSE_MUTANT
runSingleTenant _ request coordinated = SingleTenantResult "canned" <$> dispatchAuthorized request <*> pure coordinated
#else
runSingleTenant nonce request coordinated = SingleTenantResult nonce <$> dispatchAuthorized request <*> pure coordinated
#endif

networkEdgeAllowed :: NetworkEdge -> Bool
networkEdgeAllowed edge = case edge of
  BrowserEnvoy -> True
#ifdef PHASE55_DROP_NETWORKPOLICY_MUTANT
  BrowserUiDirect -> True
  BrowserProvider -> True
  UiBoundProvider -> True
  ForeignPodProvider -> True
#elif defined(PHASE55_OPEN_PROVIDER_EDGE_MUTANT)
  BrowserUiDirect -> False
  BrowserProvider -> True
  UiBoundProvider -> True
  ForeignPodProvider -> False
#else
  BrowserUiDirect -> False
  BrowserProvider -> False
  UiBoundProvider -> True
  ForeignPodProvider -> False
#endif
