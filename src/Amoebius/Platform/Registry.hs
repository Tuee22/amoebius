{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Registry
  ( RegistryBackend (..)
  , ProvisionedRegistryRehome (..)
  , provisionRegistryRehome
  , registryStorageConfiguration
  , cutoverRegistry
  , renderRegistryRehome
  ) where

import Amoebius.Capacity.ServiceStorage
import Amoebius.Capacity.StorageGeometry
import Amoebius.Platform.Types
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data RegistryBackend
  = RegistryFilesystem Text
  | RegistryMinio Text Text
  deriving stock (Eq, Ord, Show)

data ProvisionedRegistryRehome = ProvisionedRegistryRehome
  { registryOriginalDemand :: RegistryStorageDemand
  , registryOriginalPeak :: Natural
  , registryReplacementObjects :: Map Text Natural
  , registryMigration :: ProvisionedMigration
  , registryTargetBackend :: RegistryBackend
  }
  deriving stock (Eq, Show)

provisionRegistryRehome
  :: RegistryStorageDemand
  -> MigrationDemand
  -> Text
  -> Text
  -> Either Text ProvisionedRegistryRehome
provisionRegistryRehome demand migration endpoint bucket = do
  original <- either (Left . Text.pack . show) Right (registryStoragePeak demand)
  moved <- either (Left . Text.pack . show) Right (provisionRegistryBackendMigration migration)
  let objects = Map.fromListWith max (registryObjects demand)
  if endpoint == "" || bucket == "" || Map.null objects
    then Left "registry-rehome-incomplete"
    else
      Right
        ProvisionedRegistryRehome
          { registryOriginalDemand = demand
          , registryOriginalPeak = serviceStoragePeakBytes original
          , registryReplacementObjects = objects
          , registryMigration = moved
          , registryTargetBackend = RegistryMinio endpoint bucket
          }

registryStorageConfiguration :: RegistryBackend -> Text
registryStorageConfiguration backend = case effectiveBackend backend of
  RegistryFilesystem root -> "storage:\n  filesystem:\n    rootdirectory: " <> root <> "\n"
  RegistryMinio endpoint bucket ->
    Text.unlines
      [ "storage:"
      , "  s3:"
      , "    region: us-east-1"
      , "    regionendpoint: " <> endpoint
      , "    bucket: " <> bucket
      , "    secure: false"
      , "    v4auth: true"
      ]
 where
#ifdef PHASE30_REGISTRY_FS_DRIVER_MUTANT
  effectiveBackend _ = RegistryFilesystem "/var/lib/registry"
#else
  effectiveBackend = id
#endif

cutoverRegistry :: Bool -> ProvisionedRegistryRehome -> RegistryBackend
cutoverRegistry verified provision
  | verified = registryTargetBackend provision
  | otherwise = RegistryFilesystem "/var/lib/registry"

-- | The post-cutover projection deliberately retains the read-only source at
-- zero replicas.  That makes the old backing observable for verification
-- without allowing another filesystem write after the S3 cutover.
renderRegistryRehome :: Text -> ResourceEnvelope -> ProvisionedRegistryRehome -> [PlatformObject]
renderRegistryRehome image resources _provision =
  [ registryObject "registry-source" 0
  , registryObject "registry" 1
  ]
 where
  registryObject name replicas =
    PlatformObject
      "Deployment"
      "platform-system"
      name
      replicas
      image
      ["/usr/bin/registry", "serve", "/etc/distribution/config.yml"]
      (Just resources)
      Nothing
      Nothing
