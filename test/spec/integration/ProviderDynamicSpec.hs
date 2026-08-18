{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import System.Exit (die)

data Evidence = Evidence Int Text Text (Vector Cycle) Sweep Provider Deferred Universal Cleanup
data Cycle = Cycle Text Int Int Int Int Int Text Join
data Join = Join Int Text Text Bool Bool Text Bool
data Sweep = Sweep Text (Vector Text) (Vector Text) Int (Vector Text)
data Provider = Provider Text Text Text Text Text Text Text Text
data Deferred = Deferred Text Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Cleanup = Cleanup Bool Bool Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "scopedBoundary"
      <*> value .: "signalCycles" <*> value .: "runOwnedSweep" <*> value .: "providerMaterialization"
      <*> value .: "deferred" <*> value .: "universalLinuxCpu" <*> value .: "cleanup"

instance FromJSON Cycle where
  parseJSON = withObject "Cycle" $ \value ->
    Cycle <$> value .: "signalClass" <*> value .: "declaredTargetEdits" <*> value .: "nodesBefore"
      <*> value .: "nodesWhileActive" <*> value .: "nodesAfterRecede" <*> value .: "stablePassKubernetesMutations"
      <*> value .: "unreachableOutcome" <*> value .: "joined"

instance FromJSON Join where
  parseJSON = withObject "Join" $ \value ->
    Join <$> value .: "ordinal" <*> value .: "providerInstanceIdentity" <*> value .: "signalClass"
      <*> value .: "quarantinedBeforeAdmission" <*> value .: "supplyLayoutDevicesComplete"
      <*> value .: "schedulerGeneration" <*> value .: "authorityComplete"

instance FromJSON Sweep where
  parseJSON = withObject "Sweep" $ \value ->
    Sweep <$> value .: "boundary" <*> value .: "runOwnedEphemeralIds" <*> value .: "tagOnlyEphemeralIds"
      <*> value .: "untaggedOrphansCaught" <*> value .: "permittedDurableIds"

instance FromJSON Provider where
  parseJSON = withObject "Provider" $ \value ->
    Provider <$> value .: "eksCluster" <*> value .: "realManagedNode" <*> value .: "signalCorrelatedRunInstances"
      <*> value .: "cloudNoOpAudit" <*> value .: "awsRunOwnedDescribeSweep" <*> value .: "ephemeralProviderLeakFreedom"
      <*> value .: "durableEbsSoleSurvivor" <*> value .: "secondFullProviderCycle"

instance FromJSON Deferred where
  parseJSON = withObject "Deferred" $ \value -> Deferred <$> value .: "elevatedDurableEbsReclamation" <*> value .: "spotCostSignal"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup <$> value .: "phase47NamespaceAbsent" <*> value .: "auditNamespaceAbsent" <*> value .: "providerResources"

main :: IO ()
main = do
  bytes <- ByteString.readFile "DEVELOPMENT_PLAN/evidence/phase_47/provider-dynamic-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "provider-dynamic-nodes-live: PASS (scoped reconcile/sweep analogue; AWS node/leak sweep UNVERIFIED)"

verify :: Evidence -> IO ()
verify (Evidence register substrate boundary cycles sweep provider deferred universal cleanup) = do
  assert (register == 3 && substrate == "linux-cpu") "register/substrate"
  assert (boundary == "retained kind ConfigMap reconcile and ownership-sweep analogue; not an AWS node or leak-free provider result") "scoped-boundary"
  assert (Vector.map cycleClass cycles == Vector.fromList ["workflow-completion", "load"] && Vector.all validCycle cycles) "signal-cycles"
  case sweep of
    Sweep sweepBoundary runOwned tagOnly caught durable ->
      assert (sweepBoundary == "Kubernetes metadata ownership analogue; not AWS Describe evidence" && runOwned == Vector.fromList ["elb-untagged", "eni-tagged", "log-untagged"] && tagOnly == Vector.fromList ["eni-tagged"] && caught == 2 && durable == Vector.fromList ["volume-durable"]) "run-owned-sweep"
  case provider of
    Provider eks node signal audit sweepResult leaks durable secondCycle ->
      assert (all (== "UNVERIFIED") [eks, node, signal, audit, sweepResult, leaks, durable, secondCycle]) "provider-honesty"
  case deferred of
    Deferred reclamation spot -> assert (reclamation == "UNVERIFIED until Phase 54" && spot == "UNVERIFIED") "deferred"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) ->
      assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  case cleanup of
    Cleanup system auditNamespace resources -> assert (system && auditNamespace && resources == "none-created") "cleanup"
 where
  cycleClass (Cycle signalClass _ _ _ _ _ _ _) = signalClass
  validCycle (Cycle signalClass edits before active after stable unreachable (Join ordinal identity joinedSignal quarantined supply generation authority)) =
    edits == 0 && before == 1 && active == 2 && after == 1 && stable == 0 && unreachable == "RefuseOnUnreachable"
      && ordinal == 1 && identity == "account-fp/amoebius-p47/cpu-balanced/1" && joinedSignal == signalClass
      && quarantined && supply && generation == "generation-47" && authority
  assert condition label = unless condition (die label)
