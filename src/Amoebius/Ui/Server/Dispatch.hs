{-# LANGUAGE CPP #-}

module Amoebius.Ui.Server.Dispatch
  ( DispatchTrace (..)
  , dispatchAuthorized
  ) where

import Amoebius.Ui.Server.Security

data DispatchTrace = DispatchTrace
  { handlerEffects :: Int
  , providerEffects :: Int
  , artifactDispatches :: Int
  }
  deriving stock (Eq, Show)

dispatchAuthorized :: RequestContext -> Either SecurityError DispatchTrace
#ifdef PHASE55_DISPATCH_BEFORE_AUTH_MUTANT
dispatchAuthorized _ = Right (DispatchTrace 1 1 1)
#else
dispatchAuthorized request = do
  authorizeMutation request
  Right (DispatchTrace 1 1 1)
#endif
