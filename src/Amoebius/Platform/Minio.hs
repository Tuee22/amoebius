{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Minio
  ( MinioDemand (..)
  , ProvisionedMinio (..)
  , provisionMinio
  , renderMinio
  ) where

import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
import Amoebius.Platform.Types
import Data.Set (Set)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data MinioDemand = MinioDemand
  { minioName :: Text
  , minioImage :: Text
  , minioReplicas :: Natural
  , minioInventory :: Set Text
  , minioProducers :: [ObjectStoreProducer]
  , minioPolicy :: MinioPolicy
  , minioPresentation :: FilesystemPresentation
  , minioBacking :: StorageBacking
  , minioResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

data ProvisionedMinio = ProvisionedMinio
  { provisionedMinioDemand :: MinioDemand
  , provisionedMinioGateway :: ObjectStoreAdmissionGatewayDemand
  , provisionedMinioGeometry :: GeometryWitness
  , provisionedMinioPerDriveBytes :: Natural
  , provisionedMinioUniformDebit :: Natural
  }
  deriving stock (Eq, Show)

provisionMinio :: MinioDemand -> Either Text ProvisionedMinio
provisionMinio demand = do
  _ <- validateResourceEnvelope (minioResources demand)
  producers <- firstStorage (traverse provisionObjectStoreProducer (minioProducers demand))
  gateway <- firstStorage (mergeObjectStoreLogicalPeaks (minioInventory demand) producers)
  let logical = gatewayResidentBytes gateway + transientBytes gateway
  geometry0 <- firstStorage (minioPhysicalDemand (minioPolicy demand) logical)
  let geometry = mutateGeometry logical geometry0
      drives = minioErasureSets (minioPolicy demand) * (minioDataShards (minioPolicy demand) + minioParityShards (minioPolicy demand))
      perDriveUsable = ceilDiv (geometryPhysicalBytes geometry) drives
      perDriveRaw = roundAllocation (backingAllocation (minioBacking demand)) (presentBytes (minioPresentation demand) perDriveUsable)
      uniformDebit = uniformDebitFor perDriveRaw drives
  if minioReplicas demand == 0 || drives < 4
    then Left "minio-distributed-topology-required"
    else case fitBacking (minioBacking demand) uniformDebit of
      Left problem -> Left (renderStorage problem)
      Right _ ->
        Right
          ProvisionedMinio
            { provisionedMinioDemand = demand
            , provisionedMinioGateway = gateway
            , provisionedMinioGeometry = geometry
            , provisionedMinioPerDriveBytes = perDriveRaw
            , provisionedMinioUniformDebit = uniformDebit
            }
 where
#ifdef PLATFORM_BACKBONE_CONTENT_IMMEDIATE_GC_MUTANT
  transientBytes _ = 0
#else
  transientBytes = gatewayTransientBytes
#endif
#ifdef PLATFORM_BACKBONE_LOGICAL_AS_PHYSICAL_MUTANT
  mutateGeometry logical geometry = geometry {geometryPhysicalBytes = logical}
#elif defined(PLATFORM_BACKBONE_DROP_FAULT_SCENARIO_MUTANT)
  mutateGeometry _ geometry = geometry {geometryFailureScenarios = [[]]}
#else
  mutateGeometry _ geometry = geometry
#endif
#ifdef PLATFORM_BACKBONE_SUM_ORDINALS_MUTANT
  uniformDebitFor perDrive drives = perDrive + drives
#else
  uniformDebitFor perDrive drives = perDrive * drives
#endif

renderMinio :: ProvisionedMinio -> [PlatformObject]
renderMinio provision =
  [ PlatformObject
      "StatefulSet"
      "platform-system"
      (minioName demand)
      (minioReplicas demand)
      (minioImage demand)
      ["/usr/bin/minio", "server", "/data0", "/data1", "/data2", "/data3", "--address", ":9000", "--console-address", ":9001"]
      (Just (minioResources demand))
      Nothing
      Nothing
  ]
 where
  demand = provisionedMinioDemand provision

firstStorage :: Either StorageError value -> Either Text value
firstStorage = either (Left . renderStorage) Right

renderStorage :: StorageError -> Text
renderStorage = \case
  StorageOverBacking owner required available -> unBackingId owner <> ":storage-over-backing:" <> showText required <> ":" <> showText available
  ObjectProducerInventoryMismatch _ _ -> "object-producer-inventory-mismatch"
  ObjectIdentityConflict identity _ _ -> "object-identity-conflict:" <> identity
  InvalidStorageGeometry reason -> "invalid-storage-geometry:" <> reason
  other -> showText other

showText :: Show value => value -> Text
showText = Text.pack . show

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator
  | denominator == 0 = 0
  | otherwise = (numerator + denominator - 1) `div` denominator
