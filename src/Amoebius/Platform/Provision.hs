{-# LANGUAGE OverloadedStrings #-}

-- | Whole-backbone execution admission. Each component retains its canonical
-- resource envelope, bounded local storage, and controller lifecycle. The
-- transfer and metadata jobs have finite concurrency and retention; the
-- filesystem source stays reserved through the verified routing transition.
module Amoebius.Platform.Provision
  ( ProvisionedPlatformService, ProvisionedBackboneServices
  , provisionBackboneServices, backboneServicesProjection
  , backboneServicesPeak, backboneServiceResources
  , backboneService, platformServiceScratchBytes, platformServiceK8sResources, platformServiceProjection
  , MinioExecutionProfile, standardMinioExecutionProfile
  , minioMaximumObjectBytes, minioMaximumRequests, minioManagedHeapBytes, minioMemoryCeilingBytes
  , ObjectProducerDeclaration (..), backboneObjectProducers, bindObjectProducerWriters
  , ZkMemberExecutor (..), ZkMemberClaim (..), ZkMemberBacking (..), ZkMemberDemand (..)
  , ProvisionedZkMembers, provisionZkMembers, zkMemberProjection, zkMemberOrdinals
  , zkMemberK8sResources, zkMemberRawClaim
  , zkMemberIdentityProjection
  , backboneZooKeeperExecution
  ) where

import Amoebius.Capacity.Execution
import Amoebius.Capacity.Types
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
  ( DeclaredVolumeDemand (..), StatefulSetClaimSlot (..), VolumeGeometry (..)
  , UniformClaimWitness (..), provisionVolume, uniformStatefulSetClaims )
import Amoebius.Capacity.ZooKeeper
import Amoebius.Capacity.ObjectStore
  ( SourceKind (..), SourceScope (..), ObjectWriterAdmission, writerAdmissionSource
  , writerAdmissionScope, writerAdmissionOwner, writerAdmissionBudget, writerAdmissionKind )
import Amoebius.Platform.Types qualified as Legacy
import Control.Monad (unless)
import Data.Aeson (Value, object, toJSON, (.=))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data ProvisionedPlatformService = ProvisionedPlatformService Text ResourceEnvelope ControllerBody Natural Natural Natural
  deriving stock (Eq, Show)
data ProvisionedBackboneServices = ProvisionedBackboneServices (Map Text ProvisionedPlatformService) ProvisionedExecutionEpochs [(Natural, ProvisionedExecutionEpochs, ProvisionedPlatformService)]
  deriving stock (Eq, Show)

-- One row per actually expanded executor. Several executors can share one
-- logical producer/budget, but their instance identities remain distinct.
data ObjectProducerDeclaration = ObjectProducerDeclaration
  { producerInstance :: Text, producerSource :: Text, producerOwner :: Text
  , producerBudget :: BudgetId, producerScope :: SourceScope, producerKind :: SourceKind }
  deriving stock (Eq, Show)

backboneObjectProducers :: ProvisionedBackboneServices -> [ObjectProducerDeclaration]
backboneObjectProducers (ProvisionedBackboneServices _ epochs _) =
  [ObjectProducerDeclaration (executionInstanceId instance') source owner (BudgetId source)
    (SourceScope "root-minio" "platform" bucket) kind
  | instance' <- Map.elems (provisionedDesiredSteady epochs)
  , (source,owner,bucket,kind) <- role (executionInstanceSource instance')]
 where
  role name
    | name `elem` ["platform-system/registry","platform-system/registry-transfer","platform-system/registry-transfer-mismatch"] =
        [("registry","registry","registry",RegistryObjects)]
    | name == "pulsar-system/broker" = [("pulsar-offload","pulsar","pulsar-offload",PulsarOffloadObjects)]
    | name == "platform-system/object-gateway" = [("application-canary","phase30-application","phase30-canary",ApplicationObjects)]
    | otherwise = []

bindObjectProducerWriters :: [ObjectProducerDeclaration] -> Map Text ObjectWriterAdmission -> Either Text ()
bindObjectProducerWriters producers writers = do
  unless (length producers == Set.size (Set.fromList (fmap producerInstance producers)))
    (Left "backbone-duplicate-object-producer-instance")
  unless (Set.fromList (fmap producerSource producers) == Map.keysSet writers)
    (Left "backbone-object-producer-source-set-mismatch")
  mapM_ (\producer -> case Map.lookup (producerSource producer) writers of
    Nothing -> Left "backbone-object-producer-writer-missing"
    Just writer -> unless (writerAdmissionSource writer == producerSource producer
      && writerAdmissionOwner writer == producerOwner producer
      && writerAdmissionBudget writer == producerBudget producer
      && writerAdmissionScope writer == producerScope producer
      && writerAdmissionKind writer == producerKind producer)
        (Left "backbone-object-producer-owner-budget-scope-mismatch")) producers

-- The member budgets are partitions already reserved by execution admission.
-- They cannot borrow a surplus from another metadata member or service.
data ZkMemberExecutor = ZkMemberExecutor MaterializedExecutionInstance Text
  deriving stock (Eq, Show)
data ZkMemberClaim = ZkMemberClaim
  { memberClaimOrdinal :: Natural, memberClaimNamespace :: Text, memberClaimController :: Text
  , memberClaimTemplate :: Text, memberClaimIdentity :: Text, memberClaimBacking :: BackingId
  , memberClaimUsableBytes :: Natural, memberClaimRawBytes :: Natural }
  deriving stock (Eq, Show)
data ZkMemberBacking = ZkMemberBacking
  { memberBackingIdentity :: BackingId, memberBackingParent :: BackingId, memberBackingBytes :: Natural }
  deriving stock (Eq, Show)
data ZkMemberDemand = ZkMemberDemand
  { memberController :: BoundExecutionUnit, memberExecutors :: [ZkMemberExecutor]
  , memberSupplies :: [(Natural, ResourceVector)], memberClaims :: [ZkMemberClaim]
  , memberBackings :: [ZkMemberBacking], memberParent :: StorageBacking
  , memberGenerations :: ZkGenerationPolicy, memberPresentation :: FilesystemPresentation
  , memberAllocation :: BackingAllocationPolicy }
  deriving stock (Eq, Show)
data ProvisionedZkMembers = ProvisionedZkMembers ZkMemberDemand ProvisionedZkGenerations
  ProvisionedExecutionEpochs UniformClaimWitness Natural
  deriving stock (Eq, Show)

backboneZooKeeperExecution :: ProvisionedBackboneServices -> Either Text (BoundExecutionUnit, [ZkMemberExecutor])
backboneZooKeeperExecution (ProvisionedBackboneServices services epochs _) = do
  ProvisionedPlatformService identity envelope controller _ _ _ <- maybe
    (Left "zookeeper-execution-service-absent") Right (Map.lookup "pulsar-system/zookeeper" services)
  let rows = [ZkMemberExecutor instance' ("zookeeper-" <> showText (executionInstanceOrdinal instance'))
        | instance' <- Map.elems (provisionedDesiredSteady epochs), executionInstanceSource instance' == identity]
  pure (BoundExecutionUnit identity 1 envelope controller, rows)

provisionZkMembers :: ZkMemberDemand -> Either Text ProvisionedZkMembers
provisionZkMembers demand = do
  generations <- firstShow (provisionZkGenerations (memberGenerations demand))
  let ordinals = zkMembers (memberGenerations demand)
      count = fromIntegral (length ordinals)
      unit = memberController demand
      reserved = addResources (envelopeRequests (executionResource unit)) (envelopeHeadroom (executionResource unit))
      total = foldl' addResources zeroResources (replicate (length ordinals) reserved)
      expectedOrdinals = Set.fromList ordinals
      claims = memberClaims demand
      backings = memberBackings demand
      actualInstances = [row | ZkMemberExecutor row _ <- memberExecutors demand]
  check (ordinals == [0..count-1] && executionUnitId unit == "pulsar-system/zookeeper"
    && executionBody unit == StatefulSetBody count StatefulSetOnDelete) "controller-topology"
  check (resourcePodSlots reserved >= 1) "pod-reservation-absent"
  check (roundAllocation (BackingAllocationPolicy 4096 4096) (zkPaddedLogBytes 16 16 (zkPreallocationKiB*1024))
    <= zkMaximumLogExtent (memberGenerations demand)) "initial-log-extent-unfunded"
  expanded <- firstShow (provisionExecutionEpochs Map.empty total (BoundExecutionInventory FirstDeployment [unit]))
  let actual = Map.fromList [(executionInstanceId row,row) | row <- actualInstances]
  check (length actualInstances == Map.size actual && actual == provisionedDesiredSteady expanded) "executor-domain-identity"
  mapM_ (\(ZkMemberExecutor row pod) -> check (pod == "zookeeper-" <> showText (executionInstanceOrdinal row)) "executor-pod")
    (memberExecutors demand)
  let supplies = Map.fromList (memberSupplies demand)
  check (length (memberSupplies demand) == Map.size supplies && Map.keysSet supplies == expectedOrdinals) "supply-domain"
  mapM_ (\(ordinal, available) -> mapM_ (\(axis,get) -> check (get reserved <= get available)
    ("member-" <> showText ordinal <> "-" <> axis)) resourceAxes) (Map.toList supplies)
  check (length claims == length ordinals && Set.fromList (fmap memberClaimOrdinal claims) == expectedOrdinals) "claim-domain"
  check (length claims == Set.size (Set.fromList (fmap memberClaimIdentity claims))
    && length claims == Set.size (Set.fromList (fmap memberClaimBacking claims))) "claim-or-backing-alias"
  let backingMap = Map.fromList [(memberBackingIdentity backing,backing) | backing <- backings]
  check (length backings == Map.size backingMap && Map.keysSet backingMap == Set.fromList (fmap memberClaimBacking claims)) "backing-domain"
  mapM_ (\claim -> do
    let ordinal = memberClaimOrdinal claim
        peak = Map.findWithDefault 0 ordinal (zkGenerationSlotPeaks generations)
    check ((memberClaimNamespace claim, memberClaimController claim, memberClaimTemplate claim,
      memberClaimIdentity claim, memberClaimBacking claim) == ("pulsar-system", "zookeeper", "data",
      "data-zookeeper-" <> showText ordinal, BackingId ("phase30-zookeeper-" <> showText ordinal))) "claim-owner-template"
    check (memberClaimUsableBytes claim >= peak) ("member-" <> showText ordinal <> "-claim-usable")) claims
  mapM_ (\backing -> check (memberBackingParent backing == backingId (memberParent demand)) "backing-parent") backings
  volumes <- traverse (\claim -> do
    backing <- maybe (Left "zookeeper-member-backing-absent") Right (Map.lookup (memberClaimBacking claim) backingMap)
    firstShow (provisionVolume (DeclaredVolumeDemand (memberClaimIdentity claim)
      (StatefulSetClaimSlot (memberClaimController claim) (memberClaimTemplate claim) (memberClaimOrdinal claim))
      (StorageBacking (memberBackingIdentity backing) (memberBackingBytes backing) (memberAllocation demand))
      (Map.findWithDefault 0 (memberClaimOrdinal claim) (zkGenerationSlotPeaks generations))
      (DirectGeometry 1) (memberPresentation demand)))) claims
  uniform <- firstShow (uniformStatefulSetClaims volumes)
  mapM_ (\claim -> do
    required <- maybe (Left "zookeeper-member-uniform-claim-absent") Right
      (Map.lookup (StatefulSetClaimSlot "zookeeper" "data" (memberClaimOrdinal claim)) (uniformBytesBySlot uniform))
    check (memberClaimRawBytes claim >= required) ("member-" <> showText (memberClaimOrdinal claim) <> "-claim-raw")) claims
  let debit = sum (Map.elems (uniformClaimBytesByBacking uniform))
  _ <- firstShow (fitBacking (memberParent demand) debit)
  pure (ProvisionedZkMembers demand generations expanded uniform
    (maximum (0 : fmap (presentBytes (memberPresentation demand)) (Map.elems (zkGenerationSlotPeaks generations)))))
 where
  check condition reason = unless condition (Left ("zookeeper-member-" <> reason))
  resourceAxes = [("cpu",resourceCpu),("memory",resourceMemory),("ephemeral",resourceEphemeralStorage),("pods",resourcePodSlots)]

zkMemberOrdinals :: ProvisionedZkMembers -> [Natural]
zkMemberOrdinals (ProvisionedZkMembers demand _ _ _ _) = zkMembers (memberGenerations demand)

zkMemberK8sResources :: ProvisionedZkMembers -> Value
zkMemberK8sResources (ProvisionedZkMembers demand _ _ _ _) = envelopeK8sResources (executionResource (memberController demand))

zkMemberRawClaim :: ProvisionedZkMembers -> Natural -> Maybe Natural
zkMemberRawClaim (ProvisionedZkMembers _ _ _ uniform _) ordinal = Map.lookup
  (StatefulSetClaimSlot "zookeeper" "data" ordinal) (uniformBytesBySlot uniform)

zkMemberIdentityProjection :: ProvisionedZkMembers -> Value
zkMemberIdentityProjection provision@(ProvisionedZkMembers demand generations _ _ _) =
  toJSON [object ["ordinal" .= ordinal, "serverId" .= (ordinal+1),
    "source" .= executionInstanceSource executor, "revision" .= executionInstanceRevision executor,
    "instanceId" .= executionInstanceId executor, "podName" .= pod,
    "namespace" .= memberClaimNamespace claim, "statefulSet" .= memberClaimController claim,
    "claimTemplate" .= memberClaimTemplate claim, "claimId" .= memberClaimIdentity claim,
    "backingId" .= unBackingId (memberClaimBacking claim), "parentBackingId" .= unBackingId (backingId (memberParent demand)),
    "reserved" .= object ["cpuMillis" .= resourceCpu resources,"memoryBytes" .= resourceMemory resources,
      "ephemeralBytes" .= resourceEphemeralStorage resources,"podSlots" .= resourcePodSlots resources],
    "requiredUsableBytes" .= Map.findWithDefault 0 ordinal (zkGenerationSlotPeaks generations),
    "requiredRawBytes" .= raw]
  | ordinal <- zkMemberOrdinals provision
  , ZkMemberExecutor executor pod <- memberExecutors demand, executionInstanceOrdinal executor == ordinal
  , claim <- memberClaims demand, memberClaimOrdinal claim == ordinal
  , Just raw <- [zkMemberRawClaim provision ordinal]
  , let resources = executionInstanceResource executor]

zkMemberProjection :: ProvisionedZkMembers -> Value
zkMemberProjection provision@(ProvisionedZkMembers demand generations expanded uniform presented) = object
  [ "quorum" .= (length ordinals `div` 2+1)
  , "requiredPerMember" .= vector reserved
  , "steadyBytesPerMember" .= zkGenerationSteadyBytes generations
  , "incomingBytesPerMember" .= zkGenerationIncomingBytes generations
  , "peakUsableBytesPerMember" .= maximum (0:Map.elems (zkGenerationSlotPeaks generations))
  , "presentedBytesPerMember" .= presented
  , "uniformRawClaimBytes" .= maximum (0:Map.elems (uniformBytesBySlot uniform))
  , "executionTotal" .= vector (provisionedExecutionPeak expanded)
  , "uniformRawDebitBytes" .= sum (Map.elems (uniformClaimBytesByBacking uniform))
  , "uniformUsableReservationBytes" .= sum (Map.elems (zkGenerationSlotPeaks generations))
  , "steadyAggregateBytes" .= (fromIntegral (length ordinals)*zkGenerationSteadyBytes generations)
  , "largestFaultCaseAggregateBytes" .= maximum (0:fmap (sum . Map.elems . snd) cases)
  , "faultFamily" .= fmap fst cases
  , "faultCases" .= [object ["unavailable" .= failed, "memberUsableBytes" .= Map.mapKeys showText members] | (failed,members) <- cases]
  , "zeroRuntimeFailoverClaim" .= True ]
 where
  ordinals = zkMemberOrdinals provision
  cases = zkGenerationCases generations
  reserved = addResources (envelopeRequests (executionResource (memberController demand))) (envelopeHeadroom (executionResource (memberController demand)))
  vector value = object ["cpuMillis" .= resourceCpu value,"memoryBytes" .= resourceMemory value,
    "ephemeralBytes" .= resourceEphemeralStorage value,"podSlots" .= resourcePodSlots value]

data MinioExecutionProfile = MinioExecutionProfile
  { minioMaximumObjectBytes :: Natural, minioMaximumRequests :: Natural
  , minioManagedHeapBytes :: Natural, minioMemoryCeilingBytes :: Natural }
  deriving stock (Eq, Show)

-- Two admitted 512-MiB object requests, a 256-MiB managed-runtime reserve,
-- and a further 256 MiB between the managed heap and cgroup ceiling.
standardMinioExecutionProfile :: MinioExecutionProfile
standardMinioExecutionProfile = MinioExecutionProfile (512 * mib) 2 (1280 * mib) (1536 * mib)

provisionBackboneServices :: ResourceVector -> Either Text ProvisionedBackboneServices
provisionBackboneServices available = do
  services <- traverse provision profiles
  epochs <- firstShow (provisionExecutionEpochs Map.empty available (BoundExecutionInventory FirstDeployment
    [BoundExecutionUnit name 1 envelope controller | ProvisionedPlatformService name envelope controller _ _ _ <- services]))
  replacementEpochs <- traverse (replacementEpoch services epochs) [0,1,2]
  pure (ProvisionedBackboneServices (Map.fromList [(name, service) | service@(ProvisionedPlatformService name _ _ _ _ _) <- services]) epochs replacementEpochs)
 where
  provision (name, cpuLimit, memoryRequest, memoryLimit, ephemeralRequest, ephemeralLimit, controller) = do
    let requests = ResourceVector 50 (memoryRequest * mib) (ephemeralRequest * mib) 1
        limits = ResourceVector cpuLimit (memoryLimit * mib) (ephemeralLimit * mib) 1
        padding = ResourceVector (cpuLimit - 50) ((memoryLimit - memoryRequest) * mib) ((ephemeralLimit - ephemeralRequest) * mib) 0
        logs = 4 * mib
        writable = 4 * mib
        scratch = (ephemeralRequest - 8) * mib
    unless (ephemeralRequest >= 16 && scratch + writable + logs <= resourceEphemeralStorage requests)
      (Left "platform-ephemeral-nesting-violation")
    envelope <- firstShow (mkResourceEnvelope requests limits padding)
    pure (ProvisionedPlatformService name envelope controller scratch writable logs)
  replacementEpoch services original failed = do
    let bookies = [(envelope, scratch, writable, logs) | ProvisionedPlatformService name envelope _ scratch writable logs <- services,
                  name == "pulsar-system/bookkeeper"]
    (envelope, scratch, writable, logs) <- case bookies of [value] -> Right value; _ -> Left "bookkeeper-execution-profile-missing"
    let replacement = ProvisionedPlatformService "pulsar-system/bookkeeper-replacement" envelope
          (DeploymentBody 1 recreateRollout) scratch writable logs
        retained = Map.filter (\row -> executionInstanceSource row /= "pulsar-system/bookkeeper"
                    || executionInstanceOrdinal row /= failed) (provisionedDesiredSteady original)
        incoming = BoundExecutionUnit "pulsar-system/bookkeeper-replacement" 1 envelope (DeploymentBody 1 recreateRollout)
    -- This is the AFTER-exit inventory. It is not a token permitting overlap
    -- with a merely unavailable old process. The projected prerequisite must
    -- be observed by an execution authority before materialization.
    recovered <- firstShow (provisionRetainedExecutionEpochs ("after-bookie-" <> showText failed <> "-exit") available retained [incoming])
    pure (failed, recovered, replacement)
  stateful count = StatefulSetBody count StatefulSetOnDelete
  deployment = DeploymentBody 1 recreateRollout
  job = JobBody 1 1 0 3600
  profiles =
    [ ("metallb-system/controller", 250, 32, 128, 16, 64, deployment)
    , ("metallb-system/speaker", 250, 32, 128, 16, 64, DaemonSetBody ["root-node"] DaemonSetOnDelete)
    , ("platform-system/minio", 500, 256, minioMemoryCeilingBytes standardMinioExecutionProfile `div` mib, 16, 64, stateful 1)
    , ("platform-system/object-gateway", 125, 32, 96, 16, 64, stateful 1)
    , ("platform-system/registry-source", 250, 32, 128, 16, 64, deployment)
    , ("platform-system/registry", 250, 32, 128, 16, 64, deployment)
    , ("platform-system/registry-transfer", 250, 64, 128, 32, 64, job)
    , ("platform-system/registry-transfer-mismatch", 125, 32, 128, 32, 64, job)
    , ("pulsar-system/zookeeper", 500, 96, 256, 16, 64, stateful 3)
    , ("pulsar-system/bookkeeper", 500, 160, 384, 16, 64, stateful 3)
    -- NAR extraction is disk-backed scratch. Assign the already admitted
    -- ceiling to its named volume instead of leaving it as unused padding.
    , ("pulsar-system/broker", 500, 320, 768, 1024, 1024, stateful 2)
    -- The producer JVM and persistent read-only observer overlap. Reserve
    -- both managed heaps, direct memory and their native runtime overhead.
    , ("pulsar-system/pulsar-tool", 250, 32, 640, 16, 64, deployment)
    , ("pulsar-system/pulsar-metadata", 250, 96, 256, 16, 64, job)
    ]

backboneServicesPeak :: ProvisionedBackboneServices -> ResourceVector
backboneServicesPeak (ProvisionedBackboneServices _ epochs _) = provisionedExecutionPeak epochs

backboneService :: ProvisionedBackboneServices -> Text -> Maybe ProvisionedPlatformService
backboneService (ProvisionedBackboneServices services _ _) identity = Map.lookup identity services

platformServiceScratchBytes :: ProvisionedPlatformService -> Natural
platformServiceScratchBytes (ProvisionedPlatformService _ _ _ scratch _ _) = scratch

platformServiceK8sResources :: ProvisionedPlatformService -> Value
platformServiceK8sResources (ProvisionedPlatformService _ envelope _ _ _ _) = envelopeK8sResources envelope

envelopeK8sResources :: ResourceEnvelope -> Value
envelopeK8sResources envelope = object
  ["requests" .= resources (envelopeRequests envelope), "limits" .= resources (envelopeLimits envelope)]
 where
  resources value = object ["cpu" .= (showText (resourceCpu value) <> "m"),
    "memory" .= showText (resourceMemory value), "ephemeral-storage" .= showText (resourceEphemeralStorage value)]

backboneServiceResources :: ProvisionedBackboneServices -> Text -> Maybe Legacy.ResourceEnvelope
backboneServiceResources (ProvisionedBackboneServices services _ _) identity = do
  ProvisionedPlatformService _ envelope _ _ _ _ <- Map.lookup identity services
  let requests = envelopeRequests envelope
      limits = envelopeLimits envelope
  pure (Legacy.ResourceEnvelope (resourceCpu requests) (resourceCpu limits)
    (resourceMemory requests) (resourceMemory limits) (resourceEphemeralStorage requests) (resourceEphemeralStorage limits))

backboneServicesProjection :: ProvisionedBackboneServices -> Value
backboneServicesProjection provision@(ProvisionedBackboneServices services epochs replacements) = object
  [ "schema" .= ("amoebius.platform-service-projection.v1" :: Text)
  , "peak" .= vector (backboneServicesPeak provision)
  , "epochCount" .= length (provisionedEpochs epochs)
  , "services" .= Map.map platformServiceProjection services
  , "objectProducers" .= [object ["instance" .= producerInstance producer, "source" .= producerSource producer,
      "owner" .= producerOwner producer, "budget" .= unBudgetId (producerBudget producer),
      "kind" .= showText (producerKind producer), "scope" .= object ["store" .= scopeStore (producerScope producer),
        "tenant" .= scopeTenant (producerScope producer), "bucket" .= scopeBucket (producerScope producer)]]
      | producer <- backboneObjectProducers provision]
  , "bookkeeperReplacementEpochs" .= [object ["failedOrdinal" .= failed,
      "activationBoundary" .= (["owning-stateful-controller-retired-with-survivors-retained", "old-bookie-process-exit-observed"] :: [Text]),
      "startPermission" .= ("not-supplied-by-capacity-plan" :: Text),
      "retainedSurvivorOrdinals" .= [ordinal | ordinal <- [0,1,2 :: Natural], ordinal /= failed],
      "retainedSurvivorInstanceIds" .= [executionInstanceId row | row <- Map.elems (provisionedPriorSteady replacementEpoch),
          executionInstanceSource row == "pulsar-system/bookkeeper"],
      "replacement" .= platformServiceProjection replacement,
      "afterExitPeak" .= vector (provisionedExecutionPeak replacementEpoch),
      "beforeExitOverlapPeak" .= vector (addResources (backboneServicesPeak provision) (replacementUpper replacement))]
      | (failed, replacementEpoch, replacement) <- replacements]
  ]
 where
  replacementUpper (ProvisionedPlatformService _ envelope _ _ _ _) = addResources (envelopeRequests envelope) (envelopeHeadroom envelope)
  vector value = object ["cpuMillis" .= resourceCpu value, "memoryBytes" .= resourceMemory value,
    "ephemeralBytes" .= resourceEphemeralStorage value, "podSlots" .= resourcePodSlots value]

platformServiceProjection :: ProvisionedPlatformService -> Value
platformServiceProjection service@(ProvisionedPlatformService name envelope controller scratch writable logs) = object
    [ "identity" .= name, "resources" .= platformServiceK8sResources service
    , "effectivePodRequests" .= vector (envelopeRequests envelope), "effectivePodLimits" .= vector (envelopeLimits envelope)
    , "controller" .= showText controller, "cache" .= ("None" :: Text), "accelerator" .= ("None" :: Text)
    , "scratchBytes" .= scratch, "writableBytes" .= writable, "logBytes" .= logs
    , "logPolicy" .= object ["maximumFileBytes" .= (1048576 :: Natural), "maximumFiles" .= (3 :: Natural)]
    , "securityContext" .= object ["readOnlyRootFilesystem" .= True, "allowPrivilegeEscalation" .= False]
    , "environment" .= if name == "platform-system/minio"
        then [object ["name" .= ("MINIO_API_REQUESTS_MAX" :: Text), "value" .= showText (minioMaximumRequests standardMinioExecutionProfile)],
              object ["name" .= ("GOMEMLIMIT" :: Text), "value" .= (showText (minioManagedHeapBytes standardMinioExecutionProfile `div` mib) <> "MiB")]]
        else ([] :: [Value])
    ]
 where
  vector value = object ["cpuMillis" .= resourceCpu value, "memoryBytes" .= resourceMemory value,
    "ephemeralBytes" .= resourceEphemeralStorage value, "podSlots" .= resourcePodSlots value]

mib :: Natural
mib = 1048576

firstShow :: Show problem => Either problem value -> Either Text value
firstShow = either (Left . showText) Right

showText :: Show value => value -> Text
showText = Text.pack . show
