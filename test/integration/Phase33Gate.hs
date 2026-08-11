{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.ControlPlane.AdminApi
import Amoebius.ControlPlane.AuthorityHandoff
import Amoebius.ControlPlane.Deploy
import Amoebius.ControlPlane.Reconcile
import Amoebius.ControlPlane.Singleton
import Amoebius.Platform.Types (ResourceEnvelope (..))
import Control.Monad (forM_, unless)
import Data.Aeson (FromJSON, eitherDecodeFileStrict', withObject, (.:))
import Data.Aeson qualified as Aeson
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import System.Exit (die)
import System.FilePath ((</>))

data ExpectedEnact = ExpectedEnact
  { schema :: Text
  , objects :: [Text]
  }
  deriving stock (Generic, Show)

instance FromJSON ExpectedEnact

data CapabilityFixture = CapabilityFixture
  { fixtureName :: Text
  , fixtureSecretExists :: Bool
  , fixtureSshConnects :: Bool
  , fixtureObservedResourcesSatisfy :: Bool
  , fixtureCloudPermissionAndQuota :: Bool
  }
  deriving stock (Show)

instance FromJSON CapabilityFixture where
  parseJSON = withObject "CapabilityFixture" $ \value ->
    CapabilityFixture
      <$> value .: "name"
      <*> value .: "secretExists"
      <*> value .: "sshConnects"
      <*> value .: "observedResourcesSatisfy"
      <*> value .: "cloudPermissionAndQuota"

main :: IO ()
main = do
  checkSingleton
  checkHandoff
  checkDeployAndReconcile
  checkAdminReach
  checkAdminAdmission
  checkNegativeOracle
  putStrLn "phase33-gate-spec: PASS (singleton seal, Lease handoff, reconcile, admin reach/admission, pinned oracles)"

checkSingleton :: IO ()
checkSingleton = do
  let valid = singletonManifest
  assertRight "singleton exact manifest" (validateSingletonManifest valid)
  assertLeft "replicas" SingletonReplicaCardinalityInvalid (validateSingletonManifest valid {singletonReplicas = 2})
  assertLeft "rollout" SingletonRolloutMustBeRecreate (validateSingletonManifest valid {singletonRolloutPolicy = RollingUpdate})
  assertLeft "PVC" SingletonMustBeStateless (validateSingletonManifest valid {singletonPersistentVolumeClaims = ["state"]})
  assertLeft "standby" SingletonStandbyForbidden (validateSingletonManifest valid {singletonStandbyReplicas = 1})
  assertLeft "election" SingletonElectionForbidden (validateSingletonManifest valid {singletonHasElectionController = True})
  assertLeft "image" SingletonImageUnpinned (validateSingletonManifest valid {singletonImage = "mutable:latest"})
  assertEqual "daemon spine" [Loaded, PrerequisitesReady, LeaseAcquired "pod-a", Serving "pod-a", Draining "pod-a", Exited] (daemonSpine "pod-a")
  assertBool "ready only after acquire" (singletonReady (Serving "pod-a") && not (singletonReady PrerequisitesReady))
  assertEqual "singleton writer" "amoebius-phase33-singleton" singletonFieldManager
  let state = controlPlaneState
  assertRight "control-plane state exact" (provisionControlPlaneState state)
  forM_ [minBound .. maxBound] $ \kind ->
    assertLeft ("state kind " <> show kind) ControlPlaneStateKindsIncomplete
      (provisionControlPlaneState state {stateKinds = Set.delete kind (stateKinds state)})
  assertLeft "state admission" ControlPlaneStateAdmissionMissing
    (provisionControlPlaneState state {stateHasMutationAdmissionGateway = False})

checkHandoff :: IO ()
checkHandoff = do
  bootstrap <- requireRight (observeBootstrap "phase26-bootstrap-host" (snapshot "10" (Just "phase26-bootstrap-host")))
  released <- requireRight (releaseForHandoff bootstrap (snapshot "11" Nothing))
  held <- requireRight (acquireSingleton "pod-uid-a" released (snapshot "12" (Just "pod-uid-a")))
  assertEqual "singleton holder" (Just "pod-uid-a") (handoffHolderIdentity (singletonLeaseSnapshot held))
  assertLeft "stale release" (HandoffResourceVersionStale "10")
    (releaseForHandoff bootstrap (snapshot "10" Nothing))
  assertLeft "release still held" (HandoffReleaseNotObserved (Just "phase26-bootstrap-host"))
    (releaseForHandoff bootstrap (snapshot "11" (Just "phase26-bootstrap-host")))
  assertLeft "wrong pod" (HandoffSingletonHolderMismatch "pod-uid-a" (Just "pod-uid-b"))
    (acquireSingleton "pod-uid-a" released (snapshot "12" (Just "pod-uid-b")))
  let changed = (snapshot "11" Nothing) {handoffLeaseUid = "other-uid"}
  assertLeft "object replacement" (HandoffObjectUidChanged "lease-uid" "other-uid")
    (releaseForHandoff bootstrap changed)

checkDeployAndReconcile :: IO ()
checkDeployAndReconcile = do
  expected1 <- loadExpected "test/fixtures/phase33/expected-enact-pass1.json"
  expected2 <- loadExpected "test/fixtures/phase33/expected-enact-pass2.json"
  assertEqual "pass1 schema" "amoebius.phase33.expected-enact.v1" (schema expected1)
  assertEqual "pass2 oracle empty" [] (objects expected2)
  let desired = Set.fromList (fmap ObjectIdentity (objects expected1))
      demand = deployDemand desired
  sealed <- requireRight (provisionDeploy demand)
  assertEqual "opaque render equality" desired (renderProvisionedDeploy sealed)
  forM_ [minBound .. maxBound] $ \envelope ->
    assertLeft ("envelope " <> show envelope) DeployEnvelopeOmitted
      (provisionDeploy demand {deployEnvelopes = Set.delete envelope (deployEnvelopes demand)})
  forM_ [minBound .. maxBound] $ \producer ->
    assertLeft ("producer " <> show producer) DeployProducerArmOmitted
      (provisionDeploy demand {deployProducerArms = Set.delete producer (deployProducerArms demand)})
  let first = enactPlan desired Set.empty
  assertEqual "pass1 exact enact" (Set.toAscList desired) (plannedEnactments first)
  let (observed, records) = executePlan Set.empty first
  assertBool "all records singleton-attributed" (not (null records) && all ((== singletonFieldManager) . enactedFieldManager) records)
  assertEqual "pass2 empty enact" [] (plannedEnactments (enactPlan desired observed))
  assertBool "re-observed convergence" (converged desired observed)

checkAdminReach :: IO ()
checkAdminReach = do
  rows <- tsvRows "test/golden/admin/reach-matrix.tsv"
  assertEqual "reach matrix cardinality" 16 (length rows)
  forM_ rows $ \row -> case row of
    [endpointRaw, reachRaw, decisionRaw, tag] -> do
      endpoint <- parseEndpoint endpointRaw
      reach <- parseReach reachRaw
      let actual = authorizeReach endpoint reach
          expected = if decisionRaw == "admit" then Admit else Refuse tag
      assertEqual ("reach " <> Text.unpack endpointRaw <> "/" <> Text.unpack reachRaw) expected actual
    _ -> die "malformed admin reach oracle"
  assertEqual "password transport only" TransportOnly passwordDisposition

checkAdminAdmission :: IO ()
checkAdminAdmission = do
  rows <- tsvRows "test/golden/admin/admission-tags.tsv"
  assertEqual "admission corpus cardinality" 4 (length rows)
  forM_ rows $ \row -> case row of
    [_cause, expectedTag, negativePath, positivePath] -> do
      negative <- loadCapability negativePath
      positive <- loadCapability positivePath
      case admitDhallUpdate [toProbe negative] of
        Left problem -> assertEqual ("negative tag " <> Text.unpack negativePath) expectedTag (admissionErrorTag problem)
        Right _ -> die ("negative capability admitted: " <> Text.unpack negativePath)
      assertRight ("positive capability " <> Text.unpack positivePath) (admitDhallUpdate [toProbe positive])
    _ -> die "malformed admin admission oracle"

checkNegativeOracle :: IO ()
checkNegativeOracle = do
  rows <- tsvRows "test/fixtures/phase33/negative-expected-tags.tsv"
  assertEqual "Phase-6 live-path oracle cardinality" 26 (length rows)
  forM_ rows $ \row -> case row of
    [fixture, gate, tag, positive] -> do
      assertBool "negative fixture named" ("dhall/examples/illegal_" `Text.isPrefixOf` fixture)
      assertBool "positive pair named" ("dhall/examples/" `Text.isPrefixOf` positive)
      assertBool "gate named" (gate == "Gate-1" || gate == "Gate-2")
      assertBool "specific tag nonempty" (not (Text.null tag))
    _ -> die "malformed Phase-33 negative oracle"

singletonManifest :: SingletonManifest
singletonManifest = SingletonManifest
  { singletonKind = "Deployment"
  , singletonReplicas = 1
  , singletonRolloutPolicy = Recreate
  , singletonPersistentVolumeClaims = []
  , singletonStandbyReplicas = 0
  , singletonHasElectionController = False
  , singletonImage = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
  , singletonResources = ResourceEnvelope 25 500 67108864 268435456 16777216 268435456
  }

controlPlaneState :: ControlPlaneStateDemand
controlPlaneState = ControlPlaneStateDemand
  { stateStorageBudgetId = "control-plane-state"
  , stateKinds = Set.fromList [minBound .. maxBound]
  , stateMaximumCanonicalBytes = 1048576
  , stateRetainedVersions = 4
  , stateMaximumConcurrentWrites = 1
  , stateMaximumFailedWriteSets = 4
  , stateOrphanGcHorizonSeconds = 3600
  , stateHasMutationAdmissionGateway = True
  }

deployDemand :: Set ObjectIdentity -> DeployDemand
deployDemand desired = DeployDemand
  { deployDhallPath = "dhall/examples/platform_plus_trivial_app.dhall"
  , deployTargetAuthenticated = True
  , deployCapacityFits = True
  , deployEnvelopes = Set.fromList [minBound .. maxBound]
  , deployProducerArms = Set.fromList [minBound .. maxBound]
  , deployStateKinds = Set.fromList [minBound .. maxBound]
  , deployDesiredObjects = desired
  }

snapshot :: Text -> Maybe Text -> LeaseSnapshot
snapshot resourceVersion holder = LeaseSnapshot "amoebius-reconciler" "lease-uid" resourceVersion holder

loadExpected :: FilePath -> IO ExpectedEnact
loadExpected path = eitherDecodeFileStrict' path >>= either die pure

loadCapability :: Text -> IO CapabilityFixture
loadCapability name = do
  let path = "test/fixtures/admin/secrets-capability" </> Text.unpack name
  decoded <- Aeson.eitherDecodeFileStrict' path
  either die pure decoded

toProbe :: CapabilityFixture -> SecretCapabilityProbe
toProbe fixture = SecretCapabilityProbe
  (fixtureName fixture)
  (fixtureSecretExists fixture)
  (fixtureSshConnects fixture)
  (fixtureObservedResourcesSatisfy fixture)
  (fixtureCloudPermissionAndQuota fixture)

parseEndpoint :: Text -> IO EndpointFamily
parseEndpoint raw = case raw of
  "vault-init" -> pure VaultInit
  "vault-unseal" -> pure VaultUnseal
  "dhall-update" -> pure DhallUpdate
  "kv-crud" -> pure KvCrud
  _ -> die ("unknown endpoint family: " <> Text.unpack raw)

parseReach :: Text -> IO ReachClass
parseReach raw = case raw of
  "NodeLocal" -> pure NodeLocal
  "AuthenticatedFabric" -> pure AuthenticatedFabric
  "Lan" -> pure Lan
  "WildIngress" -> pure WildIngress
  _ -> die ("unknown reach: " <> Text.unpack raw)

tsvRows :: FilePath -> IO [[Text]]
tsvRows path = do
  contents <- TextIO.readFile path
  pure [Text.splitOn "\t" row | row <- drop 1 (Text.lines contents), not (Text.null row)]

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertRight :: Show problem => String -> Either problem value -> IO ()
assertRight label result = case result of
  Left problem -> die (label <> ": " <> show problem)
  Right _ -> pure ()

assertLeft :: (Eq problem, Show problem, Show value) => String -> problem -> Either problem value -> IO ()
assertLeft label expected result = case result of
  Left actual -> assertEqual label expected actual
  Right value -> die (label <> ": unexpectedly accepted " <> show value)

assertBool :: String -> Bool -> IO ()
assertBool label condition = unless condition (die label)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
