{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Vault's complete service projection is available only after the canonical
-- resource-envelope, execution-epoch and retained-storage folds succeed.
module Amoebius.Vault.Provision
  ( VaultExecutionDemand (..)
  , VaultServiceProvisionError (..)
  , ProvisionedVaultServiceSpec
  , standardVaultExecutionDemand
  , provisionVaultService
  , vaultServiceProjection
  , runVaultServiceProjectionCommand
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionInventory (..), BoundExecutionUnit (..), ControllerBody (..)
  , ExecutionTransitionSource (FirstDeployment), ProvisionedExecutionEpochs
  , StatefulSetRollout (StatefulSetNativeSerial), provisionExecutionEpochs
  )
import Amoebius.Capacity.Types
  ( ResourceEnvelope, ResourceVector (..), envelopeLimits, envelopeRequests, mkResourceEnvelope )
import Amoebius.Vault.Init
  ( ProvisionedVaultStorageDemand, auditProvisionedRawBytes, auditRequiredUsableBytes
  , provisionVaultStorage, standardVaultAuditDemand, standardVaultStorageDemand
  , vaultProvisionedRawBytes, vaultRequiredUsableBytes
  )
import Data.Aeson (Value, encode, object, (.=))
import Data.ByteString.Lazy.Char8 qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import Text.Read (readMaybe)

data VaultExecutionDemand = VaultExecutionDemand
  { vaultAppRequests :: ResourceVector
  , vaultAppLimits :: ResourceVector
  , vaultAppHeadroom :: ResourceVector
  , vaultScratchBytes :: Natural
  , vaultWritableBytes :: Natural
  , vaultLogBytes :: Natural
  }
  deriving stock (Eq, Show)

data VaultServiceProvisionError
  = VaultStorageFailure String
  | VaultResourceFailure String
  | VaultDurableUsableTooSmall Integer Integer
  | VaultAuditUsableTooSmall Integer Integer
  | VaultEphemeralNestingViolation Natural Natural
  | VaultPodSlotMismatch
  | VaultExecutionProfileTooSmall
  deriving stock (Eq, Show)

data ProvisionedVaultServiceSpec = ProvisionedVaultServiceSpec
  ProvisionedVaultStorageDemand ResourceEnvelope ProvisionedExecutionEpochs VaultExecutionDemand
  deriving stock (Eq, Show)

standardVaultExecutionDemand :: VaultExecutionDemand
standardVaultExecutionDemand = VaultExecutionDemand
  (ResourceVector 100 (128 * mib) (32 * mib) 1)
  (ResourceVector 500 (512 * mib) (64 * mib) 1)
  (ResourceVector 400 (384 * mib) (32 * mib) 0)
  (16 * mib) (8 * mib) (4 * mib)
 where
  mib = 1048576

provisionVaultService
  :: ResourceVector -> Integer -> Integer -> Integer -> Integer
  -> VaultExecutionDemand -> Either VaultServiceProvisionError ProvisionedVaultServiceSpec
provisionVaultService available durableRaw auditRaw durableUsable auditUsable demand = do
  storage <- either (Left . VaultStorageFailure . show) Right
    (provisionVaultStorage durableRaw auditRaw standardVaultStorageDemand standardVaultAuditDemand)
  if durableUsable < vaultRequiredUsableBytes storage
    then Left (VaultDurableUsableTooSmall (vaultRequiredUsableBytes storage) durableUsable)
    else Right ()
  if auditUsable < auditRequiredUsableBytes storage
    then Left (VaultAuditUsableTooSmall (auditRequiredUsableBytes storage) auditUsable)
    else Right ()
  envelope <- either (Left . VaultResourceFailure . show) Right
    (mkResourceEnvelope (vaultAppRequests demand) (vaultAppLimits demand) (vaultAppHeadroom demand))
  if resourcePodSlots (vaultAppRequests demand) /= 1 || resourcePodSlots (vaultAppLimits demand) /= 1 || resourcePodSlots (vaultAppHeadroom demand) /= 0
    then Left VaultPodSlotMismatch
    else Right ()
  if vaultScratchBytes demand < 16 * 1048576 || vaultWritableBytes demand < 8 * 1048576 || vaultLogBytes demand < 4 * 1048576
    then Left VaultExecutionProfileTooSmall
    else Right ()
  let ephemeral = vaultScratchBytes demand + vaultWritableBytes demand + vaultLogBytes demand
      permitted = resourceEphemeralStorage (vaultAppRequests demand)
  if ephemeral > permitted
    then Left (VaultEphemeralNestingViolation ephemeral permitted)
    else Right ()
  execution <- either (Left . VaultResourceFailure . show) Right
    (provisionExecutionEpochs Map.empty available
      (BoundExecutionInventory FirstDeployment
        [BoundExecutionUnit "root-vault" 1 envelope (StatefulSetBody 1 StatefulSetNativeSerial)]))
  pure (ProvisionedVaultServiceSpec storage envelope execution demand)

vaultServiceProjection :: ProvisionedVaultServiceSpec -> Value
vaultServiceProjection (ProvisionedVaultServiceSpec storage envelope _execution demand) = object
  [ "schema" .= ("amoebius.vault-service-projection.v1" :: Text)
  , "controller" .= ("StatefulSet" :: Text), "replicas" .= (1 :: Int)
  , "executionUnit" .= ("root-vault" :: Text)
  , "executionRoles" .= (["vault-server", "vault-init-exec", "audit-writer"] :: [Text])
  , "resources" .= object ["requests" .= resources (envelopeRequests envelope), "limits" .= resources (envelopeLimits envelope)]
  , "scratch" .= object ["name" .= ("scratch" :: Text), "path" .= ("/tmp" :: Text), "bytes" .= vaultScratchBytes demand]
  , "writableBytes" .= vaultWritableBytes demand, "logBytes" .= vaultLogBytes demand
  , "logPolicy" .= object ["maximumFileBytes" .= (1048576 :: Int), "maximumFiles" .= (3 :: Int)]
  , "securityContext" .= object
      [ "readOnlyRootFilesystem" .= True, "allowPrivilegeEscalation" .= False
      , "capabilities" .= object ["drop" .= (["ALL"] :: [Text])]
      ]
  , "cache" .= ("None" :: Text), "accelerator" .= ("None" :: Text)
  , "durable" .= volume (vaultProvisionedRawBytes storage) (vaultRequiredUsableBytes storage)
  , "audit" .= volume (auditProvisionedRawBytes storage) (auditRequiredUsableBytes storage)
  ]
 where
  resources vector = object
    [ "cpu" .= (Text.pack (show (resourceCpu vector)) <> "m")
    , "memory" .= Text.pack (show (resourceMemory vector))
#ifndef VAULT_PKI_DROP_RESOURCE_AXIS_MUTANT
    , "ephemeral-storage" .= Text.pack (show (resourceEphemeralStorage vector))
#endif
    ]
  volume raw usable = object
    [ "provisionedBytes" .= raw, "requiredUsableBytes" .= usable
    , "filesystemType" .= ("ext4" :: Text), "volumeMode" .= ("Filesystem" :: Text)
    , "accessModes" .= (["ReadWriteOnce"] :: [Text])
    , "storageClass" .= ("amoebius-retained" :: Text)
    ]

runVaultServiceProjectionCommand :: [String] -> IO ()
runVaultServiceProjectionCommand arguments = case traverse readMaybe arguments :: Maybe [Integer] of
  Just [cpu, memory, ephemeral, pods, durableRaw, auditRaw, durableUsable, auditUsable]
    | all (>= 0) [cpu, memory, ephemeral, pods] ->
        either (fail . show) (Lazy.putStrLn . encode . vaultServiceProjection)
          (provisionVaultService
            (ResourceVector (fromInteger cpu) (fromInteger memory) (fromInteger ephemeral) (fromInteger pods))
            durableRaw auditRaw durableUsable auditUsable standardVaultExecutionDemand)
  _ -> fail "usage: vault-service-projection CPU_MILLICORES MEMORY_BYTES EPHEMERAL_BYTES PODS DURABLE_RAW AUDIT_RAW DURABLE_USABLE AUDIT_USABLE"
