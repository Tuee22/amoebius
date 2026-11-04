{-# LANGUAGE OverloadedStrings #-}

-- | The actual image inventory crosses into MinIO only through this pure plan.
-- The old registry provision stays intact; its driver projection, upload and
-- orphan populations remain structural inputs to the new physical geometry.
module Amoebius.Platform.StoragePlan
  ( BackboneStorageDemand (..), RegistryDriverObject (..), ProvisionedBackboneStorage
  , provisionBackboneStorage, backboneVolumeInventory, backbonePoolCapacityBytes
  , backboneStorageProjection, backboneDemandFromHandoff
  , backboneRegistryDriverObjects, backboneRegistryIndexDigest
  , backbonePulsarProfile
  , backboneWriterAdmissions
  , backboneZooKeeperMemberDemand
  , backboneHistoryStoreStorage
  ) where

import Amoebius.Capacity.Recovery
import Amoebius.Capacity.ZooKeeper
import Amoebius.Capacity.Execution (executionInstanceOrdinal, executionInstanceResource)
import Amoebius.Capacity.Placement
import Amoebius.Capacity.ObjectStore
import Amoebius.Capacity.ServiceStorage (ZooKeeperMetadataStoreDemand (..), serviceStoragePeakBytes)
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
  ( BookKeeperPolicy (..), GeometryWitness (..), MinioPolicy (..), PulsarDemand (..) )
import Amoebius.Image.Artifact (ImagePlatform (..), RegistryObjectKind (..))
import Amoebius.Image.Registry
import Amoebius.Platform.Pulsar
import Amoebius.Platform.Provision
import Amoebius.Platform.ObjectGatewayPolicy
import Amoebius.Platform.HistoryStoreProvision
import Amoebius.Platform.ZooKeeperHistory (historyPolicy)
import Control.Monad (unless)
import Crypto.Hash (Digest, SHA256, hash)
import Data.Aeson (Value, object, withObject, (.:), (.=))
import Data.Aeson.Types (Parser)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Numeric.Natural (Natural)

data RegistryDriverObject = RegistryDriverObject
  { driverObjectBytes :: Natural, driverObjectDigest :: Text }
  deriving stock (Eq, Show)

data BackboneStorageDemand = BackboneStorageDemand
  { backboneRegistryDemand :: RegistryStorageDemand
  , backboneRegistryKinds :: Map Text RegistryObjectKind
  , backboneRegistryIndex :: Text, backboneRegistryRepository :: Text, backboneRegistryTag :: Text
  , backbonePulsarDemand :: PulsarBackboneDemand
  , backboneBacking :: StorageBacking }
  deriving stock (Eq, Show)

data ProvisionedBackboneStorage = ProvisionedBackboneStorage BackboneStorageDemand
  ProvisionedRegistryStorageDemand (Map Text RegistryDriverObject)
  LogicalObjectStorePeak MinioPlacement RecoveryPlan RecoveryPlan (Map Text (Natural, Natural)) Natural
  ProvisionedHistoryStoreStorage
  deriving stock (Eq, Show)

backboneWriterAdmissions :: ProvisionedBackboneStorage -> Map Text ObjectWriterAdmission
backboneWriterAdmissions (ProvisionedBackboneStorage _ _ _ peak _ _ _ _ _ _) = objectStoreWriterAdmissions peak

-- | Decode the public, attestation-verified Phase-25 observations. Model names
-- bind the arithmetic; recorded totals are cross-checks rather than inputs
-- that could silently replace the original commitments.
backboneDemandFromHandoff :: PulsarBackboneDemand -> Value -> Parser BackboneStorageDemand
backboneDemandFromHandoff pulsar = withObject "verified image handoff" $ \input -> do
  artifact <- input .: "artifact"
  preflight <- input .: "preflight"
  publication <- input .: "publication"
  backingBytes <- input .: "backingCapacityBytes"
  (index, rows) <- withObject "image artifact" (\value -> (,)
    <$> value .: "imageIndexDigest" <*> (value .: "registryObjects" >>= traverse parseRow)) artifact
  let objects = Map.fromList [(identity, bytes) | (identity, bytes, _) <- rows]
      kinds = Map.fromList [(identity, kind) | (identity, _, kind) <- rows]
      largest = maximum (0 : Map.elems objects)
  unless (Map.size objects == length rows) (fail "duplicate registry object identity")
  (fingerprint, concurrency, horizon, recordedStored, recordedWorkspace, recordedFailed, recordedPeak, count) <-
    withObject "image preflight" (\value -> do
      fingerprint <- value .: "fingerprint"
      value .: "registry" >>= withObject "registry commitment" (\registry -> do
        workspaceModel <- registry .: "workspaceModel"
        failedModel <- registry .: "failedUploadModel"
        unless (workspaceModel == ("largest-compressed-object-per-upload-v1" :: Text)
          && failedModel == ("three-one-gib-capped-partials-v1" :: Text))
          (fail "unsupported registry storage model")
        (,,,,,,,) fingerprint <$> registry .: "uploadConcurrency" <*> registry .: "gcHorizonSeconds"
          <*> registry .: "storedBytes" <*> registry .: "workspaceBytes" <*> registry .: "failedUploadBytes"
          <*> registry .: "peakBytes" <*> registry .: "objectCount")) preflight
  (repository, tag, publishedIndex, publishedFingerprint) <- withObject "publication"
    (\value -> (,,,) <$> value .: "repository" <*> value .: "immutableTag"
      <*> value .: "indexDigest" <*> value .: "preflightFingerprint") publication
  unless (publishedIndex == index && publishedFingerprint == fingerprint) (fail "publication handoff mismatch")
  let workspace = concurrency * largest
      failed = 3 * min largest (1024 * mib)
      stored = sum (Map.elems objects)
      peak = stored + workspace + failed
  unless ((recordedStored, recordedWorkspace, recordedFailed, recordedPeak, count)
    == (stored, workspace, failed, peak, Map.size objects)) (fail "registry commitment arithmetic mismatch")
  let registry = RegistryStorageDemand objects objects concurrency largest 3 (min largest (1024 * mib))
        horizon peak (RegistryMutationAdmission fingerprint (Map.keysSet objects) concurrency largest)
  pure (BackboneStorageDemand registry kinds index repository tag pulsar
    (StorageBacking (BackingId "retained-parent") backingBytes (BackingAllocationPolicy 1 1)))
 where
  parseRow = withObject "registry object" $ \value -> do
    identity <- value .: "digest"
    bytes <- value .: "storedBytes"
    name <- value .: "kind"
    kind <- case name :: Text of
      "layer" -> pure RegistryLayer
      "config-amd64" -> pure (RegistryConfig LinuxAmd64)
      "config-arm64" -> pure (RegistryConfig LinuxArm64)
      "manifest-amd64" -> pure (RegistryChildManifest LinuxAmd64)
      "manifest-arm64" -> pure (RegistryChildManifest LinuxArm64)
      "index" -> pure RegistryIndex
      _ -> fail "unsupported registry object kind"
    pure (identity, bytes, kind)

provisionBackboneStorage :: BackboneStorageDemand -> Either Text ProvisionedBackboneStorage
provisionBackboneStorage demand = do
  registry <- firstShow (provisionRegistryStorage (backboneRegistryDemand demand))
  unless ((pulsarBrokerReplicas (backbonePulsarDemand demand), pulsarBookieReplicas (backbonePulsarDemand demand),
    pulsarZooKeeperReplicas (backbonePulsarDemand demand)) == (2, 3, 3))
    (Left "backbone-storage-requires-the-declared-three-member-profile")
  let kinds = backboneRegistryKinds demand
      objects = provisionedRegistryObjects registry
  unless (Map.keysSet kinds == Map.keysSet objects) (Left "registry-driver-kind-set-mismatch")
  unless ([digest | (digest, RegistryIndex) <- Map.toList kinds] == [backboneRegistryIndex demand])
    (Left "registry-driver-index-mismatch")
  unless (Set.fromList [platform | RegistryConfig platform <- Map.elems kinds] == Set.fromList [LinuxAmd64, LinuxArm64]
    && Set.fromList [platform | RegistryChildManifest platform <- Map.elems kinds] == Set.fromList [LinuxAmd64, LinuxArm64])
    (Left "registry-driver-platform-set-mismatch")
  unless (validRepository (backboneRegistryRepository demand) && validTag (backboneRegistryTag demand))
    (Left "registry-driver-location-invalid")
  let driverObjects = registryDriverObjects demand objects
      scope = SourceScope "root-minio" "platform" "registry"
      residents = Map.fromList [(PhysicalObjectId "root-minio" "platform" "registry" key, driverObjectBytes value) | (key, value) <- Map.toList driverObjects]
      original = backboneRegistryDemand demand
      future = [ObjectPopulation "post-cutover-blob" 1 65536 0, ObjectPopulation "post-cutover-link" 1 71 0, ObjectPopulation "registry-driver-metadata" 16 4096 0]
      concurrent = [ObjectPopulation "registry-upload-workspace" (registryUploadConcurrency original) (registryUploadWorkspaceBytesPerUpload original) 0]
        <> [ObjectPopulation "registry-future-write-workspace-excess" (registryUploadConcurrency original) (65536 - largest) 0 | largest < 65536]
      failed = [ObjectPopulation "registry-failed-upload-window" (registryFailedUploadsPerWindow original) (registryPartialBytesPerFailedUpload original) (registryGcHorizonSeconds original)
               | registryFailedUploadsPerWindow original > 0]
        <> [ObjectPopulation "registry-future-write-failed-excess" 3 (max 65536 largest - registryPartialBytesPerFailedUpload original) (registryGcHorizonSeconds original)
           | registryPartialBytesPerFailedUpload original < max 65536 largest]
      driverResidentBytes = sum (Map.elems residents)
      registryQuota = driverResidentBytes + provisionedRegistryUploadWorkspaceBytes registry
        + provisionedRegistryFailedUploadBytes registry + 65536 + 71 + 16 * 4096
        + registryUploadConcurrency original * (max 65536 largest - largest)
        + 3 * (max (max 65536 largest) (registryPartialBytesPerFailedUpload original) - registryPartialBytesPerFailedUpload original)
      registrySource = RegistrySource (ObjectSourceDemand "registry" "registry" scope
        (ProviderObjectQuota (BudgetId "registry") "root-minio" registryQuota
          (fromIntegral (Map.size residents)+sum (fmap populationCount (future<>concurrent<>failed))))
        residents future concurrent [] failed)
      -- The named finite drill produces at most 128 data/index pairs. Each
      -- extent has its own stripe cost; inflight/failed generations stay live.
      offloadContext = ObjectSourceContext "pulsar-offload" "pulsar" (SourceScope "root-minio" "platform" "pulsar-offload")
        (ProviderObjectQuota (BudgetId "pulsar-offload") "root-minio" (512 * mib) 512)
      activeLedgerPolicy = pulsarBookKeeperPolicy (pulsarStorage (backbonePulsarDemand demand))
      offloadLedger = PulsarLedgerModel 65536 1024 (5 * mib)
        (bookKeeperEnsembleSize activeLedgerPolicy) (bookKeeperWriteQuorum activeLedgerPolicy)
        (bookKeeperAckQuorum activeLedgerPolicy) 9223372036854775807
        (Map.singleton 0 ["bookkeeper-" <> showText ordinal <> ".bookkeeper.pulsar-system.svc.cluster.local:3181"
          | ordinal <- [0 .. bookKeeperEnsembleSize activeLedgerPolicy - 1]])
        -- The longest finite topic is phase30/drill/persistent/time-only-
        -- followed by32 hex characters. No affinity placement policy is enabled.
        (Map.fromList [("application", 6), ("component", 14), ("pulsar/managed-ledger", 67)])
      offloadDemand = PulsarObjectDemand PulsarSingleBlockV1 "phase30/drill" Map.empty offloadLedger
        128 3600 3600 0 1 (FailedWriteWindow 1 3600 3600) mib
      canary = ApplicationSource (ObjectSourceDemand "application-canary" "phase30-application"
        (SourceScope "root-minio" "platform" (applicationGatewayBucket standardApplicationGateway))
        (ProviderObjectQuota (BudgetId "application-canary") "root-minio" (3 * canaryBytes) 3)
        Map.empty [ObjectPopulation "admitted-canary" 1 canaryBytes 0]
        [ObjectPopulation "canary-inflight" 1 canaryBytes 0] []
        [ObjectPopulation "canary-failed-window" 1 canaryBytes (applicationGatewayFailedHorizonSeconds standardApplicationGateway)])
      canaryBytes = applicationGatewayObjectBytes standardApplicationGateway
      largest = maximum (0 : Map.elems objects)
      policy = MinioPolicy 1 2 2 4096 8192 8192 1 1 1 (max 65536 largest)
  unless (registryFailedUploadsPerWindow original >= 3)
    (Left "registry-gateway-failed-history-unfunded")
  unless (largest <= minioMaximumObjectBytes standardMinioExecutionProfile)
    (Left "registry-object-exceeds-minio-execution-profile")
  unless (registryUploadConcurrency original <= minioMaximumRequests standardMinioExecutionProfile)
    (Left "registry-concurrency-exceeds-minio-execution-profile")
  derivedOffload <- firstShow (derivePulsarObjects offloadContext offloadDemand)
  unless (all (<= mib) (Map.elems (derivedStoredExtents derivedOffload)))
    (Left "offload-encoding-exceeds-gateway-admitted-extent")
  logical <- firstShow (foldObjectStoreSources (Set.fromList ["registry", "pulsar-offload", "application-canary"])
    [registrySource, derivedObjectSource derivedOffload, canary])
  placement <- firstShow (objectStoreMinioPlacement policy logical)
  pulsar <- firstShow (provisionPulsarBackbone (backbonePulsarDemand demand))
  let metadata = pulsarMetadata (backbonePulsarDemand demand)
      bookkeeper = pulsarStorage (backbonePulsarDemand demand)
      bookkeeperPolicy = pulsarBookKeeperPolicy bookkeeper
  unless (zooKeeperMembers metadata == 3 && bookKeeperEnsembleSize bookkeeperPolicy == 3)
    (Left "backbone-storage-membership-model-mismatch")
  generations <- firstShow (provisionZkGenerations (backboneZooKeeperGenerations metadata))
  unless (zooKeeperPathsBytesPerMember metadata == 1048576
    && zooKeeperTransactionLogBytesPerMember metadata == 32 * mib
    && zooKeeperSnapshotBytesPerMember metadata == 3 * mib
    && zooKeeperRecoveryBytesPerMember metadata == zkGenerationIncomingBytes generations)
    (Left "backbone-zookeeper-generation-policy-mismatch")
  let snapshotMaximum = zkMaximumSnapshotExtent (backboneZooKeeperGenerations metadata)
  history <- historyPolicy [0,1,2] snapshotMaximum 1024 ((snapshotMaximum-1024) `div` 3)
    (zkNormalLogGenerations (backboneZooKeeperGenerations metadata))
    (zkNormalSnapshotGenerations (backboneZooKeeperGenerations metadata))
  let gatewayDemand = nativeHistoryStoreStorageDemand history (backingCapacityBytes (backboneBacking demand))
  -- This local witness supplies the child geometry. Only the final witness,
  -- bound to the complete privately computed pool, escapes this constructor.
  localGateway <- provisionHistoryStoreStorage history (64*mib) gatewayDemand
  let perDrive = maximum (0 : fmap slotPeakBytes (Map.elems (minioSlots placement)))
      minioRaw = allocation 64 perDrive
      registryUsable = driverResidentBytes + provisionedRegistryUploadWorkspaceBytes registry + provisionedRegistryFailedUploadBytes registry
      registryRaw = allocation 64 registryUsable
      -- Any bookie can receive the whole retained ledger population, plus a
      -- re-replication generation. Dividing a cluster total is not a slot fit.
      bookieUsable = pulsarLogicalHotBytes bookkeeper * (1 + bookKeeperFaultBound bookkeeperPolicy)
        + bookKeeperJournalAndIndexBytesPerBookie bookkeeperPolicy
      bookieRaw = roundAllocation (backingAllocation (pulsarBookieBacking bookkeeper))
        (presentBytes (FilesystemPresentation "ext4-v1" 500) bookieUsable)
      -- ZooKeeper's declaration is explicitly uniform per member.
      zkUsable = maximum (0 : Map.elems (zkGenerationSlotPeaks generations))
      zkRaw = roundAllocation (backingAllocation (zooKeeperBacking metadata))
        (presentBytes (FilesystemPresentation "ext4-v1" 500) zkUsable)
      claims = Map.fromList
        ([("phase30-minio-" <> showText ordinal, (minioRaw, perDrive)) | ordinal <- [0..3 :: Int]]
        <> [("phase30-zookeeper-" <> showText ordinal, (zkRaw, zkUsable)) | ordinal <- [0..2 :: Int]]
        <> [("phase30-bookkeeper-" <> showText ordinal, (bookieRaw, bookieUsable)) | ordinal <- [0..2 :: Int]]
        <> [("phase30-registry-source", (registryRaw, registryUsable)),
            ("phase30-gateway-state", (historyStoreFilesystemRawBytes localGateway, historyStoreFilesystemUsableBytes localGateway)),
            ("phase30-minio-replacement-0", (minioRaw, perDrive)), ("phase30-bookkeeper-replacement-0", (bookieRaw, bookieUsable))])
      pool = roundAllocation (BackingAllocationPolicy mib mib) (sum (fmap fst (Map.elems claims)) + 192 * mib + 4096)
  minioRecovery <- firstShow (provisionMinioRecovery placement (Map.singleton 4 perDrive))
  bookieRecovery <- firstShow (bookKeeperHistoryEnvelope bookkeeperPolicy [0,1,2] [3] (pulsarLogicalHotBytes bookkeeper))
  unless (all (<= bookieUsable) (Map.elems (recoverySlotPeaks bookieRecovery)))
    (Left "bookkeeper-replacement-profile-insufficient")
  _ <- firstShow (fitBacking (pulsarBookieBacking bookkeeper) (4 * bookieRaw))
  _ <- firstShow (fitBacking (zooKeeperBacking metadata) (3 * zkRaw))
  _ <- firstShow (fitBacking (backboneBacking demand) (physicalPoolBytes pool))
  gateway <- provisionHistoryStoreStorage history (physicalPoolBytes pool) gatewayDemand
  unless (serviceStoragePeakBytes (provisionedPulsarMetadata pulsar) == sum (Map.elems (zkGenerationSlotPeaks generations)))
    (Left "backbone-zookeeper-generation-peak-mismatch")
  pure (ProvisionedBackboneStorage demand registry driverObjects logical placement minioRecovery bookieRecovery claims pool gateway)
 where
  allocation minimumMiB usable = roundAllocation (BackingAllocationPolicy (minimumMiB * mib) (64 * mib))
    (presentBytes (FilesystemPresentation "ext4-v1" 500) usable)

backboneVolumeInventory :: ProvisionedBackboneStorage -> Map Text Natural
backboneVolumeInventory (ProvisionedBackboneStorage _ _ _ _ _ _ _ claims _ _) = fmap fst claims

backbonePoolCapacityBytes :: ProvisionedBackboneStorage -> Natural
backbonePoolCapacityBytes (ProvisionedBackboneStorage _ _ _ _ _ _ _ _ pool _) = pool

backboneRegistryDriverObjects :: ProvisionedBackboneStorage -> Map Text RegistryDriverObject
backboneRegistryDriverObjects (ProvisionedBackboneStorage _ _ driver _ _ _ _ _ _ _) = driver

backboneRegistryIndexDigest :: ProvisionedBackboneStorage -> Text
backboneRegistryIndexDigest (ProvisionedBackboneStorage demand _ _ _ _ _ _ _ _ _) = backboneRegistryIndex demand

backbonePulsarProfile :: ProvisionedBackboneStorage -> PulsarBackboneDemand
backbonePulsarProfile (ProvisionedBackboneStorage demand _ _ _ _ _ _ _ _ _) = backbonePulsarDemand demand

backboneHistoryStoreStorage :: ProvisionedBackboneStorage -> ProvisionedHistoryStoreStorage
backboneHistoryStoreStorage (ProvisionedBackboneStorage _ _ _ _ _ _ _ _ _ gateway) = gateway

-- Bind each independently charged metadata member to its actual execution
-- instance and exact retained filesystem. The generation policy is the same
-- one used to create the storage inventory, before any manifest is rendered.
backboneZooKeeperMemberDemand :: ProvisionedBackboneStorage -> ProvisionedBackboneServices -> Either Text ZkMemberDemand
backboneZooKeeperMemberDemand (ProvisionedBackboneStorage demand _ _ _ _ _ _ claims pool _) services = do
  (controller, executors) <- backboneZooKeeperExecution services
  let metadata = pulsarMetadata (backbonePulsarDemand demand)
      policy = backboneZooKeeperGenerations metadata
      parentId = BackingId "retained-parent"
  members <- traverse (\ordinal -> do
    let identity = "phase30-zookeeper-" <> showText ordinal
    (raw,usable) <- maybe (Left "backbone-zookeeper-claim-absent") Right (Map.lookup identity claims)
    pure (ZkMemberClaim ordinal "pulsar-system" "zookeeper" "data" ("data-zookeeper-" <> showText ordinal)
      (BackingId identity) usable raw, ZkMemberBacking (BackingId identity) parentId raw)) (zkMembers policy)
  pure (ZkMemberDemand controller executors
    [(executionInstanceOrdinal row,executionInstanceResource row) | ZkMemberExecutor row _ <- executors]
    (fmap fst members) (fmap snd members) (StorageBacking parentId pool (BackingAllocationPolicy 1 1))
    policy (FilesystemPresentation "ext4-v1" 500) (backingAllocation (zooKeeperBacking metadata)))

backboneZooKeeperGenerations :: ZooKeeperMetadataStoreDemand -> ZkGenerationPolicy
backboneZooKeeperGenerations metadata = ZkGenerationPolicy [0..zooKeeperMembers metadata-1] 1
  2 2 (16*mib) 3 1 mib mib

backboneStorageProjection :: ProvisionedBackboneStorage -> Value
backboneStorageProjection provision@(ProvisionedBackboneStorage demand registry driverObjects logical placement minioRecovery bookieRecovery claims pool gateway) = object
  [ "schema" .= ("amoebius.backbone-storage.v1" :: Text), "poolCapacityBytes" .= pool
  , "physicalPoolRawBytes" .= physicalPoolBytes pool, "vaultUnlockAllowanceBytes" .= (4096 :: Natural)
  , "gatewayStateStorage" .= historyStoreStorageProjection gateway
  , "gatewayStateBacking" .= object ["namespace" .= ("platform-system" :: Text),
      "executor" .= ("platform-system/object-gateway" :: Text), "pod" .= ("object-gateway-0" :: Text),
      "claimTemplate" .= ("state" :: Text), "claim" .= ("state-object-gateway-0" :: Text),
      "backing" .= ("phase30-gateway-state" :: Text),
      "parent" .= unBackingId (backingId (backboneBacking demand)),
      "historySubdirectory" .= ("zookeeper-history" :: Text)]
  , "registry" .= object
      [ "indexDigest" .= backboneRegistryIndex demand, "repository" .= backboneRegistryRepository demand
      , "tag" .= backboneRegistryTag demand, "objectSet" .= provisionedRegistryObjects registry
      , "derivedPeak" .= provisionedRegistryPeakBytes registry, "storedBytes" .= provisionedRegistryStoredBytes registry
      , "uploadConcurrency" .= registryUploadConcurrency (backboneRegistryDemand demand)
      , "workspaceBytes" .= provisionedRegistryUploadWorkspaceBytes registry
      , "failedUploadBytes" .= provisionedRegistryFailedUploadBytes registry
      , "gcHorizonSeconds" .= provisionedRegistryGcHorizonSeconds registry
      , "publisherCapabilityDigest" .= registryPublisherCapabilityDigest (registryMutationAdmission (backboneRegistryDemand demand))
      , "driverObjects" .= [object ["key" .= key, "bytes" .= driverObjectBytes value, "sha256" .= driverObjectDigest value] | (key, value) <- Map.toList driverObjects] ]
  , "objectStorePeak" .= object
      [ "logicalBytes" .= objectStoreLogicalBytes logical, "objectCount" .= objectStoreLogicalObjectCount logical
      , "residents" .= [object ["store" .= physicalStore identity, "tenant" .= physicalTenant identity,
          "bucket" .= physicalBucket identity, "key" .= physicalFullKey identity, "bytes" .= bytes] | (identity, bytes) <- Map.toList (objectStoreResidents logical)]
      , "populations" .= [object ["source" .= source, "kind" .= showText kind, "name" .= populationName population,
          "count" .= populationCount population, "maximumBytes" .= populationMaximumBytes population,
          "windowSeconds" .= populationWindowSeconds population] | (source, kind, population) <- objectStorePopulations logical]
      , "writerAdmissions" .= fmap objectWriterAdmissionProjection (objectStoreWriterAdmissions logical)
      , "sourceModels" .= fmap objectModelInputProjection (objectStoreModelInputs logical) ]
  , "minio" .= object ["erasureSets" .= (1 :: Int), "dataShards" .= (2 :: Int), "parityShards" .= (2 :: Int),
      "shardBlockBytes" .= (4096 :: Natural), "logicalBytes" .= objectStoreLogicalBytes logical,
      "physicalBytes" .= geometryPhysicalBytes (minioPlacementGeometry placement), "components" .= geometryComponents (minioPlacementGeometry placement),
      "faultScenarios" .= geometryFailureScenarios (minioPlacementGeometry placement),
      "slots" .= [object ["driveId" .= ordinal, "setId" .= (ordinal `div` 4),
        "claim" .= ("data" <> showText ordinal <> "-minio-0"), "backing" .= ("phase30-minio-" <> showText ordinal),
        "replacementClaim" .= ("replacement-minio-replacement-0" :: Text),
        "replacementDriveId" .= (4 :: Natural), "replacementBacking" .= ("phase30-minio-replacement-0" :: Text),
        "steadyBytes" .= slotSteadyBytes slot, "incomingRecoveryBytes" .= slotRecoveryBytes slot,
        "requiredUsableBytes" .= slotPeakBytes slot, "components" .= slotComponents slot]
        | (ordinal, slot) <- Map.toList (minioSlots placement)],
      "replacementPool" .= [object ["driveId" .= (4 :: Natural), "claim" .= ("replacement-minio-replacement-0" :: Text),
        "backing" .= ("phase30-minio-replacement-0" :: Text), "requiredUsableBytes" .= required "phase30-minio-replacement-0"]],
      "recoveryCases" .= fmap recoveryCase (recoveryCases minioRecovery)]
  , "bookkeeperRecovery" .= object ["activeMemberIds" .= recoveryActiveIds bookieRecovery,
      "replacementMemberIds" .= recoverySpareIds bookieRecovery,
      "slotPeakBytes" .= recoverySlotPeaks bookieRecovery,
      "replacement" .= object ["memberId" .= (3 :: Natural), "bookieId" .= ("bookkeeper-replacement-0.bookkeeper.pulsar-system.svc.cluster.local:3181" :: Text),
        "claim" .= ("replacement-bookkeeper-replacement-0" :: Text), "backing" .= ("phase30-bookkeeper-replacement-0" :: Text),
        "requiredUsableBytes" .= required "phase30-bookkeeper-replacement-0"],
      "recoveryCases" .= fmap recoveryCase (recoveryCases bookieRecovery),
      "executionPrerequisite" .= ("owning-controller-retired-and-old-process-exit-observed; capacity-plan-is-not-a-start-permit" :: Text)]
  , "minioRuntime" .= object ["maximumObjectBytes" .= minioMaximumObjectBytes standardMinioExecutionProfile,
      "maximumRequests" .= minioMaximumRequests standardMinioExecutionProfile,
      "managedHeapBytes" .= minioManagedHeapBytes standardMinioExecutionProfile,
      "memoryCeilingBytes" .= minioMemoryCeilingBytes standardMinioExecutionProfile]
  , "volumes" .= [object ["name" .= name, "rawBytes" .= raw, "requiredUsableBytes" .= usable] | (name, (raw, usable)) <- Map.toList claims]
  , "inventory" .= backboneVolumeInventory provision ]
 where
  required name = maybe 0 snd (Map.lookup name claims)
  recoveryCase value = object ["failedMembers" .= failedMembers value,
    "replacements" .= [object ["sourceId" .= source, "targetId" .= target] | (source,target) <- Map.toList (replacementMembers value)],
    "incomingBytes" .= incomingBytes value,
    "segments" .= [object ["id" .= retainedSegmentId segment, "bytes" .= retainedSegmentBytes segment,
      "ensemble" .= retainedEnsemble segment, "writeSet" .= retainedWriteSet segment] | segment <- recoverySegments value]]

registryDriverObjects :: BackboneStorageDemand -> Map Text Natural -> Map Text RegistryDriverObject
registryDriverObjects demand objects = Map.fromList (concatMap project (Map.toList objects) <> tagged)
 where
  prefix = "docker/registry/v2/"
  repo = prefix <> "repositories/" <> backboneRegistryRepository demand <> "/"
  raw digest = Text.drop 7 digest
  link digest = RegistryDriverObject 71 ("sha256:" <> Text.pack (show (hash (Text.encodeUtf8 digest) :: Digest SHA256)))
  project (digest, bytes) =
    [ (prefix <> "blobs/sha256/" <> Text.take 2 (raw digest) <> "/" <> raw digest <> "/data", RegistryDriverObject bytes digest)
    , (repo <> directory (Map.findWithDefault RegistryLayer digest (backboneRegistryKinds demand)) <> "/sha256/" <> raw digest <> "/link", link digest) ]
  directory kind = case kind of
    RegistryLayer -> "_layers"
    RegistryConfig _ -> "_layers"
    RegistryChildManifest _ -> "_manifests/revisions"
    RegistryIndex -> "_manifests/revisions"
  tagged =
    [ (repo <> "_manifests/tags/" <> backboneRegistryTag demand <> "/current/link", link (backboneRegistryIndex demand))
    , (repo <> "_manifests/tags/" <> backboneRegistryTag demand <> "/index/sha256/" <> raw (backboneRegistryIndex demand) <> "/link", link (backboneRegistryIndex demand)) ]

validRepository :: Text -> Bool
validRepository name = not (Text.null name) && all (\part -> not (Text.null part) && part `notElem` [".", ".."] && Text.all allowed part) (Text.splitOn "/" name)
 where allowed character = character `elem` ("abcdefghijklmnopqrstuvwxyz0123456789._-" :: String)

validTag :: Text -> Bool
validTag tag = not (Text.null tag) && Text.length tag <= 128 && tag /= "latest"
  && Text.all (\character -> character `elem` ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" :: String)) tag

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator = (numerator + denominator - 1) `div` denominator

showText :: Show value => value -> Text
showText = Text.pack . show

firstShow :: Show problem => Either problem value -> Either Text value
firstShow = either (Left . showText) Right

mib :: Natural
mib = 1048576

physicalPoolBytes :: Natural -> Natural
physicalPoolBytes capacity = capacity + max (64 * mib) (ceilDiv capacity (20 * mib) * mib)
