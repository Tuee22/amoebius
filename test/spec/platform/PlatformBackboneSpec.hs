{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.ServiceStorage
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
import Amoebius.Platform.Backbone
import Amoebius.Platform.LoadBalancer
import Amoebius.Platform.Minio
import Amoebius.Platform.Pulsar
import Amoebius.Platform.Registry
import Amoebius.Platform.Types
import Control.Monad (foldM)
import Data.Aeson (encode)
import Data.ByteString.Lazy.Char8 qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Numeric.Natural (Natural)
import System.Environment (getArgs, lookupEnv)
import System.Exit (die)

main :: IO ()
main = do
  arguments <- getArgs
  minio <- requireRight (provisionMinio minioDemand)
  registry <- requireRight (provisionRegistryRehome registryDemand migrationDemand "http://minio.platform-system.svc:9000" "registry")
  pulsar <- requireRight (provisionPulsarBackbone pulsarDemand)
  loadBalancer <- requireRight (provisionLoadBalancer loadBalancerPlan)
  case arguments of
    ["--render-plan"] -> do
      runtimeImage <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE" privateImage
      runtimeAddress <- environmentText "AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_ADDRESS" (loadBalancerAddress loadBalancerPlan)
      let authored = renderBackbone loadBalancer minio pulsar <> renderRegistryRehome privateImage registryResources registry
      Lazy.putStr (encode (fmap (materializeRuntimePlan runtimeImage runtimeAddress) authored))
    [] -> do
      verifyMinio minio
      verifyRegistry registry
      verifyPulsar pulsar
      verifyBackbone minio pulsar
      putStrLn "platform-backbone-spec: PASS (HA shape, physical storage, verified registry rehome, size offload, readiness DAG)"
    _ -> die "usage: platform-backbone-spec [--render-plan]"

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
  assertEqual "Phase-26 peak preserved" 49152 (registryOriginalPeak provision)

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
          else objectArguments object
    }

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
    "distribution"
    [("sha256:layer", 8192), ("sha256:config", 4096), ("sha256:manifest", 4096)]
    2
    8192
    2
    (StorageBacking (BackingId "registry-source") 67108864 (BackingAllocationPolicy 0 4096))

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
