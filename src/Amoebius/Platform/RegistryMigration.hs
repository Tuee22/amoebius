{-# LANGUAGE OverloadedStrings #-}

-- | The transfer's complete Kubernetes objects are derived from the same
-- private storage and execution provisions as its source and target. There is
-- no second resource table or caller-supplied manifest fragment in this path.
module Amoebius.Platform.RegistryMigration
  ( RegistryMigrationMode (..), ProvisionedRegistryBackendMigration
  , provisionRegistryMigration, registryMigrationProjection
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..), ReconcileMode (ServerSideApply), RenderActivation (Immediate))
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.RenderAll (RenderProvisioned (renderAll))
import Amoebius.Platform.Provision
import Amoebius.Platform.StoragePlan
import Control.Monad (unless)
import Data.Aeson (Value, encode, object, (.=))
import Data.ByteString.Lazy qualified as Lazy
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text

data RegistryMigrationMode = CopyEveryObject | VerifyCorruptLink
  deriving stock (Eq, Show)

data ProvisionedRegistryBackendMigration = ProvisionedRegistryBackendMigration
  ProvisionedBackboneStorage ProvisionedPlatformService Text RegistryMigrationMode (Map Text RegistryDriverObject)
  deriving stock (Eq, Show)

instance RenderProvisioned ProvisionedRegistryBackendMigration where
  renderAll = sortOn objectIdentity . registryMigrationObjects

provisionRegistryMigration
  :: ProvisionedBackboneStorage -> ProvisionedBackboneServices -> Text -> RegistryMigrationMode
  -> Either Text ProvisionedRegistryBackendMigration
provisionRegistryMigration storage services image mode = do
  let identity = case mode of
        CopyEveryObject -> "platform-system/registry-transfer"
        VerifyCorruptLink -> "platform-system/registry-transfer-mismatch"
  service <- maybe (Left "registry-transfer-execution-provision-missing") Right
    (backboneService services identity)
  unless (("@" <> backboneRegistryIndexDigest storage) `Text.isSuffixOf` image)
    (Left "registry-transfer-image-provenance-mismatch")
  unless (platformServiceScratchBytes service >= 65536) (Left "registry-transfer-workspace-too-small")
  let driver = backboneRegistryDriverObjects storage
  selected <- case mode of
    CopyEveryObject -> pure driver
    VerifyCorruptLink -> case [(key, value) | (key, value) <- Map.toAscList driver, driverObjectBytes value == 71] of
      first : _ -> pure (Map.fromList [first])
      [] -> Left "registry-transfer-link-probe-absent"
  unless (not (Map.null selected) && Map.size selected <= 1024) (Left "registry-transfer-object-set-invalid")
  pure (ProvisionedRegistryBackendMigration storage service image mode selected)

registryMigrationProjection :: ProvisionedRegistryBackendMigration -> Value
registryMigrationProjection (ProvisionedRegistryBackendMigration storage service image mode driver) = object
  [ "schema" .= ("amoebius.registry-backend-migration.v1" :: Text)
  , "image" .= image, "mode" .= showText mode, "streamBufferBytes" .= (65536 :: Int)
  , "sourceReadOnly" .= True, "sourceRemainsChargedUntilObservedCleanup" .= True
  , "sourceRawBytes" .= Map.lookup "phase30-registry-source" (backboneVolumeInventory storage)
  , "targetRawBytes" .= sum [bytes | (name, bytes) <- Map.toList (backboneVolumeInventory storage), "phase30-minio-" `Text.isPrefixOf` name]
  , "executor" .= platformServiceProjection service
  , "objects" .= driverRows driver
  ]

registryMigrationObjects :: ProvisionedRegistryBackendMigration -> [K8sObject]
registryMigrationObjects (ProvisionedRegistryBackendMigration _ service image mode driver) =
  [ native ServiceAccountKind "v1" "registry-writer" Map.empty
  , native ConfigMapKind "v1" name (Map.singleton "data" (object ["migration.json" .= configuration]))
  , native JobKind "batch/v1" name (Map.singleton "spec" jobSpec)
  ]
 where
  name = case mode of CopyEveryObject -> "registry-transfer"; VerifyCorruptLink -> "registry-transfer-mismatch"
  configuration = registryTransferConfiguration mode driver
  jobSpec = object
    [ "backoffLimit" .= (0 :: Int), "completions" .= (1 :: Int), "parallelism" .= (1 :: Int)
    , "activeDeadlineSeconds" .= (1200 :: Int)
    , "ttlSecondsAfterFinished" .= (3600 :: Int)
    , "template" .= object
      [ "metadata" .= object ["labels" .= Map.singleton ("app" :: Text) name]
      , "spec" .= object
        [ "serviceAccountName" .= ("registry-writer" :: Text), "restartPolicy" .= ("Never" :: Text)
        , "containers" .= [object
          [ "name" .= ("transfer" :: Text), "image" .= image, "imagePullPolicy" .= ("Never" :: Text)
          , "command" .= (["/amoebius-runtime/amoebius", "registry-transfer", "/config/migration.json"] :: [Text])
          , "resources" .= platformServiceK8sResources service
          , "securityContext" .= object ["readOnlyRootFilesystem" .= True, "allowPrivilegeEscalation" .= False,
              "capabilities" .= object ["drop" .= (["ALL"] :: [Text])]]
          , "volumeMounts" .=
              [ mount "source" "/source" True, mount "config" "/config" True
              , mount "binary" "/amoebius-runtime/amoebius" True, mount "scratch" "/tmp" False ]
          ]]
        , "volumes" .=
            [ host "source" "/amoebius-retained/phase30-registry-source" "Directory"
            , object ["name" .= ("config" :: Text), "configMap" .= object ["name" .= name]]
            , host "binary" "/amoebius-test/bin/amoebius" "File"
            , object ["name" .= ("scratch" :: Text), "emptyDir" .= object ["sizeLimit" .= showText (platformServiceScratchBytes service)]]
            ]
        ]
      ]
    ]
  native kind api identity fields = K8sObject
    (K8sObjectIdentity (kindText kind <> "/platform-system/" <> identity)) (Text.unpack api) kind
    (ObjectMetadata identity (Just "platform-system") (Map.singleton "app.kubernetes.io/managed-by" "amoebius")
      (if kind == JobKind then Map.singleton "amoebius.io/migration-mode" (showText mode) else Map.empty))
    (ExtensionSpec fields) Immediate ServerSideApply
  mount identity path readOnly = object (["name" .= (identity :: Text), "mountPath" .= (path :: Text)]
    <> ["readOnly" .= True | readOnly])
  host identity path kind = object ["name" .= (identity :: Text), "hostPath" .= object ["path" .= (path :: Text), "type" .= (kind :: Text)]]

kindText :: K8sObjectKind -> Text
kindText kind = case kind of ServiceAccountKind -> "ServiceAccount"; ConfigMapKind -> "ConfigMap"; _ -> "Job"

registryTransferConfiguration :: RegistryMigrationMode -> Map Text RegistryDriverObject -> Text
registryTransferConfiguration mode driver = Text.decodeUtf8 (Lazy.toStrict (encode (object
  [ "endpointHost" .= ("minio.platform-system.svc" :: Text), "endpointPort" .= (9000 :: Int)
  , "bucket" .= ("registry" :: Text), "sourceRoot" .= ("/source" :: Text)
  , "objects" .= driverRows driver, "verifyOnly" .= (mode == VerifyCorruptLink) ])))

driverRows :: Map Text RegistryDriverObject -> [Value]
driverRows driver = [object ["key" .= key, "bytes" .= driverObjectBytes value, "sha256" .= driverObjectDigest value] | (key, value) <- Map.toAscList driver]

showText :: Show value => value -> Text
showText = Text.pack . show
