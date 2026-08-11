{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import System.Exit (die)

data Evidence = Evidence Int Text Text Bootstrap [Cutover] Managed Handoff [Text] SecondPass Topology Provider Universal Cleanup
data Bootstrap = Bootstrap Text Int
data Cutover = Cutover Bool Bool Bool Bool
data Managed = Managed Text Bool Bool Bool Bool
data Handoff = Handoff Int Int [Transition]
data Transition = Transition Text (Maybe Text) (Maybe Int)
data SecondPass = SecondPass Int Int Int Int Int
data Topology = Topology Int Int Int Int (Maybe Text)
data Provider = Provider Text Text Text Text Text Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Cleanup = Cleanup Bool Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "scopedBoundary"
      <*> value .: "bootstrap" <*> value .: "cutover" <*> value .: "managed" <*> value .: "handoff"
      <*> value .: "services" <*> value .: "secondPass" <*> value .: "topology"
      <*> value .: "providerMaterialization" <*> value .: "universalLinuxCpu" <*> value .: "cleanup"

instance FromJSON Bootstrap where
  parseJSON = withObject "Bootstrap" $ \value -> Bootstrap <$> value .: "witness" <*> value .: "pods"

instance FromJSON Cutover where
  parseJSON = withObject "Cutover" $ \value ->
    Cutover <$> value .: "oldUidAbsent" <*> value .: "oldResourcesReleased" <*> value .: "reservationJoined" <*> value .: "boundReady"

instance FromJSON Managed where
  parseJSON = withObject "Managed" $ \value ->
    Managed <$> value .: "witness" <*> value .: "taint" <*> value .: "admission" <*> value .: "exclusiveBindingRbac" <*> value .: "writerDomainExact"

instance FromJSON Handoff where
  parseJSON = withObject "Handoff" $ \value ->
    Handoff <$> value .: "parentMutationsAfterRelease" <*> value .: "childMutationsBeforeAcquire" <*> value .: "sequence"

instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \value -> Transition <$> value .: "event" <*> value .:? "holder" <*> value .:? "readyReplicas"

instance FromJSON SecondPass where
  parseJSON = withObject "SecondPass" $ \value ->
    SecondPass <$> value .: "mutatingKubernetesCalls" <*> value .: "mutatingCloudCalls" <*> value .: "serviceCount" <*> value .: "deploymentCount" <*> value .: "reservationCount"

instance FromJSON Topology where
  parseJSON = withObject "Topology" $ \value ->
    Topology <$> value .: "singletonRoles" <*> value .: "capacitySchedulerRoles" <*> value .: "hostDaemonRoles" <*> value .: "hostNodePortPeers" <*> value .: "hostSubstrate"

instance FromJSON Provider where
  parseJSON = withObject "Provider" $ \value ->
    Provider <$> value .: "eksChild" <*> value .: "managedNode" <*> value .: "cloudLoadBalancer" <*> value .: "fullStandardServiceReachability" <*> value .: "fullStandardServiceHa" <*> value .: "wildIngressOnlyViaKeycloakOnProvider"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup <$> value .: "namespaceAbsent" <*> value .: "providerResources"

main :: IO ()
main = do
  bytes <- ByteString.readFile "../DEVELOPMENT_PLAN/evidence/phase_45/provider-child-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "provider-child-bringup-live: PASS (scoped Kubernetes child boundary; EKS convergence UNVERIFIED)"

verify :: Evidence -> IO ()
verify (Evidence register substrate boundary (Bootstrap bootstrap pods) cutover (Managed managed taint admission rbac writer) (Handoff parentAfter childBefore transitions) services (SecondPass kubeMut cloudMut serviceCount deployments reservations) (Topology singleton scheduler hostDaemons hostPeers hostSubstrate) (Provider eks node lb reachability ha ingress) (Universal universal (Pristine linux linuxCuda apple windows)) (Cleanup namespace providerResources)) = do
  assert (register == 3 && substrate == "linux-cpu") "register/substrate"
  assert (boundary == "retained kind Kubernetes API emulating ManagedEks child shape; not an EKS result") "scoped-boundary"
  assert (bootstrap == "BootstrapCapacitySchedulerReady" && pods == 1) "bootstrap"
  assert (length cutover == 4 && all completeCutover cutover) "cutover"
  assert (managed == "ManagedCapacityReady" && and [taint, admission, rbac, writer]) "managed"
  assert (parentAfter == 0 && childBefore == 0 && transitionEvents transitions == expectedTransitions) "handoff"
  assert (length services == 16 && serviceCount == 16) "services"
  assert (kubeMut == 0 && cloudMut == 0 && deployments == 2 && reservations == 4) "second-pass"
  assert (singleton == 1 && scheduler == 1 && hostDaemons == 0 && hostPeers == 0 && hostSubstrate == Nothing) "topology"
  assert (all (== "UNVERIFIED") [eks, node, lb, reachability, ha, ingress]) "provider-honesty"
  assert (universal && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  assert (namespace && providerResources == "none-created") "cleanup"
 where
  completeCutover (Cutover absent released joined bound) = and [absent, released, joined, bound]
  transitionEvents = map (\(Transition event _ _) -> event)
  expectedTransitions = ["parent-holder", "child-applied-non-serving", "fresh-holder-absence", "child-holder", "child-ready"]
  assert condition marker = unless condition (die marker)
