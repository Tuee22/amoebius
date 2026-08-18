{-# LANGUAGE CPP #-}

-- | Closed credential/action policy used before any provider invocation.
module Amoebius.Pulumi.Credential
  ( Principal (..)
  , CloudAction (..)
  , Decision (..)
  , Scope (..)
  , PolicyRow (..)
  , credentialMatrix
  , decide
  ) where

data Principal = Operational | CsiRuntime | ElevatedTest
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data CloudAction
  = CreateVolume
  | DeleteVolume
  | CreateCluster
  | DeleteCluster
  | DescribeVolumes
  | AttachVolume
  | DetachVolume
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Decision = Allow | Deny
  deriving stock (Eq, Ord, Show)

data Scope
  = AccountAndDeclaredZone
  | DurableRetained
  | PerRunCluster
  | AttachedCluster
  | DeclaredVolume
  | AllResources
  | TestOwnedOnly
  deriving stock (Eq, Ord, Show)

data PolicyRow = PolicyRow
  { policyPrincipal :: Principal
  , policyAction :: CloudAction
  , policyDecision :: Decision
  , policyScope :: Scope
  }
  deriving stock (Eq, Ord, Show)

decide :: Principal -> CloudAction -> PolicyRow
decide principal action =
  case (principal, action) of
    (Operational, CreateVolume) -> row Allow AccountAndDeclaredZone
#ifdef PROVIDER_EBS_CREDENTIAL_ALLOW_DELETE_MUTANT
    (Operational, DeleteVolume) -> row Allow AllResources
#else
    (Operational, DeleteVolume) -> row Deny DurableRetained
#endif
    (Operational, CreateCluster) -> row Allow PerRunCluster
    (Operational, DeleteCluster) -> row Allow PerRunCluster
    (CsiRuntime, DescribeVolumes) -> row Allow AttachedCluster
    (CsiRuntime, AttachVolume) -> row Allow DeclaredVolume
    (CsiRuntime, DetachVolume) -> row Allow DeclaredVolume
    (CsiRuntime, CreateVolume) -> row Deny AllResources
    (CsiRuntime, DeleteVolume) -> row Deny AllResources
    (ElevatedTest, DeleteVolume) -> row Allow TestOwnedOnly
    _ -> row Deny AllResources
 where
  row decision scope = PolicyRow principal action decision scope

credentialMatrix :: [PolicyRow]
credentialMatrix =
  [ decide Operational CreateVolume
  , decide Operational DeleteVolume
  , decide Operational CreateCluster
  , decide Operational DeleteCluster
  , decide CsiRuntime DescribeVolumes
  , decide CsiRuntime AttachVolume
  , decide CsiRuntime DetachVolume
  , decide CsiRuntime CreateVolume
  , decide CsiRuntime DeleteVolume
  , decide ElevatedTest DeleteVolume
  ]
