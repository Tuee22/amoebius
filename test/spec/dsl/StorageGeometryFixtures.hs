{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryFixtures
  ( StorageFixture (..)
  , storageFixtures
  , storagePositiveRows
  , allocation
  , backing
  , bookKeeperPolicy
  , minioPolicy
  , cachePopulation
  , storageTag
  ) where

import Amoebius.Capacity.ServiceStorage
  ( CacheAsset (..)
  , CachePlacement (..)
  , CachePopulationDemand (..)
  , ControlPlaneStorageDemand (..)
  , PatroniSqlDemand (..)
  , RegistryStorageDemand (..)
  , VaultStorageDemand (..)
  , ZooKeeperMetadataStoreDemand (..)
  , provisionCacheDemand
  , provisionControlPlaneStorage
  , provisionPatroniSql
  , provisionZooKeeperMetadataStore
  , registryStoragePeak
  , vaultStoragePeak
  )
import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (..)
  , BackingId (..)
  , BackupDemand (..)
  , BudgetId (..)
  , FilesystemPresentation (..)
  , PoolKind (..)
  , RestoreDemand (..)
  , StorageAmount (..)
  , StorageBacking (..)
  , StorageBudget (..)
  , StorageError (..)
  , fitStorageBudget
  , provisionBackup
  , provisionRestore
  , validateDisjointPools
  )
import Amoebius.Capacity.StorageGeometry
  ( BookKeeperPolicy (..)
  , DeclaredVolumeDemand (..)
  , GeometryWitness (..)
  , MigrationDemand (..)
  , MinioPolicy (..)
  , NodeRootSupply (..)
  , ObjectExtent (..)
  , ObjectStoreProducer (..)
  , PulsarDemand (..)
  , ProvisionedVolumeDemand
  , StatefulSetClaimSlot (..)
  , VolumeGeometry (..)
  , mergeObjectStoreLogicalPeaks
  , minioPhysicalDemand
  , provisionNodeRootVolume
  , provisionObjectStoreProducer
  , provisionPulsar
  , provisionRegistryBackendMigration
  , provisionSchemaMigration
  , provisionStorageMigration
  , provisionVolume
  , uniformStatefulSetClaims
  )
import Amoebius.Capacity.StorageScaling
  ( ObservedStorageScalingSnapshot (..)
  , mkProvisionedStorageScalingEnvelope
  , planStorageScaling
  )
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data StorageFixture = StorageFixture
  { storageFixtureVariant :: Text
  , storageFixtureFamily :: Text
  , storageFixtureOperation :: Text
  , storageFixtureCatalog :: Text
  , storageFixtureExpected :: Text
  , storageFixtureNegative :: Either Text ()
  , storageFixtureTwin :: Text
  , storageFixturePositive :: Either Text ()
  }

storageFixtures :: [StorageFixture]
storageFixtures =
  [ fixture "direct-backing" "illegal_store_over_backing" "fit" "3.19:logical-physical-fit" "StorageOverBacking:direct" (volumeResult directOver) (volumeResult directFit)
  , fixture "bookkeeper-recovery" "illegal_hot_tier_over_bookie" "bookkeeper" "3.19:logical-physical-fit" "StorageOverBacking:bookkeeper" (volumeResult bookKeeperOver) (volumeResult bookKeeperFit)
  , fixture "minio-parity-healing-orphan" "illegal_store_over_backing" "minio" "3.19:logical-physical-fit" "StorageOverBacking:minio" (volumeResult minioOver) (volumeResult minioFit)
  , fixture "complete-failure-scenarios" "illegal_store_over_backing" "failure-scenarios" "3.19:logical-physical-fit" "FailureScenarioProductMismatch" (failureScenarioResult 1) (failureScenarioResult 2)
  , fixture "filesystem-overhead-rounding" "illegal_store_over_backing" "presentation" "3.19:logical-physical-fit" "StorageOverBacking:filesystem" (volumeResult filesystemOver) (volumeResult filesystemFit)
  , fixture "backing-allocation-rounding" "illegal_store_over_backing" "allocation" "3.19:logical-physical-fit" "StorageOverBacking:allocation" (volumeResult allocationOver) (volumeResult allocationFit)
  , fixture "uniform-claim-per-backing" "illegal_store_over_backing" "uniform-claims" "3.19:logical-physical-fit" "StorageOverBacking:uniform" uniformOver uniformFit
  , fixture "registry-upload-partials" "illegal_store_over_backing" "registry" "3.19:logical-physical-fit" "StorageOverBacking:registry" (serviceResult (registryStoragePeak registryOver)) (serviceResult (registryStoragePeak registryFit))
  , fixture "zookeeper-recovery" "illegal_store_over_backing" "zookeeper" "3.19:logical-physical-fit" "StorageOverBacking:zookeeper" (serviceResult (provisionZooKeeperMetadataStore zooKeeperOver)) (serviceResult (provisionZooKeeperMetadataStore zooKeeperFit))
  , fixture "patroni-wal-failover" "illegal_store_over_backing" "patroni" "3.19:logical-physical-fit" "StorageOverBacking:patroni" (serviceResult (provisionPatroniSql patroniOver)) (serviceResult (provisionPatroniSql patroniFit))
  , fixture "vault-raft-audit" "illegal_store_over_backing" "vault" "3.19:logical-physical-fit" "StorageOverBacking:vault" (serviceResult (vaultStoragePeak vaultOver)) (serviceResult (vaultStoragePeak vaultFit))
  , fixture "storage-migration-highwater" "illegal_store_over_backing" "storage-migration" "3.19:logical-physical-fit" "StorageOverBacking:migration" (migrationResult provisionStorageMigration migrationOver) (migrationResult provisionStorageMigration migrationFit)
  , fixture "schema-migration-highwater" "illegal_store_over_backing" "schema-migration" "3.19:logical-physical-fit" "StorageOverBacking:migration" (migrationResult provisionSchemaMigration migrationOver) (migrationResult provisionSchemaMigration migrationFit)
  , fixture "registry-backend-migration" "illegal_store_over_backing" "registry-migration" "3.19:logical-physical-fit" "StorageOverBacking:migration" (migrationResult provisionRegistryBackendMigration migrationOver) (migrationResult provisionRegistryBackendMigration migrationFit)
  , fixture "object-producer-inventory" "illegal_store_over_backing" "object-inventory" "3.19:logical-physical-fit" "ObjectProducerInventoryMismatch" objectInventoryOver objectInventoryFit
  , fixture "object-identity-conflict" "illegal_store_over_backing" "object-conflict" "3.19:logical-physical-fit" "ObjectIdentityConflict:shared" objectConflictOver objectConflictFit
  , fixture "object-count-quota" "illegal_store_over_backing" "object-count" "3.19:logical-physical-fit" "ObjectCountOverQuota:provider" objectCountOver objectCountFit
  , fixture "backup-medium-fit" "illegal_store_over_backing" "backup" "3.53:backup-medium-fit" "StorageOverBacking:backup" (witnessResult (provisionBackup backupOver)) (witnessResult (provisionBackup backupFit))
  , fixture "disjoint-capacity-pool" "illegal_store_over_backing" "pool-ownership" "3.60:disjoint-capacity-pool" "DisjointCapacityPoolViolation:shared-pool" disjointPoolOver disjointPoolFit
  , fixture "restore-target-fit" "illegal_store_over_backing" "restore" "3.67:restore-target-fit" "StorageOverBacking:restore" (witnessResult (provisionRestore restoreOver)) (witnessResult (provisionRestore restoreFit))
  , fixture "pulsar-durable-total" "illegal_topic_time_only_offload" "pulsar-durable" "3.19:logical-physical-fit" "PulsarDurableCeilingUnbounded:events" (pulsarResult durableUnbounded) (pulsarResult durableBounded)
  , fixture "pulsar-hot-tier-ceiling" "illegal_hot_tier_over_bookie" "pulsar-hot" "3.19:logical-physical-fit" "StorageOverBacking:bookie" (pulsarResult hotOver) (pulsarResult hotFit)
  , fixture "native-cache-pool" "illegal_cache_over_local_pool" "cache-native" "3.60:disjoint-capacity-pool" "StorageOverBacking:cache" (cacheResult nativeCacheOver) (cacheResult nativeCacheFit)
  , fixture "incluster-cache-budget" "illegal_incluster_cache_bound_mismatch" "cache-incluster" "3.19:logical-physical-fit" "CacheBudgetNestingViolation:models" (cacheResult inClusterPeakOver) (cacheResult inClusterFit)
  , fixture "incluster-cache-emptydir" "illegal_incluster_cache_bound_mismatch" "cache-incluster" "3.19:logical-physical-fit" "CacheBudgetNestingViolation:models" (cacheResult inClusterEmptyDirOver) (cacheResult inClusterFit)
  , fixture "instance-store-root" "illegal_store_over_backing" "node-root" "3.60:disjoint-capacity-pool" "StorageOverBacking:root" (rootResult instanceRootOver) (rootResult instanceRootFit)
  , fixture "root-ebs-quota" "illegal_store_over_backing" "node-root" "3.60:disjoint-capacity-pool" "StorageOverBacking:nodeRootStorage" (rootResult ebsRootOver) (rootResult ebsRootFit)
  , fixture "control-plane-transition" "illegal_store_over_backing" "control-plane" "3.19:logical-physical-fit" "StorageOverBacking:control-plane" (serviceResult (provisionControlPlaneStorage controlPlaneOver)) (serviceResult (provisionControlPlaneStorage controlPlaneFit))
  , fixture "scaling-fingerprint" "illegal_store_over_backing" "storage-scaling" "3.19:logical-physical-fit" "ScalingSnapshotMismatch:expected:stale" scalingFingerprintOver scalingFingerprintFit
  , fixture "scaling-shrink-highwater" "illegal_store_over_backing" "storage-scaling" "3.19:logical-physical-fit" "ScalingEnvelopeViolation" scalingHighWaterOver scalingHighWaterFit
  ]

storagePositiveRows :: [(Text, Either Text ())]
storagePositiveRows =
  [ ("legal_multisubstrate_cluster", sequenceResults [volumeResult directFit, volumeResult minioFit, uniformFit, serviceResult (provisionZooKeeperMetadataStore zooKeeperFit), serviceResult (provisionPatroniSql patroniFit), serviceResult (vaultStoragePeak vaultFit), serviceResult (provisionControlPlaneStorage controlPlaneFit)])
  , ("legal_managed_eks", sequenceResults [rootResult instanceRootFit, rootResult ebsRootFit, pulsarResult hotFit])
  ]

fixture :: Text -> Text -> Text -> Text -> Text -> Either Text () -> Either Text () -> StorageFixture
fixture variant family operation catalog expected negative positive =
  StorageFixture variant family operation catalog expected negative ("legal_" <> variant) positive

allocation :: BackingAllocationPolicy
allocation = BackingAllocationPolicy 0 1

backing :: Text -> Natural -> StorageBacking
backing name bytes = StorageBacking (BackingId name) bytes allocation

claim :: Text -> Natural -> StatefulSetClaimSlot
claim name ordinal = StatefulSetClaimSlot name "data" ordinal

bookKeeperPolicy :: BookKeeperPolicy
bookKeeperPolicy = BookKeeperPolicy 3 2 2 5 1

minioPolicy :: MinioPolicy
minioPolicy = MinioPolicy 1 2 1 10 2 5 1 1 1 20

volume :: Text -> Natural -> StorageBacking -> VolumeGeometry -> FilesystemPresentation -> DeclaredVolumeDemand
volume name logical owner geometry presentation = DeclaredVolumeDemand name (claim name 0) owner logical geometry presentation

directOver, directFit, bookKeeperOver, bookKeeperFit, minioOver, minioFit, filesystemOver, filesystemFit, allocationOver, allocationFit :: DeclaredVolumeDemand
directOver = volume "direct" 101 (backing "direct" 100) (DirectGeometry 1) BlockPresentation
directFit = volume "direct" 100 (backing "direct" 100) (DirectGeometry 1) BlockPresentation
bookKeeperOver = volume "bookkeeper" 100 (backing "bookkeeper" 314) (BookKeeperGeometry bookKeeperPolicy) BlockPresentation
bookKeeperFit = bookKeeperOver {volumeBacking = backing "bookkeeper" 315}
minioOver = volume "minio" 100 (backing "minio" 295) (MinioGeometry minioPolicy) BlockPresentation
minioFit = volume "minio" 100 (backing "minio" 296) (MinioGeometry minioPolicy) BlockPresentation
filesystemOver = volume "filesystem" 100 fsOverBacking (DirectGeometry 1) (FilesystemPresentation "ext4-v1" 1000)
filesystemFit = volume "filesystem" 100 fsFitBacking (DirectGeometry 1) (FilesystemPresentation "ext4-v1" 1000)
allocationOver = volume "allocation" 65 allocationOverBacking (DirectGeometry 1) BlockPresentation
allocationFit = allocationOver {volumeBacking = allocationFitBacking}

fsOverBacking, fsFitBacking :: StorageBacking
fsOverBacking = StorageBacking (BackingId "filesystem") 109 (BackingAllocationPolicy 0 1)
fsFitBacking = StorageBacking (BackingId "filesystem") 110 (BackingAllocationPolicy 0 1)

allocationOverBacking, allocationFitBacking :: StorageBacking
allocationOverBacking = StorageBacking (BackingId "allocation") 127 (BackingAllocationPolicy 0 64)
allocationFitBacking = allocationOverBacking {backingCapacityBytes = 128}

failureScenarioResult :: Int -> Either Text ()
failureScenarioResult expected = case minioPhysicalDemand minioPolicy 100 of
  Left problem -> Left (storageTag problem)
  Right witness
    | length (geometryFailureScenarios witness) == expected -> Right ()
    | otherwise -> Left "FailureScenarioProductMismatch"

uniformOver, uniformFit :: Either Text ()
uniformOver = uniformResult 150
uniformFit = uniformResult 160

uniformResult :: Natural -> Either Text ()
uniformResult capacity = do
  first <- volumeResultValue (volume "uniform-a" 60 (backing "uniform" capacity) (DirectGeometry 1) BlockPresentation)
  second <- volumeResultValue (volume "uniform-b" 80 (backing "uniform" capacity) (DirectGeometry 1) BlockPresentation)
  resultUnit (uniformStatefulSetClaims [first, second])

registryOver, registryFit :: RegistryStorageDemand
registryOver = RegistryStorageDemand "registry" [("sha", 50), ("sha", 50)] 2 20 1 (backing "registry" 109)
registryFit = registryOver {registryBacking = backing "registry" 110}

zooKeeperOver, zooKeeperFit :: ZooKeeperMetadataStoreDemand
zooKeeperOver = ZooKeeperMetadataStoreDemand "zookeeper" 3 10 10 10 10 (backing "zookeeper" 119)
zooKeeperFit = zooKeeperOver {zooKeeperBacking = backing "zookeeper" 120}

patroniOver, patroniFit :: PatroniSqlDemand
patroniOver = PatroniSqlDemand "patroni" 50 20 10 10 10 (backing "patroni" 99)
patroniFit = patroniOver {patroniBacking = backing "patroni" 100}

vaultOver, vaultFit :: VaultStorageDemand
vaultOver = VaultStorageDemand "vault" 20 10 10 20 20 10 10 2 (backing "vault" 119)
vaultFit = vaultOver {vaultBacking = backing "vault" 120}

migrationOver, migrationFit :: MigrationDemand
migrationOver = MigrationDemand "migration" 10 10 10 10 10 10 (backing "migration" 59)
migrationFit = migrationOver {migrationBacking = backing "migration" 60}

sixProducers :: [ObjectStoreProducer]
sixProducers =
  [ AppBucketProducer "app" [ObjectExtent "app-object" 10] 1
  , ContentProducer "content" [ObjectExtent "content-object" 10] 1
  , RegistryProducer "registry" [ObjectExtent "registry-object" 10] 1
  , PulsarOffloadProducer "pulsar" [ObjectExtent "pulsar-object" 10] 1
  , PulumiCheckpointProducer "pulumi" [ObjectExtent "pulumi-object" 10] 1
  , ControlPlaneStateProducer "control-plane" [ObjectExtent "control-object" 10] 1
  ]

objectInventoryOver, objectInventoryFit, objectConflictOver, objectConflictFit :: Either Text ()
objectInventoryOver = objectMergeResult (Set.fromList ["app", "content", "registry", "pulsar", "pulumi"]) sixProducers
objectInventoryFit = objectMergeResult (Set.fromList ["app", "content", "registry", "pulsar", "pulumi", "control-plane"]) sixProducers
objectConflictOver = objectMergeResult (Set.fromList ["a", "b"]) [AppBucketProducer "a" [ObjectExtent "shared" 10] 0, ContentProducer "b" [ObjectExtent "shared" 11] 0]
objectConflictFit = objectMergeResult (Set.fromList ["a", "b"]) [AppBucketProducer "a" [ObjectExtent "shared" 10] 0, ContentProducer "b" [ObjectExtent "shared" 10] 0]

objectCountOver, objectCountFit :: Either Text ()
objectCountOver = witnessResult (fitStorageBudget providerBudget (StorageAmount 100 2))
objectCountFit = witnessResult (fitStorageBudget providerBudget (StorageAmount 100 1))

providerBudget :: StorageBudget
providerBudget = ProviderObjectQuota (BudgetId "objects") "provider" 100 1

backupOver, backupFit :: BackupDemand
backupOver = BackupDemand "backup" 50 10 2 (backing "backup" 129)
backupFit = backupOver {backupMedium = backing "backup" 130}

restoreOver, restoreFit :: RestoreDemand
restoreOver = RestoreDemand "restore" 100 20 (backing "restore" 119)
restoreFit = restoreOver {restoreTarget = backing "restore" 120}

disjointPoolOver, disjointPoolFit :: Either Text ()
disjointPoolOver = resultUnit (validateDisjointPools [(DurablePool, BackingId "shared-pool"), (CachePool, BackingId "shared-pool")])
disjointPoolFit = resultUnit (validateDisjointPools [(DurablePool, BackingId "durable-pool"), (CachePool, BackingId "cache-pool")])

hotOver, hotFit, durableUnbounded, durableBounded :: PulsarDemand
hotOver = pulsarDemand (Just 100) (backing "bookie" 314)
hotFit = pulsarDemand (Just 100) (backing "bookie" 315)
durableUnbounded = pulsarDemand Nothing (backing "bookie" 315)
durableBounded = pulsarDemand (Just 100) (backing "bookie" 315)

pulsarDemand :: Maybe Natural -> StorageBacking -> PulsarDemand
pulsarDemand durable hotBacking =
  PulsarDemand
    "events"
    100
    durable
    bookKeeperPolicy
    hotBacking
    (FixedBackingBudget (BudgetId "durable") (BackingId "durable") 100)

cachePopulation :: CachePopulationDemand
cachePopulation =
  CachePopulationDemand
    "models"
    [ CacheAsset "model-a" "digest-a" 50 20
    , CacheAsset "model-a-copy" "digest-a" 50 20
    , CacheAsset "model-b" "digest-b" 30 40
    ]
    1

nativeCacheOver, nativeCacheFit, inClusterPeakOver, inClusterEmptyDirOver, inClusterFit :: Either StorageError ()
nativeCacheOver = discardStorage (provisionCacheDemand cachePopulation (NativeCache 120 (backing "cache" 119)))
nativeCacheFit = discardStorage (provisionCacheDemand cachePopulation (NativeCache 120 (backing "cache" 120)))
inClusterPeakOver = discardStorage (provisionCacheDemand cachePopulation (InClusterCache 119 120))
inClusterEmptyDirOver = discardStorage (provisionCacheDemand cachePopulation (InClusterCache 121 120))
inClusterFit = discardStorage (provisionCacheDemand cachePopulation (InClusterCache 120 120))

instanceRootOver, instanceRootFit, ebsRootOver, ebsRootFit :: Either StorageError ()
instanceRootOver = discardStorage (provisionNodeRootVolume 100 [50] (InstanceStoreRoot (backing "root" 149)))
instanceRootFit = discardStorage (provisionNodeRootVolume 100 [50] (InstanceStoreRoot (backing "root" 150)))
ebsRootOver = discardStorage (provisionNodeRootVolume 100 [50] (EphemeralRootEbs 191 1 (FilesystemPresentation "ext4-v1" 1000) (BackingAllocationPolicy 0 64)))
ebsRootFit = discardStorage (provisionNodeRootVolume 100 [50] (EphemeralRootEbs 192 1 (FilesystemPresentation "ext4-v1" 1000) (BackingAllocationPolicy 0 64)))

controlPlaneOver, controlPlaneFit :: ControlPlaneStorageDemand
controlPlaneOver = ControlPlaneStorageDemand "control-plane" 20 10 2 5 1 15 20 5 1 (backing "control-plane" 134)
controlPlaneFit = controlPlaneOver {controlPlaneBacking = backing "control-plane" 135}

scalingFingerprintOver, scalingFingerprintFit, scalingHighWaterOver, scalingHighWaterFit :: Either Text ()
scalingFingerprintOver = scalingResult 80 "expected" "stale" 200
scalingFingerprintFit = scalingResult 120 "expected" "expected" 0
scalingHighWaterOver = scalingResult 80 "expected" "expected" 199
scalingHighWaterFit = scalingResult 80 "expected" "expected" 200

scalingResult :: Natural -> Text -> Text -> Natural -> Either Text ()
scalingResult desired expected observed highWater = case mkProvisionedStorageScalingEnvelope expected (BackingId "scale") desired 150 300 of
  Left problem -> Left (storageTag problem)
  Right envelope -> resultUnit (planStorageScaling envelope (ObservedStorageScalingSnapshot observed 120 100 200 highWater))

volumeResult :: DeclaredVolumeDemand -> Either Text ()
volumeResult = resultUnit . provisionVolume

volumeResultValue :: DeclaredVolumeDemand -> Either Text ProvisionedVolumeDemand
volumeResultValue demand = case provisionVolume demand of
  Left problem -> Left (storageTag problem)
  Right value -> Right value

serviceResult :: Either StorageError a -> Either Text ()
serviceResult = resultUnit

migrationResult :: (MigrationDemand -> Either StorageError a) -> MigrationDemand -> Either Text ()
migrationResult operation = resultUnit . operation

pulsarResult :: PulsarDemand -> Either Text ()
pulsarResult = resultUnit . provisionPulsar

cacheResult :: Either StorageError a -> Either Text ()
cacheResult = resultUnit

rootResult :: Either StorageError a -> Either Text ()
rootResult = resultUnit

witnessResult :: Either StorageError a -> Either Text ()
witnessResult = resultUnit

objectMergeResult :: Set.Set Text -> [ObjectStoreProducer] -> Either Text ()
objectMergeResult inventory producers = do
  provisioned <- mapM (mapStorage . provisionObjectStoreProducer) producers
  resultUnit (mergeObjectStoreLogicalPeaks inventory provisioned)

mapStorage :: Either StorageError a -> Either Text a
mapStorage value = case value of
  Left problem -> Left (storageTag problem)
  Right result -> Right result

resultUnit :: Either StorageError a -> Either Text ()
resultUnit value = case value of
  Left problem -> Left (storageTag problem)
  Right _ -> Right ()

discardStorage :: Either StorageError a -> Either StorageError ()
discardStorage value = case value of
  Left problem -> Left problem
  Right _ -> Right ()

sequenceResults :: [Either Text ()] -> Either Text ()
sequenceResults = foldr (>>) (Right ())

storageTag :: StorageError -> Text
storageTag problem = case problem of
  StorageOverBacking (BackingId owner) _ _ -> "StorageOverBacking:" <> owner
  ObjectCountOverQuota owner _ _ -> "ObjectCountOverQuota:" <> owner
  PulsarDurableCeilingUnbounded topic -> "PulsarDurableCeilingUnbounded:" <> topic
  CacheBudgetNestingViolation name _ _ -> "CacheBudgetNestingViolation:" <> name
  ObjectProducerInventoryMismatch _ _ -> "ObjectProducerInventoryMismatch"
  ObjectIdentityConflict identity _ _ -> "ObjectIdentityConflict:" <> identity
  DisjointCapacityPoolViolation (BackingId owner) _ _ -> "DisjointCapacityPoolViolation:" <> owner
  ScalingSnapshotMismatch expected observed -> "ScalingSnapshotMismatch:" <> expected <> ":" <> observed
  ScalingEnvelopeViolation _ -> "ScalingEnvelopeViolation"
  InvalidStorageGeometry message -> "InvalidStorageGeometry:" <> Text.take 24 message
