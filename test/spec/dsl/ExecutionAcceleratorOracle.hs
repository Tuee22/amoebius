{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorOracle
  ( OracleRow (..)
  , MutantSpec (..)
  , expectedCalculusProjection
  , expectedRows
  , mutantSpecs
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

-- This module deliberately imports neither production folds nor fixture
-- modules.  It is the independent closed expectation for Phase 29.
data OracleRow = OracleRow
  { oracleVariant :: Text
  , oracleFamily :: Text
  , oracleOperation :: Text
  , oracleExpected :: Text
  , oracleTwin :: Text
  , oracleCatalog :: Text
  }
  deriving stock (Eq, Show)

data MutantSpec = MutantSpec
  { mutantName :: Text
  , mutantFlag :: String
  , mutantVariant :: Text
  , mutantLocus :: Text
  }
  deriving stock (Eq, Show)

expectedRows :: [OracleRow]
expectedRows =
  [ row "execution-replica-peak" "illegal_hard_ceiling_overcommit" "execution" "Overcommit:CpuAxis" "3.17:capacity-accounting"
  , row "execution-rollout-surge" "illegal_hard_ceiling_overcommit" "execution" "Overcommit:CpuAxis" "3.17:capacity-accounting"
  , row "execution-prior-old-revision" "illegal_hard_ceiling_overcommit" "execution-update" "Overcommit:CpuAxis" "3.17:capacity-accounting"
  , row "scheduler-aggregate-root" "illegal_hard_ceiling_overcommit" "scheduler" "SchedulerCapacityExceeded:CpuAxis" "3.17:capacity-accounting"
  , row "scheduler-snapshot-cas" "illegal_hard_ceiling_overcommit" "scheduler" "SchedulerSnapshotChanged" "3.17:capacity-accounting"
  , row "scheduler-projection" "illegal_hard_ceiling_overcommit" "scheduler" "ReservationProjectionMismatch" "3.17:capacity-accounting"
  , row "runtime-nodefs" "illegal_node_local_storage_over_backing" "runtime-metadata" "NodeLocalStorageOverBacking:nodefs" "3.17:capacity-accounting"
  , row "runtime-imagefs" "illegal_node_local_storage_over_backing" "runtime-metadata" "NodeLocalStorageOverBacking:runtime" "3.17:capacity-accounting"
  , row "runtime-model" "illegal_node_local_storage_over_backing" "runtime-metadata" "RuntimeMetadataModelMissing:v1" "3.17:capacity-accounting"
  , row "runtime-scope-domain" "illegal_node_local_storage_over_backing" "runtime-metadata" "RuntimeAccountingDomainMismatch" "3.17:capacity-accounting"
  , row "node-image-workspace" "illegal_node_local_storage_over_backing" "image-peak" "NodeLocalStorageOverBacking:unified" "3.17:capacity-accounting"
  , row "partition-parent" "illegal_disk_backing_alias_double_spend" "physical-partition" "PhysicalDiskOvercommit:disk" "3.17:capacity-accounting"
  , row "partition-carve-alias" "illegal_disk_backing_alias_double_spend" "physical-partition" "DiskBackingAlias:raw" "3.17:capacity-accounting"
  , row "partition-unit-mismatch" "illegal_disk_backing_alias_double_spend" "physical-partition" "DiskExtentUnitMismatch:raw" "3.17:capacity-accounting"
  , row "filesystem-layout-alias" "illegal_filesystem_layout_alias" "layout" "FilesystemLayoutMismatch" "3.17:capacity-accounting"
  , row "filesystem-layout-swapped" "illegal_filesystem_layout_swapped" "layout-observation" "FilesystemLayoutMismatch" "3.17:capacity-accounting"
  , row "image-content-join" "illegal_image_content_join_missing" "image-metadata" "ImageMetadataMissing:sha-index" "3.17:capacity-accounting"
  , row "image-manifest-join" "illegal_image_content_join_missing" "image-metadata" "ImageMetadataMissing:artifact:platform-manifest" "3.17:capacity-accounting"
  , row "image-snapshot-join" "illegal_image_snapshot_join_missing" "image-metadata" "ImageMetadataMissing:snap-a" "3.17:capacity-accounting"
  , row "image-storage-model" "illegal_image_storage_model_missing" "image-metadata" "ImageMetadataMissing:model-v1" "3.17:capacity-accounting"
  , row "split-image-containerd-v1" "illegal_split_image_unsupported" "layout" "SplitImageUnsupported" "3.17:capacity-accounting"
  , row "instance-store-root" "illegal_provider_instance_store_root_underprovisioned" "provider-root" "ProviderInstanceStoreRootUnderprovisioned" "3.17:capacity-accounting"
  , row "root-ebs-bytes-quota" "illegal_provider_node_root_ebs_over_quota" "provider-root" "ProviderNodeRootQuotaExceeded" "3.17:capacity-accounting"
  , row "root-ebs-volume-quota" "illegal_provider_node_root_ebs_over_quota" "provider-root" "ProviderNodeRootQuotaExceeded" "3.17:capacity-accounting"
  , row "etcd-transition-physical" "illegal_control_plane_storage_transition_overrun" "etcd" "EngineStorageOvercommit:etcd" "3.17:capacity-accounting"
  , row "cuda-family-absent" "illegal_cuda_on_cpu_target" "accelerator" "AcceleratorFamilyAbsent:CudaFamily" "3.28:accelerator-owner"
  , row "cuda-device-count" "illegal_accelerator_count_shortage" "accelerator" "AcceleratorDeviceCountShortage" "3.28:accelerator-owner"
  , row "cuda-unsharded-fragmentation" "illegal_accelerator_vram_fragmentation" "accelerator" "AcceleratorResidencyFit" "3.30:accelerator-memory-fit"
  , row "cuda-shard-byte-sum" "illegal_accelerator_vram_fragmentation" "accelerator" "AcceleratorShardInvalid" "3.30:accelerator-memory-fit"
  , row "cuda-vram-reserve" "illegal_accelerator_vram_reserve_boundary" "accelerator" "AcceleratorNetAllocatableViolation" "3.30:accelerator-memory-fit"
  , row "metal-profile" "illegal_apple_metal_profile_mismatch" "accelerator" "AcceleratorProfileMismatch" "3.30:accelerator-memory-fit"
  , row "accelerator-shared-owner" "illegal_shared_accelerator_double_owner" "accelerator-owner" "AcceleratorSharedDevice:cuda-a" "3.28:accelerator-owner"
  , row "accelerator-peer-graph" "illegal_accelerator_vram_fragmentation" "accelerator-interconnect" "AcceleratorInterconnectMissing" "3.30:accelerator-memory-fit"
  , row "build-cache-budget" "illegal_hard_ceiling_overcommit" "build-execution" "BuildCacheOvercommit" "3.17:capacity-accounting"
  , row "engine-storage-reserve" "illegal_control_plane_storage_transition_overrun" "engine-system-reserve" "EngineStorageOvercommit" "3.17:capacity-accounting"
  , row "monitoring-volume-budget" "illegal_hard_ceiling_overcommit" "monitoring-work" "MonitoringStorageOvercommit" "3.17:capacity-accounting"
  , row "pulumi-executor-concurrency" "illegal_hard_ceiling_overcommit" "pulumi-execution" "PulumiConcurrencyZero" "3.17:capacity-accounting"
  ]
 where
  row variant family operation expected catalog =
    OracleRow variant family operation expected ("legal_" <> variant) catalog

mutantSpecs :: [MutantSpec]
mutantSpecs =
  [ mutant "accelerator-drop-device-count" "cuda-device-count" "whole-device cardinality"
  , mutant "accelerator-drop-source-domain" "cuda-unsharded-fragmentation" "source inventory equality"
  , mutant "accelerator-favorable-epoch" "cuda-unsharded-fragmentation" "all coexistence epochs"
  , mutant "accelerator-ignore-metal-profile" "metal-profile" "Metal profile"
  , mutant "accelerator-ignore-shard-sum" "cuda-shard-byte-sum" "shard byte equality"
  , mutant "accelerator-share-device" "accelerator-shared-owner" "device owner uniqueness"
  , mutant "accelerator-spend-raw-vram" "cuda-vram-reserve" "net allocatable VRAM"
  , mutant "accelerator-split-unsharded" "cuda-unsharded-fragmentation" "unsharded per-device fit"
  , mutant "accelerator-treat-none-as-cuda" "cuda-family-absent" "accelerator family"
  , mutant "copy-new-execution-as-old" "execution-prior-old-revision" "prior and desired peak"
  , mutant "drop-execution-old-revision" "execution-prior-old-revision" "old revision epoch"
  , mutant "drop-execution-replica" "execution-replica-peak" "replica expansion"
  , mutant "drop-execution-surge" "execution-rollout-surge" "rolling surge epoch"
  , mutant "drop-removed-execution" "execution-prior-old-revision" "prior-only retention"
  , mutant "etcd-drop-defrag" "etcd-transition-physical" "defrag peak"
  , mutant "etcd-drop-preallocated-next" "etcd-transition-physical" "next WAL"
  , mutant "etcd-drop-snapshot-save" "etcd-transition-physical" "snapshot temporary"
  , mutant "etcd-drop-wal" "etcd-transition-physical" "WAL files"
  , mutant "image-drop-index" "image-content-join" "OCI index join"
  , mutant "image-drop-manifest" "image-manifest-join" "manifest join"
  , mutant "image-drop-snapshot" "image-snapshot-join" "snapshot join"
  , mutant "image-drop-workspace" "node-image-workspace" "pull workspace"
  , mutant "image-ignore-model" "image-storage-model" "image model"
  , mutant "invent-first-deploy-old" "execution-replica-peak" "empty first deployment"
  , mutant "layout-allow-alias" "filesystem-layout-alias" "split backing distinctness"
  , mutant "layout-enable-v1-split-image" "split-image-containerd-v1" "containerd support"
  , mutant "layout-ignore-observation" "filesystem-layout-swapped" "observed role equality"
  , mutant "partition-double-debit-child" "partition-carve-alias" "unique child identity"
  , mutant "partition-drop-system-reserve" "partition-parent" "system reserve debit"
  , mutant "partition-mix-vm-usable" "partition-unit-mismatch" "parent unit separation"
  , mutant "partition-use-vm-usable-as-raw" "partition-parent" "VM high-water"
  , mutant "provider-debit-durable" "root-ebs-volume-quota" "node root quota"
  , mutant "provider-reuse-template-id" "root-ebs-volume-quota" "qualified identities"
  , mutant "provider-skip-allocation-rounding" "root-ebs-bytes-quota" "allocation quantum"
  , mutant "provider-skip-presentation" "root-ebs-bytes-quota" "filesystem presentation"
  , mutant "provider-under-size-instance-store" "instance-store-root" "instance-store bytes"
  , mutant "resolve-latest-execution" "execution-prior-old-revision" "exact prior reference"
  , mutant "runtime-drop-largest-metadata" "runtime-nodefs" "complete metadata epoch"
  , mutant "runtime-missing-model" "runtime-model" "metadata model"
  , mutant "runtime-scope-confusion" "runtime-scope-domain" "identity domain"
  , mutant "runtime-swap-role" "runtime-imagefs" "CRI role routing"
  , mutant "scheduler-binding-crash-release" "scheduler-aggregate-root" "binding debit retention"
  , mutant "scheduler-drop-pad" "scheduler-projection" "reservation projection"
  , mutant "scheduler-per-record-cas" "scheduler-snapshot-cas" "root fingerprint"
  , mutant "scheduler-timeout-release" "scheduler-aggregate-root" "reserved debit retention"
  ]
 where
  mutant name variant locus =
    MutantSpec name ("execution-accelerator-" <> Text.unpack name <> "-mutant") variant locus

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "execution-negatives,execution-twins,composed-positives,placement-properties,mutant-evidence")
  , ("projection-counts", "37,37,2,7,45")
  , ("resource-vector", "5,128,0,0")
  ]
