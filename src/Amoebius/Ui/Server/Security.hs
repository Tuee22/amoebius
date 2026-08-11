{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Server.Security
  ( Authority (..)
  , RequestContext (..)
  , SecurityError (..)
  , authorizeMutation
  ) where

import Data.Text (Text)

data Authority = Own | Foreign | Revoked | Unauthenticated
  deriving stock (Eq, Show)

data RequestContext = RequestContext
  { requestAuthority :: Authority
  , requestOrigin :: Text
  , expectedOrigin :: Text
  , requestCsrf :: Text
  , expectedCsrf :: Text
  , requestCallerTenantHeader :: Maybe Text
  , requestDirectHandler :: Bool
  }
  deriving stock (Eq, Show)

data SecurityError = Forbidden | Unavailable | BypassDenied | CallerAuthoredScopeForbidden
  deriving stock (Eq, Show)

authorizeMutation :: RequestContext -> Either SecurityError ()
authorizeMutation request
  | requestDirectHandler request = Left BypassDenied
  | requestCallerTenantHeader request /= Nothing = Left CallerAuthoredScopeForbidden
  | requestAuthority request `elem` [Foreign, Revoked, Unauthenticated] = Left Unavailable
  | requestOrigin request /= expectedOrigin request = Left Forbidden
#ifdef PHASE55_DISABLE_CSRF_MUTANT
  | otherwise = Right ()
#else
  | requestCsrf request /= expectedCsrf request = Left Forbidden
  | otherwise = Right ()
#endif
