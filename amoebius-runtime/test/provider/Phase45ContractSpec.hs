{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Cluster.ProviderBringUp
import Amoebius.ControlPlane.AuthorityHandoff
import Amoebius.Daemon.InClusterSingleton
import Amoebius.Scheduler.Readiness
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text (Text)
import System.Exit (die)

main :: IO ()
main = do
  validateTopology
  managed <- validateBootstrap
  held <- validateHandoff managed
  converged <- validateServices held
  validateNoOp converged
  putStrLn "provider-child-bringup-contract: PASS (bootstrap, hostless topology, handoff, convergence, no-op)"

validateTopology :: IO ()
validateTopology = do
  let hostless = DaemonTopologyObservation 1 1 0 0 Nothing
  _ <- right (observeHostlessProviderTopology ManagedEks hostless)
  equal (Left NoHostSubstrateOnManagedEks) (requireHostSubstrate ManagedEks) "NoHostSubstrateOnManagedEks"
  equal (Right "linux-cpu") (requireHostSubstrate (SelfManaged "linux-cpu")) "self-managed-host-positive"
  equal (Left HostDaemonPresentOnManagedEks) (observeHostlessProviderTopology ManagedEks hostless {observedHostDaemonRoles = 1}) "host-daemon-foreclosure"

validateBootstrap :: IO ManagedProviderChild
validateBootstrap = do
  let plan = ProviderChildPlan pinnedImage 1 addOns
      controllers = map controller (Set.toList addOns)
      exactAuthority = ManagedAuthorityReadback True True True True True
  equal (Left PublicRegistryImageForbidden) (validateProviderImageSource "docker.io/amoebius/base:latest") "mut-45.1-public-pull"
  equal (Left MutableImageReferenceForbidden) (validateProviderImageSource "registry.amoebius.invalid:5000/amoebius/base:latest") "mutable-image"
  equal (Left DefaultSchedulerExceptionCardinality) (bringUpManagedCapacity plan {providerDefaultSchedulerExceptions = 2} scheduler controllers exactAuthority) "DefaultSchedulerExceptionCardinality"
  equal (Left (BootstrapAddonMissing (Set.singleton "ebs-csi-controller"))) (bringUpManagedCapacity plan scheduler (filter ((/= "ebs-csi-controller") . bootstrapControllerName) controllers) exactAuthority) "BootstrapAddonMissing"
  let oldPresent = replace "coredns" (controller "coredns") {bootstrapOldUidAbsent = False} controllers
  equal (Left (BootstrapOldUidPresent "coredns")) (bringUpManagedCapacity plan scheduler oldPresent exactAuthority) "BootstrapOldUidPresent"
  let reservationMissing = replace "aws-node" (controller "aws-node") {bootstrapReplacementReservationJoined = False} controllers
  equal (Left (BootstrapReplacementReservationMissing "aws-node")) (bringUpManagedCapacity plan scheduler reservationMissing exactAuthority) "BootstrapReplacementReservationMissing"
  right (bringUpManagedCapacity plan scheduler controllers exactAuthority)

validateHandoff :: ManagedProviderChild -> IO ChildLeaseHeld
validateHandoff managed = do
  let parent = lease "40" (Just "parent-bootstrap")
      released = lease "41" Nothing
      acquired = lease "42" (Just "child-singleton-pod-uid")
  held <- right (handoffProviderLease managed "parent-bootstrap" "child-singleton-pod-uid" parent released acquired)
  case handoffProviderLease managed "parent-bootstrap" "child-singleton-pod-uid" parent (lease "40" Nothing) acquired of
    Left (ProviderLeaseHandoffError (HandoffResourceVersionStale "40")) -> pure ()
    value -> die ("HandoffResourceVersionStale:" <> show value)
  case handoffProviderLease managed "parent-bootstrap" "child-singleton-pod-uid" parent (released {handoffLeaseUid = "changed"}) acquired of
    Left (ProviderLeaseHandoffError (HandoffObjectUidChanged "lease-uid" "changed")) -> pure ()
    value -> die ("HandoffObjectUidChanged:" <> show value)
  pure held

validateServices :: ChildLeaseHeld -> IO ConvergedProviderChild
validateServices held = do
  case convergeStandardServices held (Set.delete "keycloak" standardServiceSet) of
    Left (StandardServiceSetMismatch _ observed) -> unless (not (Set.member "keycloak" observed)) (die "service-set-negative")
    Left problem -> die ("service-set-wrong-negative:" <> show problem)
    Right _ -> die "service-set-negative"
  right (convergeStandardServices held standardServiceSet)

validateNoOp :: ConvergedProviderChild -> IO ()
validateNoOp converged = do
  equal (Right ()) (observeNoOpRerun converged (MutationAudit [] [])) "no-op"
  equal (Left (SecondPassMutatingCall "create deployment")) (observeNoOpRerun converged (MutationAudit ["create deployment"] [])) "second-pass-mutation"

pinnedImage :: String
pinnedImage = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"

addOns :: Set.Set Text
addOns = Set.fromList ["coredns", "aws-node", "kube-proxy", "ebs-csi-controller"]

scheduler :: BootstrapSchedulerObservation
scheduler = BootstrapSchedulerObservation "generation-1" "generation-1" "sha256:config" "sha256:config" "root-17" "root-17" True True True True

controller :: Text -> BootstrapControllerObservation
controller name = BootstrapControllerObservation name True True (name <> "-replacement") True True True

replace :: Text -> BootstrapControllerObservation -> [BootstrapControllerObservation] -> [BootstrapControllerObservation]
replace name replacement = map (\value -> if bootstrapControllerName value == name then replacement else value)

lease :: Text -> Maybe Text -> LeaseSnapshot
lease resourceVersion holder = LeaseSnapshot "amoebius-control-plane" "lease-uid" resourceVersion holder

right :: Show problem => Either problem value -> IO value
right = either (die . show) pure

equal :: (Eq value, Show value) => value -> value -> String -> IO ()
equal expected actual marker = unless (expected == actual) (die (marker <> ": expected " <> show expected <> ", got " <> show actual))
