{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.RenderSource
import Amoebius.Execution.Normalize
import Amoebius.Execution.Observe
import Amoebius.Execution.RuntimeStorage
import Amoebius.Execution.SerialOnDelete
import Amoebius.Execution.AcceleratorRelease
import Amoebius.Execution.HostTransition
import Amoebius.Execution.JobTerminal
import Amoebius.Manifest.Actions
import Amoebius.Manifest.Apply
import Amoebius.Manifest.Authority
import Amoebius.Manifest.Diff
import Amoebius.Manifest.Delete
import Amoebius.Manifest.Enact
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.Preflight
import Amoebius.Manifest.Reconcile
import Amoebius.Manifest.Wait
import Amoebius.Storage.ScalingAction
import Data.Aeson (FromJSON, eitherDecodeFileStrict')
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import System.Exit (die)

data CorpusRow = CorpusRow {identity :: Text}
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON)

data Corpus = Corpus {objects :: [CorpusRow]}
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON)

data ExpectedActions = ExpectedActions {actions :: [Text]}
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON)

main :: IO ()
main = do
  verifyExpectedActions
  verifyDesiredIndex
  verifyExecutionObservation
  verifyCapacityPreflight
  verifySingleUseAuthority
  verifyScopedSsaAndDispatch
  verifyRuntimeStorage
  verifyStorageScalingToken
  verifySerialStages
  verifyHostRelease
  verifyJobTerminal
  verifyDeleteAuthority
  verifyReadiness
  putStrLn "phase26-reconcile-spec: PASS (Sprint 26.1 desired/indexed/observed/preflight/action boundary)"

verifyExpectedActions :: IO ()
verifyExpectedActions = do
  corpus <- decode "test/live/fixtures/reconcile-corpus/corpus.json"
  expected <- decode "test/live/fixtures/reconcile-corpus/expected-actions.json"
  let actual = fmap (renderAction . planInitialIdentity . K8sObjectIdentity . identity) (objects corpus)
  assertEqual "independent initial action domain" (actions expected) actual

verifyDesiredIndex :: IO ()
verifyDesiredIndex = do
  let first = object "ConfigMap/ns/config" ConfigMapKind Immediate
      second = object "Deployment/ns/work" DeploymentKind Immediate
      stages = Map.fromList [(objectIdentity first, Immediate), (objectIdentity second, Immediate)]
      digests = Map.fromList [(objectIdentity first, "sha256:first"), (objectIdentity second, "sha256:second")]
  desired <- either (die . show) pure (validateAndIndexRenderedObjects stages digests [first, second])
  assertEqual "desired domain" (Map.keysSet stages) (Map.keysSet desired)
  assertEqual
    "duplicate identity"
    (Left (DuplicateRenderedIdentity (objectIdentity first)))
    (validateAndIndexRenderedObjects stages digests [first, first, second])
  let changed = second {objectActivation = AfterManagedCapacityReady}
  assertEqual
    "activation mismatch"
    (Left (RenderedActivationMismatch (objectIdentity second) Immediate AfterManagedCapacityReady))
    (validateAndIndexRenderedObjects stages digests [first, changed])
  let observed =
        Map.fromList
          [ (objectIdentity first, ObservedObject (objectIdentity first) "1" "sha256:first" "phase26" "g1" False)
          , (objectIdentity second, ObservedObject (objectIdentity second) "2" "sha256:second" "phase26" "g1" False)
          ]
  planned <- either (die . show) pure (planObjectActions True "g1" desired observed)
  assertEqual "stable no-op" [NoOp, NoOp] (fmap actionKind planned)
  let later = second {objectActivation = AfterManagedCapacityReady}
      laterStages = Map.singleton (objectIdentity later) AfterManagedCapacityReady
      laterDigests = Map.singleton (objectIdentity later) "sha256:later"
  laterDesired <- either (die . show) pure (validateAndIndexRenderedObjects laterStages laterDigests [later])
  case planObjectActions False "g1" laterDesired Map.empty of
    Left (GenericSsaStageNotEligible _ AfterManagedCapacityReady) -> pure ()
    verdict -> die ("later stage gained generic SSA authority: " <> show verdict)

verifyExecutionObservation :: IO ()
verifyExecutionObservation = do
  let pod = KubernetesPod (PodUid "uid-1")
      row = ObservedExecution pod "source" "revision" ["ReplicaSet/rs", "Deployment/work"] True True
      observed = Map.singleton pod row
  authenticated <- either (die . show) pure (authenticateObservedExecutions observed)
  let commitments = Map.singleton pod (ExecutionCommitment 100 1024 2048)
  assertEqual
    "normalized once"
    (Right (ExecutionCommitment 100 1024 2048))
    (normalizeExecutionCommitments authenticated commitments)
  let wrong = Map.singleton pod (row {observedExecutionIdentity = HostReservation (HostReservationId "fake")})
  case authenticateObservedExecutions wrong of
    Left (ExecutionMapKeyMismatch _ _) -> pure ()
    verdict -> die ("execution identity mismatch survived: " <> show verdict)

verifyCapacityPreflight :: IO ()
verifyCapacityPreflight = do
  let residual = LiveResourceVector 1000 4096 8192 10 2048
      demand = LiveResourceVector 1000 4096 8192 10 2048
      snapshot = ObservedLiveResourceSnapshot "fresh" residual Set.empty (Just "bootstrap-host") (Just "7")
      action = validatedAction NoOp (K8sObjectIdentity "ConfigMap/ns/config")
  target <- either (die . show) pure (validateLiveTarget "fresh" "bootstrap-host" demand snapshot [action])
  assertEqual "validated action" [action] (validatedTargetActions target)
  let under = snapshot {observedLiveResidual = residual {liveMemoryBytes = 4095}}
  assertEqual ("memory one-short" :: String) (Left (LiveMemoryExceeded 4096 4095)) (validateLiveTarget "fresh" "bootstrap-host" demand under [action])
  let unknown = snapshot {observedLiveUnknownCommitments = Set.singleton "foreign-pod"}
  assertEqual ("unknown commitment" :: String) (Left (UnknownCommitment (Set.singleton "foreign-pod"))) (validateLiveTarget "fresh" "bootstrap-host" demand unknown [action])

verifySingleUseAuthority :: IO ()
verifySingleUseAuthority = do
  planned <- planLeaseAction "Lease/ns/reconciler" "bootstrap-host" (LeaseAbsent "Lease/ns/reconciler")
  token <- either (die . show) pure planned
  first <- consumeLeaseActionToken token
  case first of
    Right (BootstrapAcquire "Lease/ns/reconciler" "bootstrap-host") -> pure ()
    verdict -> die ("lease acquire shape: " <> show verdict)
  assertEqual "lease token reuse" (Left LeaseTokenAlreadyConsumed) =<< consumeLeaseActionToken token
  assertEqual "renewal rounding" (4 :: Int) (renewalAttemptsWithinWindow 10 3)
  denied <- planLeaseAction "Lease/ns/reconciler" "bootstrap-host" (LeasePresent "Lease/ns/reconciler" "foreign" "uid" "9")
  case denied of
    Left (LeaseHolderMismatch "bootstrap-host" "foreign") -> pure ()
    _ -> die "foreign holder received a Lease mutation token"

verifyScopedSsaAndDispatch :: IO ()
verifyScopedSsaAndDispatch = do
  let identity = K8sObjectIdentity "ConfigMap/ns/config"
      applyAction = validatedAction ApplyDesiredObject identity
      noOpAction = validatedAction NoOp identity
      deleteAction = validatedAction DeleteOwnedObject identity
      fields = Map.singleton "data.owned" "v1"
  assertEqual "SSA field manager" (Right (SsaPatch "amoebius" fields)) (prepareScopedSsa applyAction fields)
  assertEqual "no-op has no SSA" (Left (ActionCannotUseGenericSsa NoOp)) (prepareScopedSsa noOpAction fields)
  assertEqual "delete has no SSA" (Left (ActionCannotUseGenericSsa DeleteOwnedObject)) (prepareScopedSsa deleteAction fields)
  assertEqual "no-op dispatch" NoEffect (dispatchSurface noOpAction)
  assertEqual "delete dispatch" AuthenticatedDeleteEffect (dispatchSurface deleteAction)
  assertEqual "ordinary dispatch" ServerSideApplyEffect (dispatchSurface applyAction)

verifyRuntimeStorage :: IO ()
verifyRuntimeStorage = do
  let components =
        [ RuntimeStorageComponent KubeletNodefs "unified" 100
        , RuntimeStorageComponent CriRuntimeRoot "unified" 200
        , RuntimeStorageComponent ImageContentRoot "image" 300
        ]
  assertEqual
    "physical backing grouping"
    (Right (Map.fromList [("image", 300), ("unified", 300)]))
    (groupRuntimeStorageByBacking components)

verifyStorageScalingToken :: IO ()
verifyStorageScalingToken = do
  action <- mintStorageScalingAction CreateRetainedCapacity "fresh"
  assertEqual "stale storage token" False =<< consumeStorageScalingAction "stale" action
  assertEqual "fresh storage token" True =<< consumeStorageScalingAction "fresh" action
  assertEqual "storage token reuse" False =<< consumeStorageScalingAction "fresh" action

verifySerialStages :: IO ()
verifySerialStages = do
  let first = SerialObservation "f1" "f1" "slot-1" (Just "old-uid") False Nothing False False
  assertEqual "serial delete one" (Right (DeleteOnePredecessor "slot-1" "old-uid")) (planSerialAction DeletePredecessor first)
  let absent = first {serialPredecessorAbsent = True}
  assertEqual "serial resume after absence" (Right (ResumeController "slot-1")) (planSerialAction ObserveRelease absent)
  let replacement = absent {serialReplacementUid = Just "new-uid", serialReplacementBound = True, serialReplacementReady = True}
  assertEqual "serial advance after bound ready" (Right (AdvanceAfterReplacement "slot-1" "new-uid")) (planSerialAction ObserveReplacement replacement)
  let sameUid = replacement {serialReplacementUid = Just "old-uid"}
  assertEqual "replacement UID distinct" (Left SerialReplacementNotDistinct) (planSerialAction ObserveReplacement sameUid)
  let notReady = replacement {serialReplacementReady = False}
  assertEqual "serial advance before replacement Bound+Ready" (Left SerialReplacementNotBoundReady) (planSerialAction ObserveReplacement notReady)
  let stale = first {serialObservedFingerprint = "stale"}
  assertEqual "serial stale fingerprint" (Left SerialSnapshotChanged) (planSerialAction DeletePredecessor stale)

verifyHostRelease :: IO ()
verifyHostRelease = do
  let ordinary = OrdinaryAfterExit "old" (OrdinaryRelease True)
      cuda = CudaAfterDeviceRelease "old" (CudaRelease True True 4096 4096)
      metal = MetalAfterDrain "old" (MetalRelease True True True "cache" "cache")
  assertEqual "ordinary host release" (Right ()) (authorizeHostStart "f" "f" ordinary)
  assertEqual "CUDA host release" (Right ()) (authorizeHostStart "f" "f" cuda)
  assertEqual "Metal host release" (Right ()) (authorizeHostStart "f" "f" metal)
  assertEqual "stale host release" (Left HostSnapshotChanged) (authorizeHostStart "f" "stale" cuda)
  let held = CudaAfterDeviceRelease "old" (CudaRelease True False 4096 4096)
  assertEqual "CUDA hold remains" (Left (HostReleaseInvalid DeviceHoldStillPresent)) (authorizeHostStart "f" "f" held)

verifyJobTerminal :: IO ()
verifyJobTerminal = do
  let live = TerminalJobObservation "pod-uid" JobSucceeded "digest" "revision" False Nothing False False
  assertEqual "pre-gateway terminal retention" (Right (RetainTerminalAwaitingGateway "pod-uid")) (planJobTerminal live)
  let gateway = live {terminalGatewayAvailable = True}
  assertEqual "completion persist" (Right (PersistJobCompletion JobSucceeded "digest" "revision")) (planJobTerminal gateway)
  let readback = gateway {terminalCompletionReadback = Just (JobSucceeded, "digest", "revision")}
  assertEqual "completion no-op before deadline" (Right (CompletedTerminalNoOp "pod-uid")) (planJobTerminal readback)
  let cleanup = readback {terminalCleanupDeadlineReached = True, terminalReleaseComplete = True}
  assertEqual "completion cleanup" (Right (CleanupPersistedTerminal "pod-uid")) (planJobTerminal cleanup)
  let wrong = readback {terminalCompletionReadback = Just (JobFailedBackoffExhausted, "digest", "revision")}
  assertEqual "completion readback mismatch" (Left CompletionReadbackMismatch) (planJobTerminal wrong)

verifyDeleteAuthority :: IO ()
verifyDeleteAuthority = do
  let candidate = DeleteCandidate "ConfigMap/ns/old" "owner" "generation" "7" False True
      authority = DeleteAuthority "ConfigMap/ns/old" "owner" "generation" "7"
  assertEqual "authenticated delete" (Right candidate) (authorizeDelete authority candidate)
  assertEqual "changed resourceVersion" (Left DeleteAuthorityMismatch) (authorizeDelete (authority {deleteAuthorityResourceVersion = "6"}) candidate)
  assertEqual "retained object" (Left DeleteRetainedObject) (authorizeDelete authority (candidate {deleteCandidateRetained = True}))
  assertEqual "active dependency" (Left DeleteDependencyActive) (authorizeDelete authority (candidate {deleteCandidateDependenciesReleased = False}))

verifyReadiness :: IO ()
verifyReadiness = do
  let ready = ReadinessObservation True 1000 4000 3
  assertEqual "non-instantaneous readiness" (Right ()) (observeReady ready)
  assertEqual "never-ready red path" (Left ConvergenceTimeout) (observeReady (ready {readinessAvailable = False}))
  assertEqual "too-early readiness" (Left ReadinessReportedBeforeInitialDelay) (observeReady (ready {readinessObservedMillis = 3999}))
  let provisioned = ChildEnvelope 100 65536 65536 16384 1 1
      exact = provisioned
      over = exact {childCpuMillis = 101}
  assertEqual "child exact fit" (Right ()) (validateChildEnvelope provisioned exact)
  assertEqual "healthy CR over-bound child" (Left (ChildEnvelopeExceeded provisioned over)) (validateChildEnvelope provisioned over)
  let namespace = ControllerEnvelopeNamespace "amoebius-phase26-owner-a"
      ownerA = ControllerEnvelopeOwner "owner-a"
      ownerB = ControllerEnvelopeOwner "owner-b"
  assertEqual
    "two owners cannot share one ControllerEnvelopeNamespace"
    (Left (ControllerEnvelopeNamespaceShared namespace ownerA ownerB))
    (claimControllerEnvelopeNamespaces [(ownerA, namespace), (ownerB, namespace)])

object :: Text -> K8sObjectKind -> RenderActivation -> K8sObject
object raw kind activation =
  K8sObject
    { objectIdentity = K8sObjectIdentity raw
    , objectApiVersion = "v1"
    , objectKind = kind
    , objectMetadata = ObjectMetadata raw Nothing Map.empty Map.empty
    , objectSpec = GlobalControlSpec Map.empty
    , objectActivation = activation
    , objectReconcileMode = ServerSideApply
    }

decode :: FromJSON value => FilePath -> IO value
decode path = eitherDecodeFileStrict' path >>= either die pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
