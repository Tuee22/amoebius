{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Cluster.ProviderBringUp
  ( ProviderChildPlan (..)
  , ProviderBringUpError (..)
  , ManagedProviderChild
  , bringUpManagedCapacity
  , ChildLeaseHeld
  , handoffProviderLease
  , ConvergedProviderChild
  , convergeStandardServices
  , standardServiceSet
  , MutationAudit (..)
  , observeNoOpRerun
  , validateProviderImageSource
  ) where

import Amoebius.ControlPlane.AuthorityHandoff
import Amoebius.Scheduler.Readiness
import Data.List (isPrefixOf)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

data ProviderChildPlan = ProviderChildPlan
  { providerSchedulerImage :: String
  , providerDefaultSchedulerExceptions :: Int
  , providerExpectedAddOns :: Set Text
  }
  deriving stock (Eq, Show)

data ProviderBringUpError
  = PublicRegistryImageForbidden
  | MutableImageReferenceForbidden
  | DefaultSchedulerExceptionCardinality
  | ProviderBootstrapReadinessError BootstrapReadinessError
  | BootstrapAddonMissing (Set Text)
  | BootstrapAddonUnexpected (Set Text)
  | BootstrapOldUidPresent Text
  | BootstrapOldResourcesNotReleased Text
  | BootstrapReplacementReservationMissing Text
  | BootstrapReplacementNotBoundReady Text
  | ManagedAuthorityMismatch
  | ProviderLeaseHandoffError HandoffError
  | StandardServiceSetMismatch (Set Text) (Set Text)
  | SecondPassMutatingCall Text
  deriving stock (Eq, Show)

data ManagedProviderChild = ManagedProviderChild ProviderChildPlan ManagedCapacityReady
  deriving stock (Eq, Show)

validateProviderImageSource :: String -> Either ProviderBringUpError ()
#ifdef PROVIDER_CHILD_BRINGUP_PUBLIC_PULL_MUTANT
validateProviderImageSource _ = Right ()
#else
validateProviderImageSource image
  | not ("registry.amoebius.invalid:5000/amoebius/" `isPrefixOf` image) = Left PublicRegistryImageForbidden
  | not ("@sha256:" `contains` image) = Left MutableImageReferenceForbidden
  | otherwise = Right ()
 where
  contains needle haystack = any (needle `isPrefixOf`) (tails haystack)
  tails [] = [[]]
  tails value@(_ : rest) = value : tails rest
#endif

bringUpManagedCapacity
  :: ProviderChildPlan
  -> BootstrapSchedulerObservation
  -> [BootstrapControllerObservation]
  -> ManagedAuthorityReadback
  -> Either ProviderBringUpError ManagedProviderChild
bringUpManagedCapacity plan scheduler controllers authority = do
  validateProviderImageSource (providerSchedulerImage plan)
  if providerDefaultSchedulerExceptions plan == 1
    then pure ()
    else Left DefaultSchedulerExceptionCardinality
  bootstrap <- either (Left . ProviderBootstrapReadinessError) Right (observeBootstrapCapacitySchedulerReady scheduler)
  managed <- case observeManagedCapacityReady bootstrap (providerExpectedAddOns plan) controllers authority of
    Right value -> Right value
    Left (BootstrapControllerDomainMismatch expected observed)
      | not (Set.null (expected Set.\\ observed)) -> Left (BootstrapAddonMissing (expected Set.\\ observed))
      | otherwise -> Left (BootstrapAddonUnexpected (observed Set.\\ expected))
    Left (BootstrapControllerNotReleased name) ->
      case findController name controllers of
        Just row
          | not (bootstrapOldUidAbsent row) -> Left (BootstrapOldUidPresent name)
          | otherwise -> Left (BootstrapOldResourcesNotReleased name)
        Nothing -> Left (BootstrapAddonMissing (Set.singleton name))
    Left (BootstrapReplacementNotJoinedReady name) ->
      case findController name controllers of
        Just row
          | not (bootstrapReplacementReservationJoined row) -> Left (BootstrapReplacementReservationMissing name)
          | otherwise -> Left (BootstrapReplacementNotBoundReady name)
        Nothing -> Left (BootstrapAddonMissing (Set.singleton name))
    Left ManagedAuthorityReadbackMismatch -> Left ManagedAuthorityMismatch
  pure (ManagedProviderChild plan managed)
 where
  findController name = go
   where
    go [] = Nothing
    go (row : rest)
      | bootstrapControllerName row == name = Just row
      | otherwise = go rest

data ChildLeaseHeld = ChildLeaseHeld ManagedProviderChild ControlPlaneDaemonLease
  deriving stock (Eq, Show)

handoffProviderLease
  :: ManagedProviderChild
  -> Text
  -> Text
  -> LeaseSnapshot
  -> LeaseSnapshot
  -> LeaseSnapshot
  -> Either ProviderBringUpError ChildLeaseHeld
handoffProviderLease managed parentHolder childPodUid parent released acquired = do
  parentLease <- handoff (observeBootstrap parentHolder parent)
  releasedLease <- handoff (releaseForHandoff parentLease released)
  controlPlaneLease <- handoff (acquireControlPlaneDaemon childPodUid releasedLease acquired)
  pure (ChildLeaseHeld managed controlPlaneLease)
 where
  handoff = either (Left . ProviderLeaseHandoffError) Right

newtype ConvergedProviderChild = ConvergedProviderChild ChildLeaseHeld
  deriving stock (Eq, Show)

standardServiceSet :: Set Text
standardServiceSet = Set.fromList
  [ "registry", "minio", "vault", "zookeeper", "bookkeeper", "pulsar"
  , "redis", "sentinel", "prometheus", "grafana", "postgres", "pgadmin"
  , "envoy", "gateway-api", "keycloak", "cloud-load-balancer"
  ]

convergeStandardServices
  :: ChildLeaseHeld
  -> Set Text
  -> Either ProviderBringUpError ConvergedProviderChild
convergeStandardServices held observed
  | observed == standardServiceSet = Right (ConvergedProviderChild held)
  | otherwise = Left (StandardServiceSetMismatch standardServiceSet observed)

data MutationAudit = MutationAudit
  { mutatingKubernetesCalls :: [Text]
  , mutatingCloudCalls :: [Text]
  }
  deriving stock (Eq, Show)

observeNoOpRerun :: ConvergedProviderChild -> MutationAudit -> Either ProviderBringUpError ()
observeNoOpRerun _ audit = case mutatingKubernetesCalls audit <> mutatingCloudCalls audit of
  [] -> Right ()
  call : _ -> Left (SecondPassMutatingCall call)
