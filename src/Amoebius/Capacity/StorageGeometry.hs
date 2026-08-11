{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure logical-to-physical geometry.  Every successful value retains the
-- scenarios and rounding operands used to derive its private byte witness.
module Amoebius.Capacity.StorageGeometry
  ( BookKeeperPolicy (..)
  , MinioPolicy (..)
  , VolumeGeometry (..)
  , StatefulSetClaimSlot (..)
  , DeclaredVolumeDemand (..)
  , GeometryWitness (..)
  , ProvisionedVolumeDemand (..)
  , UniformClaimWitness (..)
  , ObjectExtent (..)
  , ObjectStoreProducer (..)
  , ProvisionedObjectStoreLogicalPeak (..)
  , ObjectStoreAdmissionGatewayDemand (..)
  , MigrationDemand (..)
  , ProvisionedMigration (..)
  , NodeRootSupply (..)
  , ProvisionedNodeRootVolumeRequest (..)
  , PulsarDemand (..)
  , PulsarStorageWitness (..)
  , bookKeeperPhysicalDemand
  , minioPhysicalDemand
  , provisionVolume
  , uniformStatefulSetClaims
  , provisionObjectStoreProducer
  , mergeObjectStoreLogicalPeaks
  , provisionStorageMigration
  , provisionSchemaMigration
  , provisionRegistryBackendMigration
  , provisionNodeRootVolume
  , provisionPulsar
  ) where

import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (..)
  , BackingId (..)
  , FilesystemPresentation
  , StorageBacking (..)
  , StorageBudget
  , StorageError (..)
  , StorageWitness (..)
  , fitBacking
  , fitStorageBudget
  , presentBytes
  , roundAllocation
  , StorageAmount (..)
  )
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data BookKeeperPolicy = BookKeeperPolicy
  { bookKeeperEnsembleSize :: Natural
  , bookKeeperWriteQuorum :: Natural
  , bookKeeperAckQuorum :: Natural
  , bookKeeperJournalAndIndexBytesPerBookie :: Natural
  , bookKeeperFaultBound :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data MinioPolicy = MinioPolicy
  { minioErasureSets :: Natural
  , minioDataShards :: Natural
  , minioParityShards :: Natural
  , minioShardBlockBytes :: Natural
  , minioMetadataBytesPerDrive :: Natural
  , minioHealingWorkspaceBytesPerDrive :: Natural
  , minioFaultBoundPerSet :: Natural
  , minioConcurrentWriteSets :: Natural
  , minioFailedWriteSets :: Natural
  , minioMaximumWriteSetBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data VolumeGeometry
  = DirectGeometry Natural
  | BookKeeperGeometry BookKeeperPolicy
  | MinioGeometry MinioPolicy
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StatefulSetClaimSlot = StatefulSetClaimSlot
  { claimStatefulSet :: Text
  , claimTemplate :: Text
  , claimOrdinal :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data DeclaredVolumeDemand = DeclaredVolumeDemand
  { volumeDemandId :: Text
  , volumeClaim :: StatefulSetClaimSlot
  , volumeBacking :: StorageBacking
  , volumeLogicalBytes :: Natural
  , volumeGeometry :: VolumeGeometry
  , volumePresentation :: FilesystemPresentation
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data GeometryWitness = GeometryWitness
  { geometryLogicalBytes :: Natural
  , geometryPhysicalBytes :: Natural
  , geometryFailureScenarios :: [[Natural]]
  , geometryComponents :: Map Text Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedVolumeDemand = ProvisionedVolumeDemand
  { provisionedVolumeId :: Text
  , provisionedClaim :: StatefulSetClaimSlot
  , provisionedBacking :: BackingId
  , provisionedBytes :: Natural
  , provisionedGeometryWitness :: GeometryWitness
  , provisionedBackingWitness :: StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data UniformClaimWitness = UniformClaimWitness
  { uniformClaimBytesByBacking :: Map BackingId Natural
  , uniformMemberBytesByBacking :: Map BackingId Natural
  , uniformMembersByBacking :: Map BackingId Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObjectExtent = ObjectExtent
  { objectIdentity :: Text
  , objectBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObjectStoreProducer
  = AppBucketProducer Text [ObjectExtent] Natural
  | ContentProducer Text [ObjectExtent] Natural
  | RegistryProducer Text [ObjectExtent] Natural
  | PulsarOffloadProducer Text [ObjectExtent] Natural
  | PulumiCheckpointProducer Text [ObjectExtent] Natural
  | ControlPlaneStateProducer Text [ObjectExtent] Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedObjectStoreLogicalPeak = ProvisionedObjectStoreLogicalPeak
  { objectProducer :: Text
  , objectResidents :: Map Text Natural
  , objectTransientBytes :: Natural
  , objectAdmissionWitness :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObjectStoreAdmissionGatewayDemand = ObjectStoreAdmissionGatewayDemand
  { gatewayResidentBytes :: Natural
  , gatewayTransientBytes :: Natural
  , gatewayObjectCount :: Natural
  , gatewayWriters :: Set Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data MigrationDemand = MigrationDemand
  { migrationId :: Text
  , migrationOldBytes :: Natural
  , migrationNewBytes :: Natural
  , migrationWorkspaceBytes :: Natural
  , migrationTemporaryBytes :: Natural
  , migrationWalBytes :: Natural
  , migrationExecutorBytes :: Natural
  , migrationBacking :: StorageBacking
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedMigration = ProvisionedMigration
  { provisionedMigrationId :: Text
  , provisionedMigrationPeak :: Natural
  , provisionedMigrationWitness :: StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeRootSupply
  = InstanceStoreRoot StorageBacking
  | EphemeralRootEbs
      { rootEbsQuotaBytes :: Natural
      , rootEbsQuotaVolumes :: Natural
      , rootEbsPresentation :: FilesystemPresentation
      , rootEbsAllocation :: BackingAllocationPolicy
      }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedNodeRootVolumeRequest = ProvisionedNodeRootVolumeRequest
  { rootRequiredUsableBytes :: Natural
  , rootProvisionedBytes :: Natural
  , rootVolumeCount :: Natural
  , rootBackingWitness :: StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PulsarDemand = PulsarDemand
  { pulsarTopic :: Text
  , pulsarLogicalHotBytes :: Natural
  , pulsarDurableRetainedBytes :: Maybe Natural
  , pulsarBookKeeperPolicy :: BookKeeperPolicy
  , pulsarBookieBacking :: StorageBacking
  , pulsarDurableBudget :: StorageBudget
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PulsarStorageWitness = PulsarStorageWitness
  { pulsarHotWitness :: GeometryWitness
  , pulsarHotBackingWitness :: StorageWitness
  , pulsarDurableBackingWitness :: StorageWitness
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

bookKeeperPhysicalDemand :: BookKeeperPolicy -> Natural -> Either StorageError GeometryWitness
bookKeeperPhysicalDemand policy logicalBytes
  | ensemble == 0 = Left (InvalidStorageGeometry "BookKeeper ensemble must be non-zero")
  | writeQuorum == 0 || writeQuorum > ensemble = Left (InvalidStorageGeometry "BookKeeper write quorum is outside ensemble")
  | bookKeeperAckQuorum policy == 0 || bookKeeperAckQuorum policy > writeQuorum = Left (InvalidStorageGeometry "BookKeeper ack quorum is outside write quorum")
  | faultBound >= ensemble = Left (InvalidStorageGeometry "BookKeeper fault bound exhausts ensemble")
  | otherwise =
      Right
        GeometryWitness
          { geometryLogicalBytes = logicalBytes
          , geometryPhysicalBytes = baseBytes + reserves + recoveryBytes
          , geometryFailureScenarios = failureSubsets ensemble faultBound
          , geometryComponents =
              Map.fromList
                [ ("write-quorum", baseBytes)
                , ("journal-index", reserves)
                , ("re-replication", recoveryBytes)
                ]
          }
 where
  ensemble = bookKeeperEnsembleSize policy
  writeQuorum = bookKeeperWriteQuorum policy
  faultBound = bookKeeperFaultBound policy
  baseBytes = logicalBytes * writeQuorum
  reserves = ensemble * bookKeeperJournalAndIndexBytesPerBookie policy
  recoveryBytes = logicalBytes * faultBound

minioPhysicalDemand :: MinioPolicy -> Natural -> Either StorageError GeometryWitness
minioPhysicalDemand policy logicalBytes
  | sets == 0 || dataShards == 0 || blockBytes == 0 = Left (InvalidStorageGeometry "MinIO sets, data shards, and block bytes must be non-zero")
  | parityShards == 0 = Left (InvalidStorageGeometry "MinIO parity shards must be non-zero")
  | faultBound > parityShards = Left (InvalidStorageGeometry "MinIO fault bound exceeds parity")
  | otherwise =
      Right
        GeometryWitness
          { geometryLogicalBytes = logicalBytes
          , geometryPhysicalBytes = resident + metadata + healing + orphanAndInflight
          , geometryFailureScenarios = crossSetScenarios sets faultBound
          , geometryComponents =
              Map.fromList
                [ ("stripe-data-parity", resident)
                , ("metadata", metadata)
                , ("healing", healing)
                , ("concurrent-orphan", orphanAndInflight)
                ]
          }
 where
  sets = minioErasureSets policy
  dataShards = minioDataShards policy
  parityShards = minioParityShards policy
  totalShards = dataShards + parityShards
  blockBytes = minioShardBlockBytes policy
  stripes = ceilDiv logicalBytes (dataShards * blockBytes)
  resident = stripes * totalShards * blockBytes
  drives = sets * totalShards
  metadata = drives * minioMetadataBytesPerDrive policy
  faultBound = minioFaultBoundPerSet policy
  healing = sets * faultBound * minioHealingWorkspaceBytesPerDrive policy + ceilDiv (resident * faultBound) dataShards
  orphanAndInflight =
    (minioConcurrentWriteSets policy + minioFailedWriteSets policy)
      * minioMaximumWriteSetBytes policy
      * totalShards
      `div` dataShards

provisionVolume :: DeclaredVolumeDemand -> Either StorageError ProvisionedVolumeDemand
provisionVolume demand = do
  geometry <- geometryFor (volumeGeometry demand) (volumeLogicalBytes demand)
  let presented = presentBytes (volumePresentation demand) (geometryPhysicalBytes geometry)
      rounded = roundAllocation (backingAllocation (volumeBacking demand)) presented
  backingWitness <- fitBacking (volumeBacking demand) rounded
  pure
    ProvisionedVolumeDemand
      { provisionedVolumeId = volumeDemandId demand
      , provisionedClaim = volumeClaim demand
      , provisionedBacking = backingId (volumeBacking demand)
      , provisionedBytes = rounded
      , provisionedGeometryWitness = geometry
      , provisionedBackingWitness = backingWitness
      }

uniformStatefulSetClaims :: [ProvisionedVolumeDemand] -> Either StorageError UniformClaimWitness
uniformStatefulSetClaims demands = do
  let groups = Map.fromListWith (<>) [(provisionedBacking demand, [demand]) | demand <- demands]
      memberBytes = fmap (maximumTotal . fmap provisionedBytes) groups
      members = fmap (fromIntegral . length) groups
      debit = Map.intersectionWith (*) memberBytes members
  mapM_ (checkGroup debit) (Map.toList groups)
  pure (UniformClaimWitness debit memberBytes members)
 where
  checkGroup debit (owner, group) = case group of
    [] -> Right ()
    firstDemand : _ ->
      let backing = volumeBackingFrom firstDemand
          required = Map.findWithDefault 0 owner debit
       in fitBacking backing required >> Right ()
  -- The backing witness retained by each provisioned demand already proves
  -- the backing identity/capacity.  Recovering the capacity from that witness
  -- avoids accepting a second authored number here.
  volumeBackingFrom demand =
    StorageBacking
      { backingId = provisionedBacking demand
      , backingCapacityBytes = amountBytes (witnessAvailable (provisionedBackingWitness demand))
      , backingAllocation = BackingAllocationPolicy 0 1
      }

provisionObjectStoreProducer :: ObjectStoreProducer -> Either StorageError ProvisionedObjectStoreLogicalPeak
provisionObjectStoreProducer producer =
  let (name, extents, transient, arm) = producerParts producer
      residents = foldObjects extents
   in if name == ""
        then Left (InvalidStorageGeometry "object-store producer identity is empty")
        else
          Right
            ProvisionedObjectStoreLogicalPeak
              { objectProducer = name
              , objectResidents = residents
              , objectTransientBytes = transient
              , objectAdmissionWitness = arm <> ":" <> name
              }

mergeObjectStoreLogicalPeaks
  :: Set Text
  -> [ProvisionedObjectStoreLogicalPeak]
  -> Either StorageError ObjectStoreAdmissionGatewayDemand
mergeObjectStoreLogicalPeaks sourceInventory producers
  | sourceInventory /= producerInventory =
      Left
        ( ObjectProducerInventoryMismatch
            (Set.toAscList sourceInventory)
            (Set.toAscList producerInventory)
        )
  | otherwise = do
      objects <- mergeObjects Map.empty producers
      pure
        ObjectStoreAdmissionGatewayDemand
          { gatewayResidentBytes = sum (Map.elems objects)
          , gatewayTransientBytes = sum (fmap objectTransientBytes producers)
          , gatewayObjectCount = fromIntegral (Map.size objects)
          , gatewayWriters = producerInventory
          }
 where
  producerInventory = Set.fromList (fmap objectProducer producers)

provisionStorageMigration :: MigrationDemand -> Either StorageError ProvisionedMigration
provisionStorageMigration = provisionMigration

provisionSchemaMigration :: MigrationDemand -> Either StorageError ProvisionedMigration
provisionSchemaMigration = provisionMigration

provisionRegistryBackendMigration :: MigrationDemand -> Either StorageError ProvisionedMigration
provisionRegistryBackendMigration = provisionMigration

provisionNodeRootVolume
  :: Natural
  -> [Natural]
  -> NodeRootSupply
  -> Either StorageError ProvisionedNodeRootVolumeRequest
provisionNodeRootVolume systemReserve carves supply = case supply of
  InstanceStoreRoot backing -> do
    witness <- fitBacking backing requiredUsable
    pure (ProvisionedNodeRootVolumeRequest requiredUsable requiredUsable 1 witness)
  EphemeralRootEbs quotaBytes quotaVolumes presentation allocation -> do
    let provisioned = roundAllocation allocation (presentBytes presentation requiredUsable)
        syntheticBacking = StorageBacking (BackingId "nodeRootStorage") quotaBytes allocation
    if quotaVolumes < 1
      then Left (ObjectCountOverQuota "nodeRootStorage" 1 quotaVolumes)
      else do
        witness <- fitBacking syntheticBacking provisioned
        pure (ProvisionedNodeRootVolumeRequest requiredUsable provisioned 1 witness)
 where
  requiredUsable = systemReserve + sum carves

provisionPulsar :: PulsarDemand -> Either StorageError PulsarStorageWitness
provisionPulsar demand = do
  durable <- case pulsarDurableRetainedBytes demand of
    Nothing -> Left (PulsarDurableCeilingUnbounded (pulsarTopic demand))
    Just bytes -> Right bytes
  hot <- bookKeeperPhysicalDemand (pulsarBookKeeperPolicy demand) (pulsarLogicalHotBytes demand)
  hotFit <- fitBacking (pulsarBookieBacking demand) (geometryPhysicalBytes hot)
  durableFit <- fitStorageBudget (pulsarDurableBudget demand) (StorageAmount durable 1)
  pure (PulsarStorageWitness hot hotFit durableFit)

geometryFor :: VolumeGeometry -> Natural -> Either StorageError GeometryWitness
geometryFor geometry logicalBytes = case geometry of
  DirectGeometry replicas
    | replicas == 0 -> Left (InvalidStorageGeometry "direct volume replica count must be non-zero")
    | otherwise ->
        Right
          GeometryWitness
            { geometryLogicalBytes = logicalBytes
            , geometryPhysicalBytes = logicalBytes * replicas
            , geometryFailureScenarios = [[]]
            , geometryComponents = Map.singleton "direct-replicas" (logicalBytes * replicas)
            }
  BookKeeperGeometry policy -> bookKeeperPhysicalDemand policy logicalBytes
  MinioGeometry policy -> minioPhysicalDemand policy logicalBytes

provisionMigration :: MigrationDemand -> Either StorageError ProvisionedMigration
provisionMigration demand = do
  let peak =
        migrationOldBytes demand
          + migrationNewBytes demand
          + migrationWorkspaceBytes demand
          + migrationTemporaryBytes demand
          + migrationWalBytes demand
          + migrationExecutorBytes demand
  witness <- fitBacking (migrationBacking demand) peak
  pure (ProvisionedMigration (migrationId demand) peak witness)

producerParts :: ObjectStoreProducer -> (Text, [ObjectExtent], Natural, Text)
producerParts producer = case producer of
  AppBucketProducer name objects transient -> (name, objects, transient, "app")
  ContentProducer name objects transient -> (name, objects, transient, "content")
  RegistryProducer name objects transient -> (name, objects, transient, "registry")
  PulsarOffloadProducer name objects transient -> (name, objects, transient, "pulsar-offload")
  PulumiCheckpointProducer name objects transient -> (name, objects, transient, "pulumi-checkpoint")
  ControlPlaneStateProducer name objects transient -> (name, objects, transient, "control-plane-state")

foldObjects :: [ObjectExtent] -> Map Text Natural
foldObjects extents = Map.fromListWith max [(objectIdentity extent, objectBytes extent) | extent <- extents]

mergeObjects
  :: Map Text Natural
  -> [ProvisionedObjectStoreLogicalPeak]
  -> Either StorageError (Map Text Natural)
mergeObjects accumulated producers = case producers of
  [] -> Right accumulated
  producer : remaining -> do
    next <- mergeOne accumulated (Map.toList (objectResidents producer))
    mergeObjects next remaining
 where
  mergeOne current objects = case objects of
    [] -> Right current
    (identity, bytes) : rest -> case Map.lookup identity current of
      Nothing -> mergeOne (Map.insert identity bytes current) rest
      Just prior
        | prior == bytes -> mergeOne current rest
        | otherwise -> Left (ObjectIdentityConflict identity prior bytes)

failureSubsets :: Natural -> Natural -> [[Natural]]
failureSubsets population maximumFailures =
  concatMap (`choose` [0 .. population - 1]) [0 .. maximumFailures]

crossSetScenarios :: Natural -> Natural -> [[Natural]]
crossSetScenarios sets maximumPerSet = sequence (replicate (fromIntegral sets) [0 .. maximumPerSet])

choose :: Natural -> [Natural] -> [[Natural]]
choose count values
  | count == 0 = [[]]
  | otherwise = case values of
      [] -> []
      value : rest -> fmap (value :) (choose (count - 1) rest) <> choose count rest

maximumTotal :: [Natural] -> Natural
maximumTotal values = case sortOn id values of
  [] -> 0
  first : rest -> go first rest
 where
  go current remaining = case remaining of
    [] -> current
    value : tailValues -> go value tailValues

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator
  | denominator == 0 = 0
  | otherwise = (numerator + denominator - 1) `div` denominator
