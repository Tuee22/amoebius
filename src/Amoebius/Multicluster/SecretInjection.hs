module Amoebius.Multicluster.SecretInjection
  ( InjectionVault
  , SecretInjectionError (..)
  , emptyInjectionVault
  , injectSecret
  , resolveInjectedSecret
  ) where

import Amoebius.Vault.SecretRef (SecretRef)
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

newtype InjectionVault = InjectionVault (Map SecretRef ByteString)

data SecretInjectionError
  = SecretAlreadyInjected
  | InjectedSecretMissing
  deriving stock (Eq, Show)

emptyInjectionVault :: InjectionVault
emptyInjectionVault = InjectionVault Map.empty

injectSecret
  :: SecretRef
  -> ByteString
  -> InjectionVault
  -> Either SecretInjectionError InjectionVault
injectSecret reference value (InjectionVault values)
  | Map.member reference values = Left SecretAlreadyInjected
  | otherwise = Right (InjectionVault (Map.insert reference value values))

resolveInjectedSecret
  :: SecretRef
  -> InjectionVault
  -> Either SecretInjectionError ByteString
resolveInjectedSecret reference (InjectionVault values) =
  maybe (Left InjectedSecretMissing) Right (Map.lookup reference values)
