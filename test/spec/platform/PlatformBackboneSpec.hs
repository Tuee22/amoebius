{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.ServiceStorage hiding (RegistryStorageDemand (..))
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
import Amoebius.Capacity.ObjectStore (SourceKind (..), SourceScope (..))
import Amoebius.Platform.Backbone
import Amoebius.Platform.LoadBalancer
import Amoebius.Platform.Minio
import Amoebius.Platform.Pulsar
import Amoebius.Platform.Registry
import Amoebius.Platform.StoragePlan
import Amoebius.Platform.Provision
import Amoebius.Platform.RegistryMigration
import Amoebius.Platform.Manifest
import Amoebius.Platform.S3Admission (gatewayPolicyFromStorage)
import Amoebius.Manifest.K8sObject qualified as K8s
import Amoebius.Manifest (renderAll)
import Amoebius.Capacity.Types qualified as Capacity
import Amoebius.Platform.Types
import Amoebius.Image.Artifact (ImagePlatform (..), RegistryObjectKind (..))
import Amoebius.Image.Registry
import Control.Monad (foldM)
import Data.Aeson (Value (Object, Array), eitherDecode, encode, toJSON, withObject, (.:))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.ByteString.Lazy.Char8 qualified as Lazy
import Data.Either (isLeft)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Numeric.Natural (Natural)
import System.Environment (getArgs, lookupEnv)
import System.Exit (die)
import Text.Read (readMaybe)
import RecoverySpec (verifyRecovery, verifyConditionalEpochs)
import PlacementSpec (verifyPlacement)
import ObjectStoreSpec (verifyObjectStore)
import ObjectSourceModelsSpec (verifyObjectSourceModels)
import ZooKeeperSpec (verifyZooKeeper)
import ZooKeeperMemberSpec (verifyZooKeeperMembers)
import ZooKeeperHistorySpec (verifyZooKeeperHistory)
import ZooKeeperHistoryStoreSpec (verifyZooKeeperHistoryStore)
import ExecutionPodSpec (verifyExecutionPods)
import S3StreamingSpec (verifyS3Streaming)
import RuntimePolicyBindingSpec (verifyRuntimePolicyBinding)
import S3AdmissionSpec (verifyS3Admission)
import S3SigningSpec (verifyS3Signing)

main :: IO ()
main = do
  arguments <- getArgs
  minio <- requireRight (provisionMinio minioDemand)
  registry <- requireRight (provisionRegistryRehome registryDemand migrationDemand "http://minio.platform-system.svc:9000" "registry")
  pulsar <- requireRight (provisionPulsarBackbone pulsarDemand)
  loadBalancer <- requireRight (provisionLoadBalancer loadBalancerPlan)
  case arguments of
    ["--history-store-only"] -> verifyZooKeeperHistoryStore
    ["--metadata-member-plan"] -> metadataMemberPlan Nothing
    ["--metadata-member-negative", axis, rawOrdinal] -> do
      ordinal <- maybe (die "invalid metadata member ordinal") pure (readMaybe rawOrdinal)
      metadataMemberPlan (Just (axis,ordinal))
    ["--backbone-objects", stageName] -> do
      stage <- case stageName of
        "metallb" -> pure MetalLBStage
        "minio" -> pure MinioStage
        "application-gateway" -> pure ApplicationGatewayStage
        "registry-source" -> pure RegistrySourceStage
        "registry-target" -> pure RegistryTargetStage
        "registry-retired" -> pure RegistryRetiredStage
        "zookeeper" -> pure ZooKeeperStage
        "pulsar-metadata" -> pure PulsarMetadataStage
        "bookkeeper" -> pure BookKeeperStage
        "pulsar-brokers" -> pure PulsarBrokerStage
        _ -> die "invalid backbone stage"
      input <- Lazy.getContents >>= requireRightString . eitherDecode
      demand <- requireRightString (parseEither (backboneDemandFromHandoff livePulsarDemand) input)
      storage <- requireRight (provisionBackboneStorage demand)
      supply <- lookupEnv "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY" >>= maybe
        (die "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY is required") (parseSupply . words)
      services <- requireRight (provisionBackboneServices supply)
      image <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE" "missing"
      node <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_NODE" "missing"
      pool <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_POOL" "missing"
      provision <- requireRight (provisionBackboneManifest storage services (BackboneRuntime image node pool) stage)
      manifests <- requireRight (maybe (Left ("incomplete backbone API object" :: Text)) Right
        (traverse K8s.extensionObjectApiValue (renderAll provision)))
      Lazy.putStrLn (encode manifests)
    ["--migration-objects", modeName] -> do
      mode <- case modeName of
        "copy" -> pure CopyEveryObject
        "verify-corrupt-link" -> pure VerifyCorruptLink
        _ -> die "invalid migration mode"
      input <- Lazy.getContents >>= requireRightString . eitherDecode
      demand <- requireRightString (parseEither (backboneDemandFromHandoff livePulsarDemand) input)
      storage <- requireRight (provisionBackboneStorage demand)
      supply <- lookupEnv "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY" >>= maybe
        (die "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY is required") (parseSupply . words)
      services <- requireRight (provisionBackboneServices supply)
      image <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE" "missing"
      migration <- requireRight (provisionRegistryMigration storage services image mode)
      manifests <- requireRight (maybe (Left ("incomplete API object" :: Text)) Right (traverse K8s.extensionObjectApiValue (renderAll migration)))
      Lazy.putStrLn (encode manifests)
    ["--service-plan", cpu, memory, ephemeral, pods] -> do
      available <- parseSupply [cpu, memory, ephemeral, pods]
      requireRight (provisionBackboneServices available) >>= Lazy.putStrLn . encode . backboneServicesProjection
    ["--storage-plan"] -> do
      input <- Lazy.getContents >>= requireRightString . eitherDecode
      demand <- requireRightString (parseEither (backboneDemandFromHandoff livePulsarDemand) input)
      requireRight (provisionBackboneStorage demand) >>= Lazy.putStrLn . encode . backboneStorageProjection
    ["--render-plan"] -> do
      runtimeImage <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE" privateImage
      runtimeAddress <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_ADDRESS" (loadBalancerAddress loadBalancerPlan)
      supply <- lookupEnv "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY" >>= maybe
        (die "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY is required") (parseSupply . words)
      services <- requireRight (provisionBackboneServices supply)
      let authored = renderBackbone loadBalancer minio pulsar <> renderRegistryRehome privateImage registryResources registry
          runtime object = (materializeRuntimePlan runtimeImage runtimeAddress object)
            { objectResources = if objectKind object == "Service" then Nothing
                else backboneServiceResources services (objectNamespace object <> "/" <> objectName object) }
      Lazy.putStr (encode (fmap runtime authored))
    [] -> do
      verifyPlacement
      verifyRecovery
      verifyObjectStore
      verifyObjectSourceModels
      verifyZooKeeper
      verifyZooKeeperMembers
      verifyZooKeeperHistory
      verifyZooKeeperHistoryStore
      verifyExecutionPods
      verifyS3Admission
      verifyS3Signing
      verifyS3Streaming
      verifyMinio minio
      verifyRegistry registry
      verifyPulsar pulsar
      verifyBackbone minio pulsar
      verifyStoragePlan
      verifyServicePlan
      putStrLn "platform-backbone-spec: PASS (HA shape, physical storage, verified registry rehome, size offload, readiness DAG)"
    _ -> die "usage: platform-backbone-spec [--render-plan|--storage-plan|--service-plan CPU MEMORY EPHEMERAL PODS]"

parseSupply :: [String] -> IO Capacity.ResourceVector
parseSupply values = case traverse readMaybe values of
  Just [cpu, memory, ephemeral, pods] -> pure (Capacity.ResourceVector cpu memory ephemeral pods)
  _ -> die "service supply requires four natural-valued axes"

metadataMemberPlan :: Maybe (String,Natural) -> IO ()
metadataMemberPlan negative = do
  input <- Lazy.getContents >>= requireRightString . eitherDecode
  demand <- requireRightString (parseEither (backboneDemandFromHandoff livePulsarDemand) input)
  storage <- requireRight (provisionBackboneStorage demand)
  supply <- lookupEnv "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY" >>= maybe
    (die "AMOEBIUS_PLATFORM_BACKBONE_EXECUTION_SUPPLY is required") (parseSupply . words)
  services <- requireRight (provisionBackboneServices supply)
  actual <- requireRight (backboneZooKeeperMemberDemand storage services)
  selected <- maybe (pure actual) (\(axis,ordinal) -> requireRight (shortMember axis ordinal actual)) negative
  members <- requireRight (provisionZkMembers selected)
  Lazy.putStrLn (encode (toJSON (Map.fromList [("capacity" :: Text, zkMemberProjection members),
    ("bindings", zkMemberIdentityProjection members)])))

-- The test CLI changes the already derived real member budget, never the
-- accepted inventory or manifest path. Neighbor surplus preserves sums.
shortMember :: String -> Natural -> ZkMemberDemand -> Either Text ZkMemberDemand
shortMember axis target demand
  | target `notElem` fmap memberClaimOrdinal (memberClaims demand) = Left "unknown metadata member ordinal"
  | axis == "parent" = Right demand {memberParent = (memberParent demand)
      {backingCapacityBytes = sum (fmap memberClaimRawBytes (memberClaims demand))-1}}
  | axis == "usable" || axis == "incoming" = Right demand {memberClaims = fmap (\claim -> claim
      {memberClaimUsableBytes = change (if axis == "incoming" then 33*1048576 else 1)
        (memberClaimOrdinal claim) (memberClaimUsableBytes claim)}) (memberClaims demand)}
  | axis == "raw" = Right demand {memberClaims = fmap (\claim -> claim
      {memberClaimRawBytes = change 1 (memberClaimOrdinal claim) (memberClaimRawBytes claim)}) (memberClaims demand)}
  | axis == "backing" = Right demand {memberBackings = fmap (\backing -> backing
      {memberBackingBytes = if memberBackingIdentity backing == BackingId ("phase30-zookeeper-" <> Text.pack (show target))
        then memberBackingBytes backing-1 else if memberBackingIdentity backing == BackingId ("phase30-zookeeper-" <> Text.pack (show neighbor))
          then memberBackingBytes backing+1 else memberBackingBytes backing}) (memberBackings demand)}
  | otherwise = do
      (get,set) <- case axis of
        "cpu" -> Right (Capacity.resourceCpu,\value vector -> vector {Capacity.resourceCpu=value})
        "memory" -> Right (Capacity.resourceMemory,\value vector -> vector {Capacity.resourceMemory=value})
        "ephemeral" -> Right (Capacity.resourceEphemeralStorage,\value vector -> vector {Capacity.resourceEphemeralStorage=value})
        "pods" -> Right (Capacity.resourcePodSlots,\value vector -> vector {Capacity.resourcePodSlots=value})
        _ -> Left "unknown metadata member axis"
      Right demand {memberSupplies = [(ordinal,set (change 1 ordinal (get available)) available)
        | (ordinal,available) <- memberSupplies demand]}
 where
  neighbor = if target == 0 then 1 else 0
  change amount ordinal value | ordinal == target = value-amount
                              | ordinal == neighbor = value+amount
                              | otherwise = value

verifyServicePlan :: IO ()
verifyServicePlan = do
  oracle <- Lazy.readFile "test/oracle/platform_backbone_gateway.json" >>= requireRightString . eitherDecode
  expected <- requireRightString $ parseEither (withObject "gateway oracle" (\root -> root .: "execution_union" >>= withObject "execution" (\row ->
    Capacity.ResourceVector <$> row .: "cpu_millis" <*> ((1048576 *) <$> row .: "memory_mib")
      <*> ((1048576 *) <$> row .: "ephemeral_mib") <*> row .: "pod_slots"))) oracle
  exact <- requireRight (provisionBackboneServices expected)
  assertEqual "whole-backbone execution peak" expected (backboneServicesPeak exact)
  verifyConditionalEpochs (backboneServicesProjection exact)
  let short =
        [ ("CPU", expected {Capacity.resourceCpu = 6499}, "CpuAxis")
        , ("memory", expected {Capacity.resourceMemory = 6752 * 1048576 - 1}, "MemoryAxis")
        , ("ephemeral", expected {Capacity.resourceEphemeralStorage = 3072 * 1048576 - 1}, "EphemeralStorageAxis")
        , ("pod slots", expected {Capacity.resourcePodSlots = 17}, "PodSlotsAxis") ]
  mapM_ (\(name, supply, reason) -> case provisionBackboneServices supply of
    Left failure -> assertBool ("whole-backbone one-unit-short " <> name) (reason `Text.isInfixOf` failure)
    Right _ -> die ("whole-backbone admitted short " <> name)) short

-- The live profile uses the same quorum/metadata operands as the regression
-- fixture, with explicit physical allocation policies for its ext4 claims.
livePulsarDemand :: PulsarBackboneDemand
livePulsarDemand = pulsarDemand
  { pulsarSizeTriggerBytes = Just 32768
  , pulsarStorage = (pulsarStorage pulsarDemand)
      { pulsarBookieBacking = StorageBacking (BackingId "bookkeeper") (512 * 1048576) (BackingAllocationPolicy (128 * 1048576) (64 * 1048576))
      , pulsarBookKeeperPolicy = (pulsarBookKeeperPolicy (pulsarStorage pulsarDemand))
          {bookKeeperJournalAndIndexBytesPerBookie = 48 * 1048576}
      -- The controlled time-only negative still has a finite physical budget:
      -- both 100-message runs, their wire metadata, dedup and control ledgers.
      , pulsarLogicalHotBytes = 4 * 1048576 }
  , pulsarMetadata = (pulsarMetadata pulsarDemand)
      { zooKeeperBacking = StorageBacking (BackingId "zookeeper") (512 * 1048576) (BackingAllocationPolicy (64 * 1048576) (64 * 1048576))
      , zooKeeperPathsBytesPerMember = 1048576
      , zooKeeperTransactionLogBytesPerMember = 32 * 1048576
      , zooKeeperSnapshotBytesPerMember = 3 * 1048576
      , zooKeeperRecoveryBytesPerMember = 33 * 1048576 }
  }

verifyStoragePlan :: IO ()
verifyStoragePlan = do
  gatewayOracle <- Lazy.readFile "test/oracle/platform_backbone_gateway.json" >>= requireRightString . eitherDecode
  historyStorageOracle <- Lazy.readFile "test/oracle/platform_backbone_history_store_storage.json" >>= requireRightString . eitherDecode
  capacityOracle <- Lazy.readFile "test/oracle/platform_backbone_capacity.json" >>= requireRightString . eitherDecode
  offloadOracle <- Lazy.readFile "test/oracle/platform_backbone_offload_profile.json" >>= requireRightString . eitherDecode
  let objects = Map.fromList [(digest character, 4096) | character <- "abcdef"]
      kinds = Map.fromList (zip (fmap digest "abcdef")
        [RegistryLayer, RegistryConfig LinuxAmd64, RegistryConfig LinuxArm64,
         RegistryChildManifest LinuxAmd64, RegistryChildManifest LinuxArm64, RegistryIndex])
      registry = RegistryStorageDemand objects objects 2 4096 3 4096 3600 45056
        (RegistryMutationAdmission (digest '0') (Map.keysSet objects) 2 4096)
      demand = BackboneStorageDemand registry kinds (digest 'f') "amoebius/base" "immutable-test"
        livePulsarDemand (StorageBacking (BackingId "retained-parent") (64 * 1024 * 1048576) (BackingAllocationPolicy 1 1))
  provision <- requireRight (provisionBackboneStorage demand)
  let projection = backboneStorageProjection provision
      volume name = case jsonPath ["volumes"] projection of
        Just (Array rows) -> case [row | row <- foldr (:) [] rows, jsonPath ["name"] row == Just (toJSON (name :: Text))] of
          [row] -> row
          _ -> Object mempty
        _ -> Object mempty
      population name = case jsonPath ["objectStorePeak", "populations"] projection of
        Just (Array rows) -> case [row | row <- foldr (:) [] rows, jsonPath ["name"] row == Just (toJSON (name :: Text))] of
          [row] -> row
          _ -> Object mempty
        _ -> Object mempty
  assertEqual "reviewed gateway raw state claim"
    (jsonPath ["gateway_retained_filesystem", "required_raw_bytes"] gatewayOracle)
    (jsonPath ["rawBytes"] (volume "phase30-gateway-state"))
  assertEqual "reviewed gateway usable state claim"
    (jsonPath ["expected", "combinedGatewayFilesystemUsableBytes"] historyStorageOracle)
    (jsonPath ["requiredUsableBytes"] (volume "phase30-gateway-state"))
  assertEqual "original gateway component remains independently reserved"
    (jsonPath ["gateway_retained_filesystem", "required_usable_bytes"] gatewayOracle)
    (jsonPath ["gatewayStateStorage", "originalGateway", "dedicatedUsableBytes"] projection)
  assertEqual "reviewed metadata object inventory"
    (jsonPath ["metadata_addition", "object_count"] gatewayOracle)
    (jsonPath ["count"] (population "registry-driver-metadata"))
  assertEqual "reviewed metadata extent ceiling"
    (jsonPath ["metadata_addition", "maximum_bytes_each"] gatewayOracle)
    (jsonPath ["maximumBytes"] (population "registry-driver-metadata"))
  assertEqual "reviewed BookKeeper usable profile"
    (jsonPath ["fixed_profiles", "bookkeeper_proposed_serialized_history_profile", "required_usable_per_bookie"] capacityOracle)
    (jsonPath ["requiredUsableBytes"] (volume "phase30-bookkeeper-0"))
  assertEqual "private native offload retains the independently reviewed structured profile"
    (jsonPath ["expected_model_input_projection"] offloadOracle)
    (jsonPath ["objectStorePeak","sourceModels","pulsar-offload"] projection)
  let writerMap = jsonPath ["objectStorePeak","writerAdmissions"] projection
      expectedWriterMap = jsonPath ["expected_installed_source_join"] offloadOracle
  case (writerMap,expectedWriterMap) of
    (Just (Object writers),Just (Object expected)) -> do
      assertEqual "installed native producer and private writer domains match" (Set.fromList (KeyMap.keys expected)) (Set.fromList (KeyMap.keys writers))
      mapM_ (\(name, expectedRow) -> mapM_ (\field -> assertEqual "native writer scope/kind/owner/budget join"
        (jsonPath [field] expectedRow) (KeyMap.lookup name writers >>= jsonPath [field]))
        ["kind","owner","budget","scope"]) (KeyMap.toList expected)
    _ -> die "native source writer inventory projection missing"
  _ <- requireRight (gatewayPolicyFromStorage projection)
  verifyRuntimePolicyBinding projection (backboneWriterAdmissions provision)
  let editPath [] change value = change value
      editPath (key:rest) change (Object fields) = Object (case KeyMap.lookup (Key.fromText key) fields of
        Nothing -> fields
        Just value -> KeyMap.insert (Key.fromText key) (editPath rest change value) fields)
      editPath _ _ value = value
      editWriter change = editPath ["objectStorePeak","writerAdmissions","pulsar-offload"] change projection
      setField key value (Object fields) = Object (KeyMap.insert (Key.fromText key) value fields)
      setField _ _ value = value
      smallPopulation (Object fields) = if KeyMap.lookup "kind" fields == Just (toJSON ("FutureObjects" :: Text))
        then Object (KeyMap.insert "maximumBytes" (toJSON (1048575 :: Int)) fields) else Object fields
      smallPopulation value = value
      smaller (Array rows) = Array (fmap smallPopulation rows)
      smaller value = value
  assertBool "runtime cannot omit private writer admission"
    (isLeft (gatewayPolicyFromStorage (editPath ["objectStorePeak","writerAdmissions"]
      (\value -> case value of Object fields -> Object (KeyMap.delete "pulsar-offload" fields); _ -> value) projection)))
  assertBool "runtime cannot install a foreign writer owner"
    (isLeft (gatewayPolicyFromStorage (editWriter (setField "owner" (toJSON ("foreign" :: Text))))))
  assertBool "runtime cannot substitute a cheaper object extent"
    (isLeft (gatewayPolicyFromStorage (editWriter (editPath ["populations"] smaller))))
  producerServices <- requireRight (provisionBackboneServices (Capacity.ResourceVector 8000 (8*1024*1048576) (4*1024*1048576) 64))
  let producers = backboneObjectProducers producerServices
      admissions = backboneWriterAdmissions provision
      badJoin label actors policies = assertBool label (isLeft (bindObjectProducerWriters actors policies))
  assertEqual "all expanded registry, transfer, broker and gateway writers are present" 6 (length producers)
  requireRight (bindObjectProducerWriters producers admissions)
  badJoin "duplicate expanded writer instance rejects" (producers <> take 1 producers) admissions
  badJoin "missing installed producer source rejects"
    (filter ((/= "pulsar-offload") . producerSource) producers) admissions
  badJoin "extra writer policy rejects" producers (Map.insert "foreign" (snd (Map.findMin admissions)) admissions)
  let changeFirst modify = case producers of first:rest -> modify first:rest; [] -> []
  badJoin "wrong installed producer owner rejects" (changeFirst (\row -> row {producerOwner="foreign"})) admissions
  badJoin "wrong installed producer budget rejects" (changeFirst (\row -> row {producerBudget=BudgetId "foreign"})) admissions
  badJoin "wrong installed producer scope rejects" (changeFirst (\row -> row {producerScope=SourceScope "foreign" "platform" "registry"})) admissions
  badJoin "wrong installed producer kind rejects" (changeFirst (\row -> row {producerKind=ContentObjects})) admissions
  assertEqual "reviewed BookKeeper minimum raw presentation"
    (jsonPath ["fixed_profiles", "bookkeeper_proposed_serialized_history_profile", "required_raw_per_bookie"] capacityOracle)
    (jsonPath ["rawBytes"] (volume "phase30-bookkeeper-0"))
  assertEqual "reviewed ZooKeeper usable profile"
    (jsonPath ["fixed_profiles", "zookeeper_proposed_explicit_profile", "required_usable_per_member"] capacityOracle)
    (jsonPath ["requiredUsableBytes"] (volume "phase30-zookeeper-0"))
  assertEqual "small canonical fixture funds three complete future-write failures"
    (Just (toJSON (61440 :: Int))) (jsonPath ["maximumBytes"] (population "registry-future-write-failed-excess"))
  assertEqual "future-write failure count stays finite"
    (Just (toJSON (3 :: Int))) (jsonPath ["count"] (population "registry-future-write-failed-excess"))
  services <- requireRight (provisionBackboneServices (Capacity.ResourceVector 6500 (6752 * 1048576) (3072 * 1048576) 18))
  let runtime = BackboneRuntime ("registry.amoebius.invalid/base@" <> digest 'f') "node-0" "10.0.0.1/32"
  nativeStages <- traverse (requireRight . provisionBackboneManifest provision services runtime)
    [MetalLBStage, MinioStage, ApplicationGatewayStage, RegistrySourceStage, RegistryTargetStage, RegistryRetiredStage,
     ZooKeeperStage, PulsarMetadataStage, BookKeeperStage, PulsarBrokerStage]
  nativeWire <- requireRight (maybe (Left ("incomplete native backbone API object" :: Text)) Right
    (traverse K8s.extensionObjectApiValue (concatMap renderAll nativeStages)))
  assertBool "native render covers the complete backbone" (length nativeWire > 45)
  let publicBytes = Text.pack (Lazy.unpack (encode nativeWire))
      renderedZkOptions = [value | workload <- nativeWire,
        jsonPath ["kind"] workload == Just (toJSON ("StatefulSet" :: Text)),
        jsonPath ["metadata","name"] workload == Just (toJSON ("zookeeper" :: Text)),
        Just (Array containers) <- [jsonPath ["spec","template","spec","containers"] workload],
        container <- foldr (:) [] containers, jsonPath ["name"] container == Just (toJSON ("zookeeper" :: Text)),
        Just (Array environment) <- [jsonPath ["env"] container], field <- foldr (:) [] environment,
        jsonPath ["name"] field == Just (toJSON ("PULSAR_EXTRA_OPTS" :: Text)), Just value <- [jsonPath ["value"] field]]
  assertEqual "rendered ZooKeeper preallocation is the independently amended pin"
    [value | Just value <- [jsonPath ["fixed_profiles","zookeeper_proposed_explicit_profile","jvm_property"] capacityOracle]] renderedZkOptions
  assertBool "native manifests never carry credential literals or Kubernetes credential Secrets"
    (all (not . (`Text.isInfixOf` publicBytes)) ["MINIO_ROOT_PASSWORD", "AWS_SECRET_ACCESS_KEY", "secretKeyRef", "stringData"])
  mapM_ (\stage -> let identities = fmap K8s.objectIdentity (renderAll stage) in
    assertEqual "native object identities are unique" (length identities) (Set.size (Set.fromList identities))) nativeStages
  assertEqual "native services cannot substitute an unsealed image" (Left "backbone-manifest-image-provenance-mismatch")
    (provisionBackboneManifest provision services (runtime {runtimeImage = "registry.invalid/wrong"}) MinioStage)
  migration <- requireRight (provisionRegistryMigration provision services ("registry.amoebius.invalid/base@" <> digest 'f') CopyEveryObject)
  assertEqual "migration emits complete typed Kubernetes objects"
    [K8s.ConfigMapKind, K8s.JobKind, K8s.ServiceAccountKind] (fmap K8s.objectKind (renderAll migration))
  wire <- requireRight (maybe (Left ("incomplete API object" :: Text)) Right (traverse K8s.extensionObjectApiValue (renderAll migration)))
  job <- case [value | value <- wire, jsonPath ["kind"] value == Just (toJSON ("Job" :: Text))] of
    [value] -> pure value
    _ -> die "migration must emit exactly one job"
  let pod = ["spec", "template", "spec"]
  assertBool "transfer source, config, binary and scratch are explicit"
    (case jsonPath (pod <> ["volumes"]) job of Just (Array values) -> length values == 4; _ -> False)
  assertEqual "transfer has finite parallelism" (Just (toJSON (1 :: Int))) (jsonPath ["spec", "parallelism"] job)
  assertEqual "transfer cannot restart failed writes" (Just (toJSON (0 :: Int))) (jsonPath ["spec", "backoffLimit"] job)
  assertEqual "transfer pins the scoped Vault identity" (Just (toJSON ("registry-writer" :: Text))) (jsonPath (pod <> ["serviceAccountName"]) job)
  case jsonPath (pod <> ["containers"]) job of
    Just (Array values) | [container] <- foldr (:) [] values -> do
      service <- requireRight (maybe (Left ("missing transfer service" :: Text)) Right (backboneService services "platform-system/registry-transfer"))
      assertEqual "complete transfer envelope comes from the canonical provision"
        (Just (platformServiceK8sResources service)) (jsonPath ["resources"] container)
      assertEqual "transfer root filesystem is read-only" (Just (toJSON True)) (jsonPath ["securityContext", "readOnlyRootFilesystem"] container)
      case jsonPath ["volumeMounts"] container of
        Just (Array mounts) | source : _ <- foldr (:) [] mounts ->
          assertEqual "transfer source is mounted read-only" (Just (toJSON True)) (jsonPath ["readOnly"] source)
        _ -> die "transfer source mount missing"
    _ -> die "transfer executor container missing"
  assertEqual "transfer cannot substitute another image" (Left "registry-transfer-image-provenance-mismatch")
    (provisionRegistryMigration provision services ("registry.amoebius.invalid/base@" <> digest 'e') CopyEveryObject)
  assertEqual "complete backbone child inventory" 14 (Map.size (backboneVolumeInventory provision))
  let liveBookkeeper = pulsarStorage livePulsarDemand
      shortBookkeeper = liveBookkeeper {pulsarBookieBacking = (pulsarBookieBacking liveBookkeeper)
        {backingCapacityBytes = 512 * 1048576 - 1}}
  assertBool "three bookies and the distinct spare debit the exact complete backing"
    (isLeft (provisionBackboneStorage (demand {backbonePulsarDemand = livePulsarDemand {pulsarStorage = shortBookkeeper}})))
  let pool = backbonePoolCapacityBytes provision
      overhead = max (64 * 1048576) (((pool + 20 * 1048576 - 1) `div` (20 * 1048576)) * 1048576)
      raw = pool + overhead
      exact = demand {backboneBacking = (backboneBacking demand) {backingCapacityBytes = raw}}
  _ <- requireRight (provisionBackboneStorage exact)
  assertBool "one-byte-short parent rejects complete physical pool"
    (isLeft (provisionBackboneStorage (exact {backboneBacking = (backboneBacking exact) {backingCapacityBytes = raw - 1}})))
  assertEqual "driver cannot omit a platform object" (Left "registry-driver-kind-set-mismatch")
    (provisionBackboneStorage (demand {backboneRegistryKinds = Map.delete (digest 'c') kinds}))
  assertBool "new registry admission cannot hide conflicting resident bytes"
    (isLeft (provisionBackboneStorage (demand {backboneRegistryDemand = registry {registryObservedResidentObjects = Map.singleton (digest 'a') 4097}})))
  let oversized = 513 * 1048576
      bigObjects = Map.insert (digest 'a') oversized objects
      bigRegistry = registry {registryDesiredObjects = bigObjects, registryObservedResidentObjects = bigObjects,
        registryUploadWorkspaceBytesPerUpload = oversized, registryVolumeCapacityBytes = 64 * 1024 * 1048576,
        registryMutationAdmission = (registryMutationAdmission registry) {registryMaxObjectBytes = oversized}}
  assertEqual "object storage fit cannot bypass the MinIO memory profile"
    (Left "registry-object-exceeds-minio-execution-profile")
    (provisionBackboneStorage (demand {backboneRegistryDemand = bigRegistry}))
  let extraUpload = registry {registryUploadConcurrency = 3, registryVolumeCapacityBytes = 64 * 1024 * 1048576,
        registryMutationAdmission = (registryMutationAdmission registry) {registryMaxConcurrentUploads = 3}}
  assertEqual "upload storage fit cannot bypass bounded MinIO request concurrency"
    (Left "registry-concurrency-exceeds-minio-execution-profile")
    (provisionBackboneStorage (demand {backboneRegistryDemand = extraUpload}))

jsonPath :: [Text] -> Value -> Maybe Value
jsonPath [] value = Just value
jsonPath (key : rest) (Object values) = KeyMap.lookup (Key.fromText key) values >>= jsonPath rest
jsonPath _ _ = Nothing

verifyMinio :: ProvisionedMinio -> IO ()
verifyMinio provision = do
  let gateway = provisionedMinioGateway provision
      geometry = provisionedMinioGeometry provision
      expectedLogical = gatewayResidentBytes gateway + gatewayTransientBytes gateway
  assertBool "failed-write orphan horizon retained" (geometryLogicalBytes geometry == expectedLogical && gatewayTransientBytes gateway > 0)
  assertBool "MinIO physical geometry amplifies logical bytes" (geometryPhysicalBytes geometry > geometryLogicalBytes geometry)
  assertBool "MinIO fault scenarios complete" (length (geometryFailureScenarios geometry) > 1)
  assertEqual "uniform MinIO drive debit" (provisionedMinioPerDriveBytes provision * 4) (provisionedMinioUniformDebit provision)
  assertEqual "six producer arms" (Set.fromList ["apps", "content", "registry", "offload", "checkpoints", "control-state"]) (gatewayWriters gateway)
  let objects = renderMinio provision
  assertBool "MinIO resources exact and device-free" (all exactCpu objects && all ((== Nothing) . objectCache) objects && all ((== Nothing) . objectAccelerator) objects)

verifyRegistry :: ProvisionedRegistryRehome -> IO ()
verifyRegistry provision = do
  expected <- TextIO.readFile "test/fixture/platform_backbone/registry-storage-driver.golden"
  assertEqual "registry uses MinIO S3 driver" expected (registryStorageConfiguration (registryTargetBackend provision))
  assertEqual "registry digest map complete" 3 (Map.size (registryReplacementObjects provision))
  assertEqual "failed verification preserves source" (RegistryFilesystem "/var/lib/registry") (cutoverRegistry False provision)
  assertEqual "verified migration cuts over" (registryTargetBackend provision) (cutoverRegistry True provision)
  assertEqual "Phase-25 peak preserved" 49152 (registryOriginalPeak provision)
  assertEqual "canonical registry union preserved" (provisionedRegistryObjects (registryOriginalProvision provision)) (registryReplacementObjects provision)
  assertBool "canonical digest-size conflict rejects rehome"
    (isLeft (provisionRegistryRehome (registryDemand {registryObservedResidentObjects = Map.singleton layerDigest 8193}) migrationDemand "http://minio.platform-system.svc:9000" "registry"))
  assertEqual "migration cannot replace original commitments" (Left "registry-migration-commitment-mismatch")
    (provisionRegistryRehome registryDemand (migrationDemand {migrationOldBytes = 49151}) "http://minio.platform-system.svc:9000" "registry")
  assertEqual "migration executor one byte short" (Left "registry-migration-stream-buffer-too-small")
    (provisionRegistryRehome registryDemand (migrationDemand {migrationExecutorBytes = 8191}) "http://minio.platform-system.svc:9000" "registry")

verifyPulsar :: ProvisionedPulsarBackbone -> IO ()
verifyPulsar provision = do
  assertEqual "size-triggered offload provision" (Just 65536) (pulsarSizeTriggerBytes (provisionedPulsarDemand provision))
  let segments = [Segment "ledger-1" 32768, Segment "ledger-2" 32768, Segment "ledger-3" 32768]
      result = applySizeTriggeredOffload 65536 segments
  assertEqual "offload appears" [Segment "ledger-1" 32768] (offloadedSegments result)
  assertEqual "hot tier bounded" 65536 (hotBytes result)
  assertEqual
    "broker dedup exercised"
    [("producer-a", 7, "cbor-1"), ("producer-a", 8, "cbor-2")]
    (deduplicateMessages [("producer-a", 7, "cbor-1"), ("producer-a", 7, "duplicate"), ("producer-a", 8, "cbor-2")])
  assertBool "BookKeeper quorum amplification" (geometryPhysicalBytes (pulsarHotWitness (provisionedPulsarStorage provision)) > 65536)
  assertEqual "Pulsar workload and initialization arms" 5 (length (renderPulsar provision))

verifyBackbone :: ProvisionedMinio -> ProvisionedPulsarBackbone -> IO ()
verifyBackbone minio pulsar = do
  assertBool "registry waits for MinIO" (not (mayStart initialBackboneState Registry))
  assertBool "Pulsar waits for Vault" (not (mayStart initialBackboneState Pulsar))
  state <- requireRightString (foldM observeReady initialBackboneState [MetalLB, MinIO, Registry, Vault, ZooKeeper, BookKeeper, Pulsar])
  assertBool "event-driven readiness reaches Pulsar" (Pulsar `Set.member` readyServices state)
  lb <- requireRight (provisionLoadBalancer loadBalancerPlan)
  let baseline = renderBackbone lb minio pulsar
      scaled = fmap scale baseline
  assertBool "HA render differs only by replicas" (sameHaShape baseline scaled)
  assertBool "baked private image only" (all (\object -> objectImage object == "" || objectImage object == privateImage) baseline)
 where
  scale object
    | objectKind object == "StatefulSet" || objectKind object == "Deployment" || objectKind object == "DaemonSet" = object {objectReplicas = objectReplicas object + 2}
    | otherwise = object

privateImage :: Text
privateImage = "registry.amoebius.invalid:5000/amoebius/base@runtime-resolved-digest"

environmentText :: String -> Text -> IO Text
environmentText name fallback = maybe fallback Text.pack <$> lookupEnv name

materializeRuntimePlan :: Text -> Text -> PlatformObject -> PlatformObject
materializeRuntimePlan runtimeImage runtimeAddress object =
  object
    { objectImage = if objectImage object == privateImage then runtimeImage else objectImage object
    , objectArguments =
        if objectKind object == "Service" && objectNamespace object == "platform-system" && objectName object == "minio"
          then [runtimeAddress]
          else case (objectNamespace object, objectName object) of
            ("platform-system", "minio") -> wrapper "minio"
            ("platform-system", "registry") -> wrapper "registry"
            ("pulsar-system", "broker") -> wrapper "pulsar-broker"
            _ -> objectArguments object
    }
 where wrapper profile = ["/amoebius-runtime/amoebius", "platform-service-exec", profile]

envelope :: Natural -> Natural -> Natural -> Natural -> ResourceEnvelope
envelope memoryRequest memoryLimit ephemeralRequest ephemeralLimit =
  ResourceEnvelope 50 500 memoryRequest memoryLimit ephemeralRequest ephemeralLimit

controllerEnvelope, speakerEnvelope, minioEnvelope, registryResources :: ResourceEnvelope
controllerEnvelope = envelope 33554432 134217728 16777216 67108864
speakerEnvelope = envelope 33554432 134217728 16777216 67108864
minioEnvelope = envelope 134217728 536870912 16777216 67108864
registryResources = envelope 33554432 134217728 16777216 67108864

zookeeperResources, metadataResources, bookieResources, brokerResources, toolResources :: ResourceEnvelope
zookeeperResources = envelope 100663296 268435456 16777216 67108864
metadataResources = envelope 100663296 268435456 16777216 67108864
bookieResources = envelope 167772160 402653184 16777216 67108864
brokerResources = envelope 335544320 805306368 268435456 1073741824
toolResources = envelope 33554432 402653184 16777216 67108864

loadBalancerPlan :: LoadBalancerPlan
loadBalancerPlan = LoadBalancerPlan "172.18.255.200" privateImage controllerEnvelope speakerEnvelope

minioDemand :: MinioDemand
minioDemand =
  MinioDemand
    "minio"
    privateImage
    1
    (Set.fromList ["apps", "content", "registry", "offload", "checkpoints", "control-state"])
    [ AppBucketProducer "apps" [ObjectExtent "apps/a" 4096] 2048
    , ContentProducer "content" [ObjectExtent "content/a" 4096] 2048
    , RegistryProducer "registry" [ObjectExtent "registry/a" 4096] 4096
    , PulsarOffloadProducer "offload" [ObjectExtent "offload/a" 4096] 4096
    , PulumiCheckpointProducer "checkpoints" [ObjectExtent "checkpoints/a" 4096] 2048
    , ControlPlaneStateProducer "control-state" [ObjectExtent "control/a" 4096] 2048
    ]
    (MinioPolicy 1 2 2 4096 1024 8192 1 1 1 8192)
    (FilesystemPresentation "ext4-v1" 500)
    (StorageBacking (BackingId "minio") 268435456 (BackingAllocationPolicy 67108864 67108864))
    minioEnvelope

registryDemand :: RegistryStorageDemand
registryDemand =
  RegistryStorageDemand
    (Map.fromList [(layerDigest, 8192), (digest 'b', 4096), (digest 'c', 4096)])
    Map.empty
    2
    8192
    2
    8192
    60
    67108864
    (RegistryMutationAdmission (digest 'd') (Set.fromList [layerDigest, digest 'b', digest 'c']) 2 8192)

layerDigest :: Text
layerDigest = digest 'a'

digest :: Char -> Text
digest character = "sha256:" <> Text.replicate 64 (Text.singleton character)

migrationDemand :: MigrationDemand
migrationDemand =
  MigrationDemand
    "registry-to-minio"
    49152
    49152
    16384
    8192
    0
    8192
    (StorageBacking (BackingId "registry-migration") 262144 (BackingAllocationPolicy 0 4096))

pulsarDemand :: PulsarBackboneDemand
pulsarDemand =
  PulsarBackboneDemand
    privateImage
    2
    3
    3
    ( PulsarDemand
        "phase30-drill"
        65536
        (Just 1048576)
        (BookKeeperPolicy 3 2 2 16384 1)
        (StorageBacking (BackingId "bookkeeper") 1048576 (BackingAllocationPolicy 0 4096))
        (FixedBackingBudget (BudgetId "pulsar-offload") (BackingId "minio") 1048576)
    )
    ( ZooKeeperMetadataStoreDemand
        "pulsar-zookeeper"
        3
        4096
        4096
        4096
        4096
        (StorageBacking (BackingId "zookeeper") 65536 (BackingAllocationPolicy 0 4096))
    )
    65536
    (Just 65536)
    zookeeperResources
    metadataResources
    bookieResources
    brokerResources
    toolResources

exactCpu :: PlatformObject -> Bool
exactCpu object = case objectResources object of
  Nothing -> True
  Just resource -> requestCpuMillis resource == 50 && limitCpuMillis resource == 500

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

requireRightString :: Either String value -> IO value
requireRightString = either die pure

assertBool :: String -> Bool -> IO ()
assertBool label condition
  | condition = pure ()
  | otherwise = die label

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
