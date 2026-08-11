{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulumi.Credential
import Amoebius.Pulumi.Ebs
import Amoebius.Storage.EbsCsi
import Amoebius.Storage.ProviderScaling qualified as Scaling
import Control.Monad (forM_, unless)
import Numeric.Natural (Natural)
import System.Exit (die)

main :: IO ()
main = do
  volumeContract
  credentialContract
  staticCsiContract
  migrationContract
  scalingContract
  putStrLn "provider-ebs-credential-contract: PASS (geometry, credentials, static CSI, migration, scaling)"

volumeContract :: IO ()
volumeContract = do
  forM_
    [ (1, 1073741824, 1073741824, 1, 1073741824)
    , (5368709120, 1073741824, 1073741824, 5, 5368709120)
    , (5368709121, 1073741824, 1073741824, 6, 6442450944)
    , (7, 2147483648, 1073741824, 2, 2147483648)
    ]
    $ \(required, minimumBytes, quantum, expectedGiB, expectedBytes) -> do
      action <- expectRight "rounding-admission" (validateProviderVolume (quota expectedBytes 1) (demand required minimumBytes quantum))
      assertEq "rounded-size-gib" expectedGiB (requestSizeGiB (validatedRequest action))
      assertEq "rounded-provisioned-bytes" expectedBytes (requestProvisionedBytes (validatedRequest action))
  action <- expectRight "nominal-volume" (validateProviderVolume (quota 6442450944 1) (demand 5368709121 1073741824 1073741824))
  assertEq "one-short-byte" (Left DurableProviderBytesInsufficient) (validateProviderVolume (quota 6442450943 1) (demand 5368709121 1073741824 1073741824))
  assertEq "one-short-count" (Left DurableProviderVolumeCountInsufficient) (validateProviderVolume (quota 6442450944 0) (demand 5368709121 1073741824 1073741824))
  assertEq "stale-account" (Left ProviderAccountSnapshotChanged) (validateProviderVolume (ProviderQuotaSnapshot "stale" 6442450944 1) (demand 5368709121 1073741824 1073741824))
  let request = validatedRequest action
      receipt = ProviderCreateReceipt "account-fp" (promisedSlotId action) "vol-046scope" (requestProvisionedBytes request) (requestZone request)
  materialized <- expectRight "receipt-materialization" (materializeProviderVolume action receipt)
  assertEq "materialized-id" "vol-046scope" (materializedVolumeId materialized)
  assertEq "receipt-mismatch" (Left ProviderCreateReceiptMismatch) (materializeProviderVolume action receipt {receiptZone = "us-east-1b"})
  checkpoint <- expectRight "durable-checkpoint" (mkDurableCheckpointNamespace "stacks/cluster/checkpoint" "durable/pv/data-sts0-pv_0/checkpoint")
  assert "durable-checkpoint-protect-retain" (durableCheckpointProtected checkpoint && durableCheckpointRetained checkpoint)
  assertEq "checkpoint-collapse" (Left CheckpointClassCollapsed) (mkDurableCheckpointNamespace "same" "same")

credentialContract :: IO ()
credentialContract = do
  assertEq "operational-create" (PolicyRow Operational CreateVolume Allow AccountAndDeclaredZone) (decide Operational CreateVolume)
  assertEq "mut-46.1-allow-delete" (PolicyRow Operational DeleteVolume Deny DurableRetained) (decide Operational DeleteVolume)
  assertEq "csi-attach" (PolicyRow CsiRuntime AttachVolume Allow DeclaredVolume) (decide CsiRuntime AttachVolume)
  assertEq "csi-create-deny" (PolicyRow CsiRuntime CreateVolume Deny AllResources) (decide CsiRuntime CreateVolume)
  assertEq "csi-delete-deny" (PolicyRow CsiRuntime DeleteVolume Deny AllResources) (decide CsiRuntime DeleteVolume)
  assertEq "credential-matrix-cardinality" 10 (length credentialMatrix)

staticCsiContract :: IO ()
staticCsiContract = do
  assertEq "mut-46.1-enable-dynamic-provisioner" 0 (installExternalProvisionerContainers staticOnlyInstall)
  assertEq "sole-no-provisioner" "kubernetes.io/no-provisioner" (installStorageClassProvisioner staticOnlyInstall)
  assert "no-helm-public" (not (installUsesHelm staticOnlyInstall) && not (installUsesPublicImage staticOnlyInstall))
  assertEq "bake-inventory-cardinality" 5 (length bakedCsiInventory)
  assert "bake-absolute-two-arch" (all (\binary -> take 1 (csiBinaryPath binary) == "/" && csiBinaryArchitectures binary == ["amd64", "arm64"]) bakedCsiInventory)
  action <- expectRight "static-volume-admission" (validateProviderVolume (quota 6442450944 1) (demand 5368709121 1073741824 1073741824))
  let request = validatedRequest action
  volume <- expectRight "static-volume-materialize" (materializeProviderVolume action (ProviderCreateReceipt "account-fp" (promisedSlotId action) "vol-static" (requestProvisionedBytes request) (requestZone request)))
  spec <- expectRight "static-pv" (renderStaticPv volume (StaticPvDemand "pv-data" "amoebius-retained" ["claim-a", "claim-a", "claim-b"] 2 3))
  assertEq "static-driver" "ebs.csi.aws.com" (pvCsiDriver spec)
  assertEq "static-volume-handle" "vol-static" (pvVolumeHandle spec)
  assertEq "static-zone" "us-east-1a" (pvZone spec)
  assertEq "static-retain" "Retain" (pvReclaimPolicy spec)
  assertEq "attach-slot-dedup" 2 (requiredAttachmentSlots ["claim-a", "claim-a", "claim-b"])
  assertEq "attach-one-short" (Left (AttachSlotsInsufficient 2 1)) (renderStaticPv volume (StaticPvDemand "pv-data" "amoebius-retained" ["claim-a", "claim-b"] 1 3))

migrationContract :: IO ()
migrationContract = do
  let copy = CopyExecution 500 536870912 1073741824 1
      migration = StorageMigrationDemand 6442450944 7516192768 1073741824 copy 2
      exact = MigrationSupply 13958643712 2 1073741824 500 536870912 1073741824 1 2
  provisioned <- expectRight "migration-exact" (provisionStorageMigration migration exact)
  assertEq "mut-46.1-credit-old-before-observed-delete" 13958643712 (migrationDurableBytes provisioned)
  assert "migration-old-charged" (migrationOldRemainsCharged provisioned)
  assert "mut-46.1-drop-copy-executor" (migrationCopyExecutionPresent provisioned)
  assertEq "migration-count" 2 (migrationVolumeCount provisioned)
  assertEq "migration-attachments" 2 (migrationAttachmentCount provisioned)
  forM_
    [ (DurableBytesOneShort, exact {supplyDurableBytes = 13958643711})
    , (DurableVolumeCountOneShort, exact {supplyDurableVolumeCount = 1})
    , (WorkspaceOneShort, exact {supplyWorkspaceBytes = 1073741823})
    , (CopyCpuOneShort, exact {supplyCopyCpuMillis = 499})
    , (CopyMemoryOneShort, exact {supplyCopyMemoryBytes = 536870911})
    , (CopyPodEphemeralOneShort, exact {supplyCopyPodEphemeralBytes = 1073741823})
    , (PodSlotsOneShort, exact {supplyPodSlots = 0})
    , (CsiAttachSlotsOneShort, exact {supplyCsiAttachSlots = 1})
    ]
    $ \(expected, oneShort) -> assertEq (show expected) (Left expected) (provisionStorageMigration migration oneShort)

scalingContract :: IO ()
scalingContract = do
  batch <- expectRight "scaling-batch" (Scaling.mkValidatedCloudActionBatch "snapshot-fp" Scaling.CreateProviderCapacity [Scaling.CreateVolume, Scaling.WriteDurableCheckpoint])
  assertEq "scaling-exact-actions" [Scaling.CreateVolume, Scaling.WriteDurableCheckpoint] (Scaling.validatedBatchActions batch)
  assertEq "mut-46.1-bypass-validated-batch" (Left Scaling.ScalingObservationStale) (Scaling.enactCreateProviderCapacity "stale" "receipt" batch)
  enactment <- expectRight "scaling-enact" (Scaling.enactCreateProviderCapacity "snapshot-fp" "receipt" batch)
  assertEq "scaling-replay" (Left Scaling.ScalingBatchAlreadyConsumed) (Scaling.enactCreateProviderCapacity "snapshot-fp" "receipt-2" (Scaling.enactedBatch enactment))
  assertEq "non-provider-actions" (Left Scaling.ScalingBatchDomainMismatch) (Scaling.mkValidatedCloudActionBatch "snapshot-fp" Scaling.NoChange [Scaling.CreateVolume])

demand :: Natural -> Natural -> Natural -> ProviderVolumeDemand
demand required minimumBytes quantum =
  ProviderVolumeDemand
    { demandAccountFingerprint = "account-fp"
    , demandCluster = "amoebius-p46"
    , demandClaim = "data/sts0/pv_0"
    , demandVolumeType = "gp3"
    , demandZone = "us-east-1a"
    , demandRequiredUsableBytes = required
    , demandPresentation = "ext4"
    , demandAllocation = AllocationPolicy minimumBytes quantum
    }

quota :: Natural -> Natural -> ProviderQuotaSnapshot
quota bytes count = ProviderQuotaSnapshot "account-fp" bytes count

expectRight :: Show problem => String -> Either problem value -> IO value
expectRight _ (Right value) = pure value
expectRight label (Left problem) = die (label <> ": expected Right, got Left " <> show problem)

assertEq :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEq label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: String -> Bool -> IO ()
assert label condition = unless condition (die (label <> ": assertion failed"))
