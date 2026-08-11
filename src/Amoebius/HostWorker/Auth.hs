{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostWorker.Auth
  ( WorkerSecretNames (..)
  , ResolvedWorkerAuth
  , AuthError (..)
  , resolveWorkerAuth
  , authUsesEnvironment
  , authHasRawMinioMutationCredential
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

data WorkerSecretNames = WorkerSecretNames
  { pulsarSecretName :: Text
  , contentGatewaySecretName :: Text
  , rawMinioMutationSecretName :: Maybe Text
  }
  deriving stock (Eq, Show)

data ResolvedWorkerAuth = ResolvedWorkerAuth Text Text
  deriving stock (Eq, Show)

data AuthError = EmptySecretName | RawMinioMutationCredentialForbidden | SecretNotFound Text
  deriving stock (Eq, Show)

resolveWorkerAuth :: Map Text Text -> WorkerSecretNames -> Either AuthError ResolvedWorkerAuth
resolveWorkerAuth vault names
  | rawMinioMutationSecretName names /= Nothing = Left RawMinioMutationCredentialForbidden
  | pulsarSecretName names == "" || contentGatewaySecretName names == "" = Left EmptySecretName
  | otherwise = ResolvedWorkerAuth
      <$> resolve (pulsarSecretName names)
      <*> resolve (contentGatewaySecretName names)
 where
  resolve name = maybe (Left (SecretNotFound name)) Right (Map.lookup name vault)

authUsesEnvironment :: ResolvedWorkerAuth -> Bool
authUsesEnvironment _ = False

authHasRawMinioMutationCredential :: ResolvedWorkerAuth -> Bool
authHasRawMinioMutationCredential _ = False
