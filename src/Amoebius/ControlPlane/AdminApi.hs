{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Typed reach and live SecretRef capability admission for admin REST.
module Amoebius.ControlPlane.AdminApi
  ( EndpointFamily (..)
  , ReachClass (..)
  , AdminDecision (..)
  , PasswordDisposition (..)
  , passwordDisposition
  , authorizeReach
  , SecretCapabilityProbe (..)
  , AdmissionError (..)
  , admissionErrorTag
  , proveSecretCapability
  , admitDhallUpdate
  ) where

import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON (..), withObject, (.:))
import Data.Text (Text)
import GHC.Generics (Generic)

data EndpointFamily = VaultInit | VaultUnseal | DhallUpdate | KvCrud
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ReachClass = NodeLocal | AuthenticatedFabric | Lan | WildIngress
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data AdminDecision = Admit | Refuse Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PasswordDisposition = TransportOnly | PersistToFilesystem
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

passwordDisposition :: PasswordDisposition
#ifdef PHASE33_PERSIST_PASSWORD_MUTANT
passwordDisposition = PersistToFilesystem
#else
passwordDisposition = TransportOnly
#endif

authorizeReach :: EndpointFamily -> ReachClass -> AdminDecision
#ifdef PHASE33_REACH_ANY_MUTANT
authorizeReach _ _ = Admit
#else
authorizeReach endpoint reach = case (endpoint, reach) of
  (VaultInit, NodeLocal) -> Admit
  (VaultUnseal, NodeLocal) -> Admit
  (VaultInit, _) -> Refuse "admin-reach-seal-critical-node-local-required"
  (VaultUnseal, _) -> Refuse "admin-reach-seal-critical-node-local-required"
  (DhallUpdate, NodeLocal) -> Admit
  (DhallUpdate, AuthenticatedFabric) -> Admit
  (KvCrud, NodeLocal) -> Admit
  (KvCrud, AuthenticatedFabric) -> Admit
  (DhallUpdate, _) -> Refuse "admin-reach-trusted-required"
  (KvCrud, _) -> Refuse "admin-reach-trusted-required"
#endif

data SecretCapabilityProbe = SecretCapabilityProbe
  { capabilityName :: Text
  , capabilitySecretExists :: Bool
  , capabilitySshConnects :: Bool
  , capabilityObservedResourcesSatisfy :: Bool
  , capabilityCloudPermissionAndQuota :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

instance FromJSON SecretCapabilityProbe where
  parseJSON = withObject "SecretCapabilityProbe" $ \value ->
    SecretCapabilityProbe
      <$> value .: "name"
      <*> value .: "secretExists"
      <*> value .: "sshConnects"
      <*> value .: "observedResourcesSatisfy"
      <*> value .: "cloudPermissionAndQuota"

data AdmissionError
  = SecretRefAbsent Text
  | SecretSshUnreachable Text
  | SecretHostResourceMismatch Text
  | SecretCloudPermissionOrQuotaDenied Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

admissionErrorTag :: AdmissionError -> Text
admissionErrorTag problem = case problem of
  SecretRefAbsent _ -> "secret-ref-absent"
  SecretSshUnreachable _ -> "secret-ssh-unreachable"
  SecretHostResourceMismatch _ -> "secret-host-resource-mismatch"
  SecretCloudPermissionOrQuotaDenied _ -> "secret-cloud-permission-or-quota-denied"

proveSecretCapability :: SecretCapabilityProbe -> Either AdmissionError SecretCapabilityProbe
proveSecretCapability probe
  | not (capabilitySecretExists probe) = Left (SecretRefAbsent (capabilityName probe))
  | not (capabilitySshConnects probe) = Left (SecretSshUnreachable (capabilityName probe))
  | not (capabilityObservedResourcesSatisfy probe) = Left (SecretHostResourceMismatch (capabilityName probe))
  | not (capabilityCloudPermissionAndQuota probe) = Left (SecretCloudPermissionOrQuotaDenied (capabilityName probe))
  | otherwise = Right probe

admitDhallUpdate :: [SecretCapabilityProbe] -> Either AdmissionError [SecretCapabilityProbe]
#ifdef PHASE33_ADMIT_UNPROVEN_SECRET_MUTANT
admitDhallUpdate = Right
#else
admitDhallUpdate = traverse proveSecretCapability
#endif
