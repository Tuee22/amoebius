# Resource Capacity Schema

> **Purpose**: The complete typed schema of the amoebius resource-provisioning model, divided into 26 type families.
> **Read this if**: the exact spelling of a capacity, demand, budget, or provisioned type is needed.

This document is the reference artifact of the resource-capacity family: it carries the type spellings and
nothing else. Every normative statement about what these types mean, what the folds over them guarantee, and
where their numbers come from is owned by
[resource_capacity_doctrine.md](./resource_capacity_doctrine.md) and its sibling slices — a spelling here that
disagrees with the doctrine is a defect in this file. The families below are ordered as the schema is
constructed, from scalar quantities outward to whole-deployment budgets, and every type appears exactly once.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/resource_capacity_construction.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_sources.md, documents/engineering/resource_capacity_storage.md, documents/engineering/resource_capacity_types.md
**Generated sections**: none

</details>

## Contents
- [1. Compute quantities and container envelopes](#1-compute-quantities-and-container-envelopes)
- [2. Images and the kubelet filesystem layout](#2-images-and-the-kubelet-filesystem-layout)
- [3. Provider node capacity and per-instance templates](#3-provider-node-capacity-and-per-instance-templates)
- [4. Physical hosts, disks, and carves](#4-physical-hosts-disks-and-carves)
- [5. BookKeeper and ZooKeeper](#5-bookkeeper-and-zookeeper)
- [6. Object store, Pulumi state, and the producer arms](#6-object-store-pulumi-state-and-the-producer-arms)
- [7. MinIO geometry and claim slots](#7-minio-geometry-and-claim-slots)
- [8. Accelerators](#8-accelerators)
- [9. Kubelet runtime metadata and node storage accounting](#9-kubelet-runtime-metadata-and-node-storage-accounting)
- [10. Pod-local storage and the jit-build cache](#10-pod-local-storage-and-the-jit-build-cache)
- [11. Volumes, storage migration, and schema migration](#11-volumes-storage-migration-and-schema-migration)
- [12. Patroni SQL](#12-patroni-sql)
- [13. Registry storage, bootstrap registry, and backend rehome](#13-registry-storage-bootstrap-registry-and-backend-rehome)
- [14. Vault storage and audit](#14-vault-storage-and-audit)
- [15. Resource envelopes and reservation axes](#15-resource-envelopes-and-reservation-axes)
- [16. Execution units, controllers, and rollout policy](#16-execution-units-controllers-and-rollout-policy)
- [17. Scheduler and host reservation states](#17-scheduler-and-host-reservation-states)
- [18. Observed execution and normalization](#18-observed-execution-and-normalization)
- [19. Log retention and provisioned controllers](#19-log-retention-and-provisioned-controllers)
- [20. Execution transition guards and release evidence](#20-execution-transition-guards-and-release-evidence)
- [21. Namespace quota, admission, and the capacity-scheduler system](#21-namespace-quota-admission-and-the-capacity-scheduler-system)
- [22. Controller children, builds, and the bootstrap toolchain](#22-controller-children-builds-and-the-bootstrap-toolchain)
- [23. Kubernetes API objects and the mandatory reconciler Lease](#23-kubernetes-api-objects-and-the-mandatory-reconciler-lease)
- [24. etcd churn](#24-etcd-churn)
- [25. Tenant policy derivation and persistence](#25-tenant-policy-derivation-and-persistence)
- [26. Engine, kind host, network fabric, and monitoring budgets](#26-engine-kind-host-network-fabric-and-monitoring-budgets)
- [Related Documents](#related-documents)

---

## 1. Compute quantities and container envelopes

```text
Residual u =
  < Zero | Remaining : Quantity u >

-- Same scalar/resource shape as Capacity, but every scalar is Residual and
-- allocated discrete identities have been removed.
AvailableCapacity = Residualized Capacity
-- NOTE: there is deliberately no `Headroom` synonym for AvailableCapacity. "Headroom" in this doctrine
-- always means the DEMAND-side declared pad (`headroom : Optional ComputeHeadroomDemand`); remaining
-- supply is always `AvailableCapacity`. One word never names both sides of the ledger.

Resources =
  { requests : PodResourceVec
  , limits   : PodResourceVec
  }

PodResourceVec =
  { cpu              : Quantity Cpu
  , memory           : Quantity Bytes
  , ephemeralStorage : Quantity Bytes
  }

CpuOvercommitPolicy =
  < NoCpuOvercommit
  | BoundedCpuOvercommit : { maxLimitToAllocatable : RatioAtLeastOne }
  >

ComputeHeadroomReason =
  < VerticalGrowth      : { horizon : FiniteDuration }
  | BurstAbsorption
  | NeighbourIsolation
  | DefragmentationReserve
  >

ComputeHeadroomDemand =
  { reason           : ComputeHeadroomReason
  , pad              : Residualized PodResourceVec
  , someAxisPositive : PositiveHeadroomAxisWitness
  }

HostComputeHeadroomDemand =
  { reason           : ComputeHeadroomReason
  , pad              : Residualized HostResourceVec
  , someAxisPositive : PositiveHeadroomAxisWitness
  }

ComputeAxis =
  < Cpu | Memory | EphemeralStorage >
-- The host arm has no ephemeral axis, so a HostComputeHeadroomDemand naming
-- EphemeralStorage has no constructor.

PositiveHeadroomAxisWitness =
  { paddedAxes       : NonEmpty ComputeAxis
  , zeroAxesExact    : Required
  , someAxisPositive : Required
  , axesWithinArm    : Required
  }
-- An all-Zero pad has no constructor: "no headroom" is Optional None, never a
-- vector of zeroes. paddedAxes is exactly the set of axes whose pad is Remaining.

ContainerLifecycle =
  < App | Sidecar | Init | RestartableInit >

ContainerProcess =                                            -- InClusterRole: daemon_topology §2
  < AmoebiusRole : InClusterRole                              -- the linked binary, in a closed role
  | BakedService : { binary : BakedBinaryId, args : List Text }  -- a binary some BakeStep installed
  >

ContainerEnvelope =
  { id                    : ContainerId
  , lifecycle             : ContainerLifecycle
  , image                 : ImageArtifact
  , process               : ContainerProcess
  , runtimeMemoryWorkingSet : Quantity Bytes
  , privateEphemeral      :
      { rootFilesystem :
          < ReadOnlyRootfs
          | WritableRootfs : { allowance : Quantity Bytes }
          >
      , logHeadroom : Quantity Bytes
      }
  , resources             : Resources
  }
```

## 2. Images and the kubelet filesystem layout

```text
ImageLayer =
  { blobDigest     : OciObjectDigest
  , compressedBytes: Quantity Bytes
  , chainId        : SnapshotChainId
  , unpackedBytes  : Quantity Bytes
  }

ImageArtifact =
  { identity           : ImageIdentity      -- which image this is; closed, never a free digest
  , manifestListDigest : ImageDigest        -- which build of it
  , manifestListBytes  : Quantity Bytes
  , platforms          : NonEmpty
      { platform          : OsArch
      , childDigest       : ImageDigest
      , childManifestBytes: Quantity Bytes
      , configDigest      : OciObjectDigest
      , configBytes       : Quantity Bytes
      , layers            : NonEmpty ImageLayer
      , peakImportWorkspace : Quantity Bytes
      }
  }

NodeImageStorageImportDemand =
  { image       : ImageArtifact
  , targets     : NonEmptySet ProvisionedNodeTarget
  , concurrency : ImagePullConcurrencyPolicy
  , model       : NodeImageStorageModelVersion
  }

ProvisionedImageArtifact = -- private selected-platform content projection
  { source          : ImageArtifact
  , selected        : NonEmptyMap OsArch ImageDigest
  , contentObjects  : Map OciObjectDigest (Quantity Bytes)
  , snapshotChains  : Map SnapshotChainId (Quantity Bytes)
  , importWorkspace : Quantity Bytes
  , sourceEquality  : ImageArtifactSelectedPlatformContentEqualityWitness
  }

NodeFilesystemBacking =
  { carve : DiskCarveId, allocatableBytes : Quantity Bytes }

ImagePullConcurrencyPolicy =
  < Serial
  | BoundedParallel : PositiveNatural
  >

KubeletFilesystemLayout =
  < Unified :
      { nodefs : NodeFilesystemBacking }
  | SplitRuntime :
      { nodefs : NodeFilesystemBacking
      , imagefs : NodeFilesystemBacking
      }
  | SplitImage :
      { nodefs : NodeFilesystemBacking
      , imagefs : NodeFilesystemBacking
      , support : SplitImageRuntimeWitness
      }
  >

resolvePodRuntimeRole
  :: KubeletFilesystemLayout
  -> PodRuntimeRole
  -> NodeFilesystemBacking

resolveImageStorageRole
  :: KubeletFilesystemLayout
  -> ImageStorageRole
  -> NodeFilesystemBacking
-- Unified: all roles -> nodefs
-- SplitRuntime: KubeletNodefs -> nodefs; CriRuntimeRoot -> imagefs (= containerfs)
--               ImageContentRoot -> imagefs
-- SplitImage: KubeletNodefs/CriRuntimeRoot -> nodefs (= containerfs)
--             ImageContentRoot -> imagefs

NodeLocalStorageCapacity =
  { podEphemeralAllocatable : Quantity Bytes
  , filesystems             : KubeletFilesystemLayout
  , imageStorageModel       : NodeImageStorageModelVersion
  , imagePullConcurrency    : ImagePullConcurrencyPolicy
  , kubeletMetadataModel    : KubeletRuntimeMetadataModelVersion
  }
```

## 3. Provider node capacity and per-instance templates

```text
ProviderPodSlotPolicy =
  { catalogMaximum : PositiveNatural
  , systemReserve  : Natural
  , allocatable    : PositiveNatural
  , partitionExact : ProviderPodSlotCatalogReserveAllocatableEqualityWitness
  }

ProviderCniSlotPolicy =
  { catalogMaximum : PositiveNatural
  , systemReserve  : Natural
  , allocatable    : PositiveNatural
  , partitionExact : ProviderCniSlotCatalogReserveAllocatableEqualityWitness
  }

ProviderAttachSlotPolicy =
  { catalogMaximum : PositiveNatural
  , systemReserve  : Natural
  , allocatable    : PositiveNatural
  , partitionExact : ProviderAttachSlotCatalogReserveAllocatableEqualityWitness
  }

NodeCapacity =
  { allocatableCpu        : Quantity Cpu
  , allocatableMemory     : Quantity Bytes
  , allocatablePods       : PositiveNatural
  , allocatableCniSlots   : Map CniDriverId PositiveNatural
  , attachableVolumes     : Map CsiDriverId PositiveNatural
  , cpuOvercommit         : CpuOvercommitPolicy
  , localStorage          : NodeLocalStorageCapacity
  , accelerator           : NodeAcceleratorOffering
  }

-- A reusable elastic/provider class is a recipe for one future node, not an
-- already-existing NodeCapacity. Its ids are class-local template names.
ProviderNodeCapacityTemplate =
  { allocatableCpu       : Quantity Cpu
  , allocatableMemory    : Quantity Bytes
  , podSlots             : ProviderPodSlotPolicy
  , cniSlots             : Map CniDriverId ProviderCniSlotPolicy
  , attachableVolumes    : Map CsiDriverId ProviderAttachSlotPolicy
  , localDisks           : NonEmpty PerInstanceDiskTemplate
  , cpuOvercommit        : CpuOvercommitPolicy
  , localStorage         : PerInstanceNodeLocalStorageTemplate
  , accelerator          : PerInstanceAcceleratorOffering
  }

ProviderInstanceId =
  { account : CloudAccountId
  , cluster : ClusterId
  , class   : ProviderNodeClassId
  , ordinal : Natural
  }

PerInstanceDiskTemplate =
  { id               : DiskTemplateId
  , backing          :
      < InstanceStore :
          { skuDevice : ProviderLocalDeviceName
          , provisionedRawBytes : Quantity Bytes
          , presentation : FilesystemPresentation
          }
      | EphemeralRootEbs :
          { policy : ProviderNodeRootVolumePolicy }
      >
  , systemReserve    : ProviderUsableDiskCarveTemplate
  , carves           : NonEmpty ProviderUsableDiskCarveTemplate
  }

ProviderNodeRootVolumePolicy =
  { volumeType  : ProviderVolumeType
  , presentation: FilesystemPresentation
  , allocation  : BackingAllocationPolicy
  }

ProvisionedNodeRootVolumeRequest = -- private constructor
  { instance            : ProviderInstanceId
  , diskTemplate        : DiskTemplateId
  , account             : CloudAccountId
  , volumeType          : ProviderVolumeType
  , requiredUsableBytes : Quantity Bytes
  , presentation        : FilesystemPresentation
  , allocation          : BackingAllocationPolicy
  , sizeGiB             : PositiveNatural
  , provisionedBytes    : Quantity Bytes
  , witness             : BackingAllocationWitness
  , sourceEquality      :
      ProviderInstanceDiskAccountRootPolicyRequestEqualityWitness
  }

ProviderUsableDiskCarveTemplate =
  { id                  : DiskCarveTemplateId
  , requiredUsableBytes : Quantity Bytes
  }

ProvisionedPerInstanceDiskTemplate = -- private constructor
  { instance            : ProviderInstanceId
  , source              : PerInstanceDiskTemplate
  , requiredUsableBytes : Quantity Bytes
  , provisionedRawBytes : Quantity Bytes
  , mountedUsableBytes  : Quantity Bytes
  , presentation        : FilesystemPresentation
  , rootRequest         : Optional ProvisionedNodeRootVolumeRequest
  , carves              :
      NonEmptyMap DiskCarveTemplateId ProviderUsableDiskCarveTemplate
  , carveKeys           :
      ProviderUsableDiskCarveMapKeyEmbeddedTemplateIdentityEqualityWitness
  , rawToUsable         :
      ProviderDiskRawPresentationMountedUsableCapacityWitness
  , nestedFit           :
      ProviderSystemReserveAndUniqueCarvesFitMountedUsableBytesExactlyOnceWitness
  , backingArm          :
      InstanceStoreRawBytesOrEphemeralRootRequestExactlyMatchesSourceWitness
  , sourceEquality      :
      ProviderInstanceDiskSourceGeometryCarveRootRequestEqualityWitness
  }
-- Provider carve-template bytes are explicitly usable filesystem bytes. Checked construction first derives
-- one mounted-usable capacity from the SKU-pinned raw instance-store bytes or the allocation-rounded root-EBS
-- request, then proves systemReserve + Σ unique carves <= mountedUsableBytes. No usable carve enters a raw
-- parent sum, and no raw provider byte count is compared directly with a usable filesystem role.

PerInstanceCarveRef =
  { disk : DiskTemplateId, carve : DiskCarveTemplateId }

PerInstanceFilesystemRef =
  { carve : PerInstanceCarveRef, allocatableBytes : Quantity Bytes }

PerInstanceKubeletFilesystemLayout =
  < Unified :
      { nodefs : PerInstanceFilesystemRef }
  | SplitRuntime :
      { nodefs : PerInstanceFilesystemRef
      , imagefs : PerInstanceFilesystemRef
      }
  | SplitImage :
      { nodefs : PerInstanceFilesystemRef
      , imagefs : PerInstanceFilesystemRef
      , requiredRuntime : SplitImageRuntimeRequirement
      }
  >

PerInstanceNodeLocalStorageTemplate =
  { podEphemeralAllocatable : Quantity Bytes
  , filesystems             : PerInstanceKubeletFilesystemLayout
  , imageStorageModel       : NodeImageStorageModelVersion
  , imagePullConcurrency    : ImagePullConcurrencyPolicy
  , kubeletMetadataModel    : KubeletRuntimeMetadataModelVersion
  }

PerInstanceAcceleratorSlot = -- private checked constructor after dhall-typecheck decode
  { id                   : AcceleratorSlotTemplateId
  , profile              : AcceleratorProfile
  , rawVram              : Quantity Bytes
  , driverRuntimeReserve : Quantity Bytes
  , allocatableVram      : Quantity Bytes
  , vramPartition        :
      AcceleratorDriverReservePlusAllocatableWithinRawVramWitness
  }

PerInstanceAcceleratorLink =
  { from : AcceleratorSlotTemplateId
  , to   : AcceleratorSlotTemplateId
  , kind : < PciePeerAccess | NvLink >
  }

PerInstanceAcceleratorOffering =
  < None
  | CudaOffering :
      { devices : NonEmpty PerInstanceAcceleratorSlot
      , links   : List PerInstanceAcceleratorLink
      }
  >
```

## 4. Physical hosts, disks, and carves

```text
PhysicalHostCapacity =
  { allocatableCpu    : Quantity Cpu
  , allocatableMemory : Quantity Bytes
  , diskPartitions    : NonEmpty PhysicalDiskPartition
  , accelerator       : HostAcceleratorOffering
  }

PhysicalDiskPartition =
  { backing             : PhysicalDiskBackingId
  , allocatableRawBytes : Quantity Bytes
  , systemReserve       : NamedDiskCarve PhysicalRawExtent
  , vmDisks             : List VmDiskCarve
  , directNodePools     : List (KubeletFilesystemCarves PhysicalRawExtent)
  , retainedPools       : List RetainedStoragePool
  , hostCachePools      : List HostCachePool
  , hostStoragePools    : List HostStoragePool
  }

DiskParentExtent = < PhysicalRawExtent | VmGuestUsableExtent >

NamedDiskCarve parent =
  < ExactParentExtent :
      { id          : DiskCarveId
      , parentBytes : Quantity Bytes
      }
  | PresentedUsableExtent :
      { id                  : DiskCarveId
      , requiredUsableBytes : Quantity Bytes
      , presentation        : VolumePresentation
      , allocation          : BackingAllocationPolicy
      }
  >

ProvisionedNamedDiskCarve parent = -- private constructor
  { source          : NamedDiskCarve parent
  , id              : DiskCarveId
  , parentDebitBytes: Quantity Bytes
  , witness         : NamedCarveParentDomainPresentationAllocationWitness parent
  , sourceEquality  : NamedCarveSourceIdentityParentDebitEqualityWitness
  }
-- PhysicalRawExtent parent debits are raw physical bytes. VmGuestUsableExtent parent debits are usable
-- bytes inside the already-provisioned VM filesystem. The parent index prevents adding either unit to the
-- other; PresentedUsableExtent derives its parent debit through presentation/allocation geometry.

RetainedStoragePool =
  { id : BackingId, carve : NamedDiskCarve PhysicalRawExtent }

HostCachePool =
  { id : CacheBackingId, carve : NamedDiskCarve PhysicalRawExtent }

HostStoragePurpose =
  < HostWorkerLocal | BuildScratch | ToolInstall >

HostStoragePool =
  { id : HostStorageBackingId
  , purpose : HostStoragePurpose
  , carve : NamedDiskCarve PhysicalRawExtent
  }

VmDiskCarve =
  { id           : DiskCarveId
  , presentation : FilesystemPresentation
  , allocation   : BackingAllocationPolicy
  , guestSystem  : NamedDiskCarve VmGuestUsableExtent
  , kubelet      : KubeletFilesystemCarves VmGuestUsableExtent
  }

ProvisionedVmDiskCarve = -- private constructor
  { id                  : DiskCarveId
  , requiredUsableBytes : Quantity Bytes
  , provisionedBytes    : Quantity Bytes
  , presentation        : FilesystemPresentation
  , allocation          : BackingAllocationPolicy
  , witness             : BackingAllocationWitness
  , nestedCarves        : Map DiskCarveId (ProvisionedNamedDiskCarve VmGuestUsableExtent)
  , nestedFit           : VmGuestUsableExtentExactlyOnceFitWitness
  , sourceEquality      : VmDiskSourceIdentityGeometryNestedCarveEqualityWitness
  }

KubeletFilesystemCarves parent =
  < Unified :
      { nodefs : NamedDiskCarve parent }
  | SplitRuntime :
      { nodefs : NamedDiskCarve parent
      , imagefs : NamedDiskCarve parent
      }
  | SplitImage :
      { nodefs : NamedDiskCarve parent
      , imagefs : NamedDiskCarve parent
      }
  >

ProvisionedPhysicalDiskPartition = -- private provision-seal result
  { source          : PhysicalDiskPartition
  , carves          : Map DiskCarveId (ProvisionedNamedDiskCarve PhysicalRawExtent)
  , vmDisks         : Map DiskCarveId ProvisionedVmDiskCarve
  , parentDebit     : Quantity Bytes
  , residualRawBytes: Residual Bytes
  , exactOnceFit    : PhysicalRawExtentChildIdentityAndSumWitness
  , sourceEquality  : PhysicalPartitionSourceBackingChildDomainEqualityWitness
  }
```

## 5. BookKeeper and ZooKeeper

```text
BookieSlot =
  { id                     : BookieId
  , claim                  : StatefulSetClaimSlot
  , backing                : BackingId
  , journalAndIndexReserve : Quantity Bytes
  }

BookKeeperGeometry =
  { bookies             : NonEmpty BookieSlot
  , ensembleSize        : PositiveNatural
  , writeQuorum         : PositiveNatural
  , ackQuorum           : PositiveNatural
  , ledgerSegmentBytes  : Quantity Bytes
  , faultPolicy         :
      { maxSimultaneousUnavailableBookies : PositiveNatural }
  }

BookKeeperLogicalDemand =
  { retainedHotBytes     : Quantity Bytes
  , openLedgerHeadroom   : Quantity Bytes
  , inFlightOffloadBytes : Quantity Bytes
  , deletionLagBytes     : Quantity Bytes
  }

ZooKeeperMetadataEntryDemand =
  { path            : ZooKeeperPath
  , maxPayloadBytes : Quantity Bytes
  , lifetime        : < Persistent | SessionEphemeral : ZooKeeperSessionClassId >
  }

ZooKeeperChurnBudget =
  { maxTransactionsPerWindow : PositiveNatural
  , transactionWindow        : FiniteDuration
  , maxConcurrentSessions    : PositiveNatural
  , maxWatches               : PositiveNatural
  , retainedSnapshots        : PositiveNatural
  , retainedTransactionLogs  : PositiveNatural
  , maxUnavailableMembers    : PositiveNatural
  }

ZooKeeperMemberDemand =
  { id       : ZooKeeperMemberId
  , resource : PodResourceEnvelope
  , volume   : DeclaredVolumeDemand
  }

ZooKeeperMetadataStoreDemand =
  { members : NonEmpty ZooKeeperMemberDemand
  , entries : NonEmpty ZooKeeperMetadataEntryDemand
  , churn   : ZooKeeperChurnBudget
  , model   : ZooKeeperStorageModelVersion
  }

ProvisionedZooKeeperMetadataStoreDemand = -- private constructor
  { members           : NonEmpty
      { id       : ZooKeeperMemberId
      , resource : PodResourceEnvelope
      , volume   : ProvisionedVolumeDemand
      }
  , logicalPeak       : Quantity Bytes
  , recoveryWorkspace : Map ZooKeeperMemberId (Quantity Bytes)
  , witness           : ZooKeeperCapacityWitness
  }

PulsarMetadataStoreDemand =
  < ZooKeeper : ZooKeeperMetadataStoreDemand >
```

## 6. Object store, Pulumi state, and the producer arms

```text
LogicalObjectExtent =
  { count : PositiveNatural, maxBytesEach : Quantity Bytes }

LogicalObjectSet = List LogicalObjectExtent

ObjectStoreObjectId =
  { store  : ObjectStoreId
  , tenant : TenantId
  , bucket : BucketId
  , key    : ObjectKey
  }

ProvisionedObjectStoreLogicalPeak = -- private constructor
  { residentObjects  : Map ObjectStoreObjectId (Quantity Bytes)
  , futureResidentExtents : LogicalObjectSet
  , transientExtents : LogicalObjectSet
  , derivedPeak      : Quantity Bytes
  , admissions       : NonEmptyMap ObjectStoreWriterId ObjectStoreMutationAdmissionWitness
  , witness          : ObjectStorePeakWitness
  }

ObjectStoreRetentionBudget =
  { maxAdditionalResidentExtents : NonEmpty LogicalObjectExtent
  , maxRetention                 : FiniteDuration
  }

ObjectStoreFailureBudget =
  { maxFailedWriteSetsPerWindow : PositiveNatural
  , failureWindow               : FiniteDuration
  , orphanGcHorizon             : FiniteDuration
  }

ObjectStoreWriteBudget =
  { maxConcurrentWriteSets : PositiveNatural
  , maxWriteSet            : NonEmpty LogicalObjectExtent
  , failure                : ObjectStoreFailureBudget
  }

ObjectStoreMutationAdmission =
  { model  : ObjectStoreAdmissionModelVersion
  , writer : ObjectStoreWriterId
  , costModel : ObjectStoreAdmissionCostModelVersion
  }

ObjectStoreGatewayIntent = -- dhall-typecheck/ClusterIR source; writers come from producer intents
  { gateway : ObjectStoreGatewayId
  , model   : ObjectStoreGatewayExecutionModelVersion
  }

ObjectStoreDemand =
  { budget            : StorageBudgetId
  , committedResident : Map ObjectStoreObjectId (Quantity Bytes)
  , retention         : ObjectStoreRetentionBudget
  , writes            : ObjectStoreWriteBudget
  , mutationAdmission : ObjectStoreMutationAdmission
  }

ContentStoreLogicalDemand = ObjectStoreDemand

PulsarOffloadObjectDemand =
  { topic                 : TopicId
  , budget                : StorageBudgetId
  , retainedBytes         : Quantity Bytes
  , ledgerSegmentBytes    : Quantity Bytes
  , maxConcurrentOffloads : PositiveNatural
  , maxSegmentsPerWindow  : PositiveNatural
  , offloadWindow         : FiniteDuration
  , deletionLag           : FiniteDuration
  , failure                : ObjectStoreFailureBudget
  , model                 : PulsarOffloadObjectModelVersion
  , mutationAdmission     : ObjectStoreMutationAdmission
  }

PulumiStateFieldDemand =
  { path              : PulumiStateFieldPath
  , maxCanonicalBytes : Quantity Bytes
  , secrecy           : < Plain | Secret >
  }

PulumiStateEntryDemand =
  { identity : PulumiResourceStateId
  , fields   : NonEmpty PulumiStateFieldDemand
  }

PulumiCheckpointObjectDemand =
  { stack                : PulumiStackId
  , budget               : StorageBudgetId
  , entries              : NonEmpty PulumiStateEntryDemand
  , maxRetainedRevisions : PositiveNatural
  , updateConcurrency    : < Serial >
  , failure              : ObjectStoreFailureBudget
  , model                : PulumiCheckpointModelVersion
  , mutationAdmission    : ObjectStoreMutationAdmission
  }

ProvisionedPulumiCheckpointObjectDemand = -- private provision result
  { source          : PulumiCheckpointObjectDemand
  , logicalPeak     : ProvisionedObjectStoreLogicalPeak
  , storageBudget   : StorageBudgetId
  , gateway         : ProvisionedObjectStoreAdmissionGateway
  , entryDomain     : PulumiCheckpointEntryFieldDomainEqualityWitness
  , sourceEquality  :
      PulumiCheckpointStackBudgetPeakGatewayMutationEqualityWitness
  }

ControlPlaneStateEntryDemand =
  { identity          : ControlPlaneStateId
  , kind              :
      < InForceSpecSnapshot
      | ManagedResourceRegistry
      | ReconcileJournal
      | ValidationLedger
      | JobCompletion
      >
  , maxCanonicalBytes : Quantity Bytes
  }

ControlPlaneStateObjectDemand =
  { budget               : StorageBudgetId
  , entries              : NonEmpty ControlPlaneStateEntryDemand
  , maxRetainedVersions  : PositiveNatural
  , updateConcurrency    : < Serial >
  , failure              : ObjectStoreFailureBudget
  , model                : ControlPlaneStateModelVersion
  , mutationAdmission    : ObjectStoreMutationAdmission
  }

PulumiPluginDemand =
  { identity         : PulumiPluginId
  , digest           : ContentAddress
  , installedBytes   : Quantity Bytes
  , peakInstallBytes : Quantity Bytes
  }

PulumiDeployUnit =
  { id           : PulumiDeployId
  , executionUnit: ExecutionUnitId
  , dependsOn    : List PulumiDeployId
  , state        : NonEmpty PulumiStateEntryDemand
  , plugins      : NonEmpty PulumiPluginId
  , cache        : InClusterCacheDemand
  , cacheEquality:
      PulumiDeployExecutionUnitCacheSourceEqualityWitness
  }

PulumiExecutionDemand =
  { deploys          : NonEmpty PulumiDeployUnit
  , concurrency      : < Serial | BoundedParallel : PositiveNatural >
  , plugins          : NonEmpty PulumiPluginDemand
  , pluginVolume     : VolumeId
  , workspaceVolume  : VolumeId
  , model            : PulumiExecutionCostModelVersion
  }

PulumiExecutionVolumeRole = < PluginVolume | WorkspaceVolume >

ProvisionedPulumiExecutionVolume role = -- private constructor
  { role                : role
  , volume              : VolumeId
  , requiredUsableBytes : Quantity Bytes
  , provisionedRawBytes : Quantity Bytes
  , presentation        : VolumePresentation
  , allocation          : BackingAllocationPolicy
  , witness             : BackingAllocationWitness
  , sourceEquality      :
      PulumiExecutionRoleSourceVolumePeakPresentationAllocationEqualityWitness
  }
-- The plugin/workspace peak is a required-usable demand. It first resolves the named volume's presentation
-- and allocation policy and derives a raw debit; neither peak is compared directly with raw backing supply.

ProvisionedPulumiExecutionDemand = -- private constructor
  { source        : PulumiExecutionDemand
  , executorPods  : NonEmptyMap PulumiDeployId PodResourceEnvelope
  , deployGraph   : NonEmptyMap PulumiDeployId (Set PulumiDeployId)
  , pluginObjects : NonEmptyMap PulumiPluginId PulumiPluginDemand
  , pluginVolume  : ProvisionedPulumiExecutionVolume PluginVolume
  , workspaceVolume : ProvisionedPulumiExecutionVolume WorkspaceVolume
  , caches        : NonEmptyMap PulumiDeployId (ProvisionedCacheDemand InClusterCacheOwner)
  , sourceEquality:
      PulumiDeployGraphPluginDigestProvisionedVolumeExecutorCacheDomainEqualityWitness
  , witness       : PulumiExecutionWitness
  }

ObjectStoreProducerIntent = -- dhall-typecheck/ClusterIR source union
  < AppBucket       : ObjectStoreDemand
  | Content         : ContentStoreLogicalDemand
  | Registry        : RegistryStorageIntent
  | PulsarOffload   : PulsarOffloadObjectDemand
  | PulumiCheckpoint: PulumiCheckpointObjectDemand
  | ControlPlaneState: ControlPlaneStateObjectDemand
  >

ObjectStoreProducerDemand = -- binder output; normalized six-arm expansion of ObjectStoreProducerIntent
  < AppBucket       : ObjectStoreDemand
  | Content         : ContentStoreLogicalDemand
  | Registry        : RegistryStorageDemand
  | PulsarOffload   : PulsarOffloadObjectDemand
  | PulumiCheckpoint: PulumiCheckpointObjectDemand
  | ControlPlaneState: ControlPlaneStateObjectDemand
  >

ObjectStoreAdmissionGatewayDemand = -- binder output from ObjectStoreGatewayIntent + producer writers
  { gateway : ObjectStoreGatewayId
  , writers : NonEmptyMap ObjectStoreWriterId ObjectStoreMutationAdmission
  , model   : ObjectStoreGatewayExecutionModelVersion
  }

ProvisionedObjectStoreAdmissionGateway = -- private constructor
  { gateway      : ObjectStoreGatewayId
  , execution    : PodResourceEnvelope
  , admitted     : NonEmptyMap ObjectStoreWriterId ObjectStoreMutationAdmissionWitness
  , witness      : ObjectStoreGatewayCapacityWitness
  }
```

## 7. MinIO geometry and claim slots

```text
MinioDrive =
  { id               : MinioDriveId
  , claim            : StatefulSetClaimSlot
  , backing          : BackingId
  }

StatefulSetClaimSlot =
  { statefulSet : StatefulSetId
  , template    : VolumeClaimTemplateId
  , ordinal     : Natural
  }

UniformClaimPlan = -- private constructor
  { statefulSet          : StatefulSetId
  , template             : VolumeClaimTemplateId
  , ordinals             : NonEmpty Natural
  , members              : Map StatefulSetClaimSlot ProvisionedVolumeDemand
  , presentation         : VolumePresentation
  , allocation           : BackingAllocationPolicy
  , requiredUsableBytes  : Quantity Bytes
  , provisionedBytes     : Quantity Bytes
  , perBackingDebit      : Map BackingId (Quantity Bytes)
  , witness              : UniformClaimWitness
  }

MinioErasureSet =
  { id           : ErasureSetId
  , drives       : NonEmpty MinioDrive
  , dataShards   : PositiveNatural
  , parityShards : PositiveNatural
  }

MinioErasureGeometry =
  { sets                     : NonEmpty MinioErasureSet
  , shardBlockBytes          : Quantity Bytes
  , metadataReservePerDrive  : Quantity Bytes
  , healingWorkspacePerDrive : Quantity Bytes
  , faultPolicy              :
      { maxUnavailablePerErasureSet : PositiveNatural
      , replacementDrives            : NonEmpty MinioDrive
      }
  }
```

## 8. Accelerators

```text
AcceleratorDevice = -- private checked constructor
  { id                   : AcceleratorDeviceId
  , profile              : AcceleratorProfile
  , rawVram              : Quantity Bytes
  , driverRuntimeReserve : Quantity Bytes
  , allocatableVram      : Quantity Bytes
  , vramPartition        :
      AcceleratorDriverReservePlusAllocatableWithinRawVramWitness
  }

ObservedAcceleratorDevice =
  { declared        : AcceleratorDevice
  , currentFreeVram : Residual Bytes
  }

ObservedCudaOffering =
  { devices : NonEmpty ObservedAcceleratorDevice
  , links   : List AcceleratorLink
  }

AcceleratorLink =
  { from : AcceleratorDeviceId
  , to   : AcceleratorDeviceId
  , kind : < PciePeerAccess | NvLink >
  }

CudaDeviceOffering =
  { devices : NonEmpty AcceleratorDevice
  , links   : List AcceleratorLink
  }

VramShard =
  { id : VramShardId, bytes : Quantity Bytes }

AcceleratorInterconnectRequirement =
  < NoPeerRequirement
  | FullyConnectedPeerAccess
  | FullyConnectedNvLink
  >

ShardingPlan =
  { shards       : NonEmpty VramShard
  , interconnect : AcceleratorInterconnectRequirement
  }

AcceleratorWorkloadClass =
  < ServedModel | TrainingJob | JitCompilation | LibraryWork >

AcceleratorWorkloadSource =
  < ServedModel   : ModelArtifactId
  | TrainingJob   : TrainingJobId
  | JitCompilation: JitWorkId
  | LibraryWork   : AcceleratorLibraryWorkId
  >

AcceleratorResidencyClass =
  < Weights | ServingKvCache | Activations | OptimizerState | JitWorkspace | LibraryWorkspace >

AcceleratorResidencyPlacement =
  < Unsharded
  | ReplicatedPerDevice
  | Sharded : ShardingPlan
  >

AcceleratorResidencyDemand =
  { id        : AcceleratorResidencyId
  , class     : AcceleratorResidencyClass
  , bytes     : Quantity Bytes
  , placement : AcceleratorResidencyPlacement
  }

AcceleratorCoexistencePolicy =
  { maxResidentByClass : NonEmptyMap AcceleratorWorkloadClass PositiveNatural
  , maxRunningByClass  : NonEmptyMap AcceleratorWorkloadClass PositiveNatural
  , model              : AcceleratorCoexistenceModelVersion
  }

CudaWorkloadDemand =
  { residency : NonEmptyMap AcceleratorResidencyId AcceleratorResidencyDemand }

MetalWorkloadDemand =
  { residency : NonEmptyMap AcceleratorResidencyId
      { class : AcceleratorResidencyClass, bytes : Quantity Bytes }
  }

CudaOwnerDemand = -- unprovisioned wholesale-owner input
  { profile     : AcceleratorProfile
  , devices     : PositiveNatural
  , sources     : NonEmptyMap AcceleratorWorkloadId AcceleratorWorkloadSource
  , workloads   : NonEmptyMap AcceleratorWorkloadId CudaWorkloadDemand
  , coexistence : AcceleratorCoexistencePolicy
  }

MetalOwnerDemand = -- unprovisioned wholesale-owner input
  { profile     : MetalProfile
  , sources     : NonEmptyMap AcceleratorWorkloadId AcceleratorWorkloadSource
  , workloads   : NonEmptyMap AcceleratorWorkloadId MetalWorkloadDemand
  , coexistence : AcceleratorCoexistencePolicy
  }

ProvisionedCudaOwnerDemand = -- private ProvisionedSpec member
  { epochs      : NonEmptyMap AcceleratorEpochId (Map AcceleratorDeviceId (Quantity Bytes))
  , assignments : AcceleratorWorkloadAssignmentWitness
  , witness     : AcceleratorCapacityWitness
  }

ProvisionedMetalOwnerDemand = -- private ProvisionedSpec member
  { epochs  : NonEmptyMap AcceleratorEpochId (Quantity Bytes)
  , witness : AcceleratorCapacityWitness
  }

PodAcceleratorDemand =
  < None | Cuda : { owner : ContainerId, demand : CudaOwnerDemand } >

HostAcceleratorDemand =
  < None | Cuda : CudaOwnerDemand | AppleMetal : MetalOwnerDemand >

NodeAcceleratorOffering =
  < None
  | CudaOffering : CudaDeviceOffering
  >

HostAcceleratorOffering =
  < None
  | CudaOffering       : CudaDeviceOffering
  | AppleMetalOffering : MetalProfile
  >

ObservedHostAcceleratorInventory =
  { host             : HostId
  , offering         : HostAcceleratorOffering
  , cudaDevices      : Map AcceleratorDeviceId
      { profile         : AcceleratorProfile
      , rawVram         : Quantity Bytes
      , runtimeReserve  : Quantity Bytes
      , allocatableVram : Quantity Bytes
      , currentFreeVram : Residual Bytes
      , vramPartition   :
          ObservedDriverReservePlusAllocatableWithinRawVramReadbackWitness
      , hold            : Optional HostReservationId
      }
  , metal            : Optional
      { profile              : MetalProfile
      , allocatedUnifiedMemory : Residual Bytes
      }
  , sourceEquality   : ObservedHostAcceleratorSourceDomainWitness
  , fingerprint      : InventoryFingerprint
  }
```

## 9. Kubelet runtime metadata and node storage accounting

```text
KubeletMappedFileDemand =
  { id           : MappedFileVolumeId
  , source       :
      < ConfigMap
      | Secret
      | DownwardApi
      | ServiceAccountToken
      >
  , payloadBytes : Quantity Bytes
  , accounting   : < NodefsEphemeral | Memory >
  , model        : KubeletMappedFileModelVersion
  }

PodRuntimeMetadataSource = -- structural pod input; no authorable byte total
  { networkAttachments : NonEmpty NetworkAttachmentId
  , mounts             : Map PodVolumeMountId
      { container : ContainerId
      , volume    : PodVolumeId
      }
  }

KubeletRuntimeMetadataShape = -- derived from structural Pod source; no authorable bytes/routes
  { sourceUnit         : ExecutionUnitId
  , sandboxCount       : PositiveNatural
  , podDirectoryCount  : PositiveNatural
  , runtimeStateCount  : PositiveNatural
  , cniStateCount      : PositiveNatural
  , volumeMetadataCount: Natural
  , mountMetadataCount : Natural
  , model              : KubeletRuntimeMetadataModelVersion
  }

PlannedKubeletRuntimeMetadataDemand =
  { slot  : PlannedExecutionSlotId
  , shape : KubeletRuntimeMetadataShape
  }

ObservedKubeletRuntimeMetadataDemand =
  { podUid  : PodUid
  , shape   : KubeletRuntimeMetadataShape
  , source  : ObservedExecutionSourceWitness
  }

KubeletRuntimeMetadataDemand =
  < Planned : PlannedKubeletRuntimeMetadataDemand
  | Observed: ObservedKubeletRuntimeMetadataDemand
  >

ProvisionedKubeletRuntimeMetadataDemand identity demand = -- private ProvisionedSpec member
  { identity           : identity
  , demand             : demand
  , components         : NonEmptyMap RuntimeStorageComponentId
      { role  : PodRuntimeRole
      , bytes : Quantity Bytes
      }
  , bytesByRole        : NonEmptyMap PodRuntimeRole (Quantity Bytes)
  , backingDebits      : NonEmptyMap ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , identityEquality   : RuntimeMetadataDemandIdentityWitness identity demand
  , roleEquality       : RuntimeMetadataRoleGroupingWitness
  , backingEquality    : RuntimeMetadataBackingGroupingWitness
  , witness            : KubeletRuntimeMetadataWitness
  }

ProvisionedPlannedKubeletRuntimeMetadataDemand =
  ProvisionedKubeletRuntimeMetadataDemand
    PlannedExecutionSlotId PlannedKubeletRuntimeMetadataDemand

ProvisionedObservedKubeletRuntimeMetadataDemand =
  ProvisionedKubeletRuntimeMetadataDemand
    PodUid ObservedKubeletRuntimeMetadataDemand

PodRuntimeRole = < KubeletNodefs | CriRuntimeRoot >
ImageStorageRole = < ImageContentRoot | CriRuntimeRoot >
RuntimeFilesystemRole = < KubeletNodefs | CriRuntimeRoot | ImageContentRoot > -- resolver codomain only

NodeRuntimeStorageComponentKey identity =
  < Pod :
      { accounting : identity
      , component  : RuntimeStorageComponentId
      }
  | Image : NodeImageStorageComponentId
  >

ProvisionedNodeImageStorageDemand =
  { target          : ProvisionedNodeTarget
  , model           : NodeImageStorageModelVersion
  , components      : NonEmptyMap NodeImageStorageComponentId
      { role  : ImageStorageRole
      , bytes : Quantity Bytes
      }
  , contentObjects  : Map OciObjectDigest (Quantity Bytes)
  , snapshotChains  : Map SnapshotChainId (Quantity Bytes)
  , importWorkspace : Residual Bytes
  , roleEquality    : NodeImageRoleGroupingWitness
  , witness         : NodeImageStorageWitness
  }

ProvisionedKubeletFilesystemLayout =
  < Fixed :
      { target     : ProvisionedNodeTarget
      , fixed      : ProvisionedNodeTargetIsFixedWitness
      , layout     : KubeletFilesystemLayout
      , roleRoutes : NonEmptyMap RuntimeFilesystemRole ProvisionedRuntimeOrStorageBackingRef
      }
  | Elastic :
      { target     : ProvisionedNodeTarget
      , elastic    : ProvisionedNodeTargetIsElasticWitness
      , layout     : PerInstanceKubeletFilesystemLayout
      , roleRoutes : NonEmptyMap RuntimeFilesystemRole ProvisionedRuntimeOrStorageBackingRef
      }
  >

ProvisionedNodeRuntimeStorageCommon identity =
  { target            : ProvisionedNodeTarget
  , layout            : ProvisionedKubeletFilesystemLayout
  , metadataModel     : KubeletRuntimeMetadataModelVersion
  , imageModelVersion : NodeImageStorageModelVersion
  , imageModel        : ProvisionedNodeImageStorageDemand
  , nodeImageEquality : NodeImageTargetLayoutModelEqualityWitness
  , ownership         : RuntimeStorageComponentOwnershipWitness identity
  , backingDebits     : NonEmptyMap ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , targetEquality    : RuntimeStorageTargetAndLayoutEqualityWitness
  , backingEquality  : NodeRuntimeBackingGroupingWitness
  }

ProvisionedPlannedNodeRuntimeStorageAccounting =
  { scope             : ExecutionEpochFingerprint
  , target            : ProvisionedNodeTarget
  , common            : ProvisionedNodeRuntimeStorageCommon PlannedExecutionSlotId
  , podMetadata       : Map PlannedExecutionSlotId
      { demand : PlannedKubeletRuntimeMetadataDemand
      , provisioned : ProvisionedPlannedKubeletRuntimeMetadataDemand
      }
  , podKeyEquality    : PlannedRuntimeMetadataSlotKeyWitness
  , podDomainEquality : PlannedAssignedPodRuntimeMetadataDomainWitness
  , targetEquality    : PlannedRuntimeStorageOuterTargetEqualityWitness
  , scopeEquality     : PlannedRuntimeStorageScopeValueWitness
  }

ProvisionedObservedNodeRuntimeStorageAccounting =
  { scope             : InventoryFingerprint
  , target            : ProvisionedNodeTarget
  , common            : ProvisionedNodeRuntimeStorageCommon PodUid
  , binding           : ObservedNodeTargetBinding
  , podMetadata       : Map PodUid
      { demand : ObservedKubeletRuntimeMetadataDemand
      , provisioned : ProvisionedObservedKubeletRuntimeMetadataDemand
      }
  , podKeyEquality    : ObservedRuntimeMetadataPodUidKeyWitness
  , podDomainEquality : ObservedAssignedPodRuntimeMetadataDomainWitness
  , targetBindingEquality : ObservedRuntimeStorageTargetBindingMaterializationWitness
  , scopeEquality     : ObservedRuntimeStorageScopeValueWitness
  }

ProvisionedNodeRuntimeStorageAccounting =
  < Planned  : ProvisionedPlannedNodeRuntimeStorageAccounting
  | Observed : ProvisionedObservedNodeRuntimeStorageAccounting
  >

ObservedNodeRuntimeStorageInventory =
  { nodes : Map NodeId
      { binding         : ObservedNodeTargetBinding
      , layout          : ObservedKubeletFilesystemLayout
      , rootIdentities  : Map RuntimeFilesystemRole ObservedRuntimeRootIdentity
      , metadataModel   : KubeletRuntimeMetadataModelVersion
      , imageModel      : NodeImageStorageModelVersion
      , podComponents   : Map
          (PodUid, RuntimeStorageComponentId) ObservedRuntimeStorageComponent
      , contentObjects  : Map OciObjectDigest ObservedOciContentObject
      , snapshotChains  : Map SnapshotChainId ObservedSnapshotChain
      , pullWorkspaces  : Map ImagePullWorkItemId ObservedImagePullState
      , backingUsage    : Map DiskCarveId (Residual Bytes)
      , sourceEquality  : ObservedNodeRuntimeStorageSourceWitness
      }
  , fingerprint : InventoryFingerprint
  , nodeDomain  : ObservedNodeRuntimeStorageDomainWitness
  }

RuntimeStorageComponentOwnershipWitness identity =
  { sourceComponents : Set (NodeRuntimeStorageComponentKey identity)
  , podMetadataOwned : Set (NodeRuntimeStorageComponentKey identity)
  , imageModelOwned  : Set (NodeRuntimeStorageComponentKey identity)
  , unionExact       : Required
  , intersectionEmpty: Required
  }
```

## 10. Pod-local storage and the jit-build cache

```text
PodLocalStorageDemand =
  { diskBackedVolumes   : List { id : VolumeId, sizeLimit : Quantity Bytes }
  , mappedFiles          : List KubeletMappedFileDemand
  , memoryBackedVolumes :
      List
        { id        : VolumeId
        , sizeLimit : Quantity Bytes
        , persistence : < StageLocal : ContainerId | PodLifetime >
        , access    : NonEmpty
            { container : ContainerId
            , mode      : < ReadOnly | ReadWrite >
            }
        }
  }

CacheBudgetSource =
  < ExecutionUnit : ExecutionUnitId
  | ImageBuild    : BuildExecutionId
  | EngineProcess : EngineProcessId
  >

HostCacheSource =
  < ImageBuild    : BuildExecutionId
  | EngineProcess : EngineProcessId
  >

CacheBudgetId = -- opaque deployment/source-scoped nominal identity
  { deployment : DeploymentId
  , source     : CacheBudgetSource
  , ordinal    : Natural
  }

InClusterCacheOwner =
  { volume : VolumeId }

HostCacheOwner =
  { host    : HostId
  , backing : CacheBackingId
  }

CacheBudget owner =
  { id      : CacheBudgetId
  , owner   : owner
  , ceiling : Quantity Bytes
  }
-- Quantity is a finite, strictly positive refinement; absence is represented by no cache demand, never zero
-- or an unbounded/caller-authored elastic arm.
-- The owner index resolves to exactly one bounded pod volume or named native-host cache backing.

InClusterCacheBudget = CacheBudget InClusterCacheOwner
HostCacheBudget      = CacheBudget HostCacheOwner

InClusterCacheDemand =
  { sourceUnit : ExecutionUnitId
  , budget     : InClusterCacheBudget
  , population : CachePopulationDemand
  , sourceEquality :
      budget.id.source == ExecutionUnit sourceUnit
  }

HostCacheDemand =
  { source     : HostCacheSource
  , budget     : HostCacheBudget
  , population : CachePopulationDemand
  , sourceEquality : HostCacheSourceBudgetIdEqualityWitness
  }

AssetMaterializationDemand =
  { identity           : CatalogAssetId
  , digest             : ContentAddress
  , residentBytes      : Quantity Bytes
  , peakTemporaryBytes : Quantity Bytes
  }

CachePopulationDemand =
  { assets               : NonEmpty AssetMaterializationDemand
  , firstMissConcurrency : < Serial | BoundedParallel : PositiveNatural >
  }

CachePopulationSourceEqualityWitness =
  { selectedAssetIds     : Set CatalogAssetId
  , materializedDigests  : Set ContentAddress
  , exactAssetDigestJoin : Required
  , noDigestSizeConflict : Required
  }

ResolvedCacheSupply owner =
  { owner             : owner
  , logicalLimit      : Quantity Bytes
  , physicalBacking   : ProvisionedRuntimeOrStorageBackingRef
  , physicalCapacity  : Quantity Bytes
  , ownerRouteEquality: CacheOwnerVolumeOrHostBackingResolutionEqualityWitness
  }

CachePeakWitness owner budget objectSet derivedPeak =
  { budgetId       : budget.id
  , owner          : budget.owner
  , objectSet      : objectSet
  , derivedPeak    : derivedPeak
  , ceiling        : budget.ceiling
  , withinCeiling  : Required
  , resolvedSupply : ResolvedCacheSupply owner
  , ownerSupplyEquality : resolvedSupply.owner == budget.owner
  , ceilingWithinLogicalLimit  : Required
  , logicalLimitWithinBacking  : Required
  , sourceEquality : CachePopulationSourceEqualityWitness
  , exactProjection: Required
  }

ProvisionedCacheDemand owner = -- private constructor; renderer/enactor input
  { enclosingSource : CacheBudgetSource
  , budget       : CacheBudget owner
  , objectSet    : Map ContentAddress (Quantity Bytes)
  , derivedPeak  : Quantity Bytes
  , witness      : CachePeakWitness owner budget objectSet derivedPeak
  , sourceEquality :
      ProvisionedCacheEnclosingSourceBudgetPopulationEqualityWitness
  }
-- The target is derived only from budget.owner; there is no independent target that can be cross-paired.
-- provision proves derivedPeak = deduplicated residents + bounded concurrent temporary materialization
--                  <= budget.ceiling <= resolved volume/backing capacity.
```

## 11. Volumes, storage migration, and schema migration

```text
FilesystemPresentation =
  { fsType        : FilesystemType
  , overheadModel : FilesystemOverheadModelVersion
  }

VolumePresentation =
  < Block
  | Filesystem : FilesystemPresentation
  >

DeclaredVolumeDemand =
  { claim         : StatefulSetClaimSlot
  , backing       : BackingId
  , attachment    :
      < NodeLocal
      | Csi : { driver : CsiDriverId }
      >
  , logicalBytes  : Quantity Bytes
  , geometry      :
      < Direct
      | BookKeeper : BookieId
      | Minio      : MinioDriveId
      >
  , presentation  : VolumePresentation
  }

ProvisionedVolumeDemand = -- private constructor; renderer input
  { claim               : StatefulSetClaimSlot
  , backing             : BackingId
  , attachment          : < NodeLocal | Csi : { driver : CsiDriverId } >
  , requiredUsableBytes : Quantity Bytes
  , provisionedBytes    : Quantity Bytes
  , presentation        : VolumePresentation
  , allocation          : BackingAllocationPolicy
  , witness             : VolumeGeometryWitness
  }

PriorProvisionRefSource = -- dhall-typecheck source, branded by gadt-decode; never a prior output record
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest
  , resource   :
      < Execution
      | Volume   : StatefulSetClaimSlot
      | Registry : StorageBudgetId
      >
  }

PriorExecutionProvisionRef = opaque ref to the deployment-level Execution arm of PriorProvisionRefSource
PriorVolumeProvisionRef   = opaque ref to the Volume arm of PriorProvisionRefSource
PriorRegistryProvisionRef = opaque ref to the Registry arm of PriorProvisionRefSource

StorageMigrationPolicy =
  { model            : StorageCopyModelVersion
  , workspaceBacking : BackingId
  , copyConcurrency  : PositiveNatural
  , copyChunkBytes   : Quantity Bytes
  }

StorageMigrationIntent = -- dhall-typecheck/ClusterIR source
  { identity    : StorageMigrationId
  , old         : PriorProvisionRefSource -- must be the Volume arm
  , replacement : DeclaredVolumeDemand
  , policy      : StorageMigrationPolicy
  }

StorageMigrationDemand =
  { identity    : StorageMigrationId
  , old         : PriorVolumeProvisionRef
  , replacement : DeclaredVolumeDemand
  , policy      : StorageMigrationPolicy
  }

ProvisionedStorageMigration = -- private constructor
  { identity        : StorageMigrationId
  , old             : ProvisionedVolumeDemand
  , replacement     : ProvisionedVolumeDemand
  , workspaceBytes  : Quantity Bytes
  , copyExecution   : PodResourceEnvelope
  , perBackingPeak  : Map BackingId (Quantity Bytes)
  , witness         : StorageMigrationWitness
  }

SchemaObjectDemand =
  { identity : DatabaseSchemaObjectId
  , kind     : < Table | Index | Constraint | MaterializedView >
  , maxBytes : Quantity Bytes
  }

SchemaMigrationPolicy =
  { model                   : SchemaMigrationCostModelVersion
  , maxConcurrentOperations : PositiveNatural
  , workspaceBacking        : BackingId
  }

SchemaMigrationIntent = -- dhall-typecheck/ClusterIR source
  { identity    : SchemaMigrationId
  , database    : DatabaseId
  , dataBacking : BackingId
  , old         : Map DatabaseSchemaObjectId SchemaObjectDemand
  , replacement : Map DatabaseSchemaObjectId SchemaObjectDemand
  , policy      : SchemaMigrationPolicy
  }

SchemaMigrationDemand = normalized, unprovisioned expansion of SchemaMigrationIntent

ProvisionedSchemaMigration = -- private constructor
  { identity        : SchemaMigrationId
  , old             : Map DatabaseSchemaObjectId (Quantity Bytes)
  , replacement     : Map DatabaseSchemaObjectId (Quantity Bytes)
  , temporaryExtents: NonEmpty LogicalObjectExtent
  , walPeak         : Quantity Bytes
  , execution       : PodResourceEnvelope
  , perBackingPeak  : Map BackingId (Quantity Bytes)
  , witness         : SchemaMigrationWitness
  }
```

## 12. Patroni SQL

```text
PatroniLogicalStorageIntent = -- dhall-typecheck/ClusterIR source
  { objects               : NonEmpty SchemaObjectDemand
  , maxWalBytes           : Quantity Bytes
  , checkpointBytes       : Quantity Bytes
  , failoverReplayBytes   : Quantity Bytes
  , recoveryWorkspaceBytes: Quantity Bytes
  , model                 : PatroniStorageModelVersion
  }

PatroniLogicalStorageDemand = normalized, unprovisioned expansion of PatroniLogicalStorageIntent

SqlMutationIntent = -- dhall-typecheck/ClusterIR source
  { writer                   : SqlWriterId
  , maxConnections           : PositiveNatural
  , maxConcurrentTransactions: PositiveNatural
  , maxTransactionsPerWindow : PositiveNatural
  , transactionWindow        : FiniteDuration
  , maxWalBytesPerTransaction: Quantity Bytes
  , costModel                : SqlAdmissionCostModelVersion
  }

SqlMutationAdmission = normalized, unprovisioned expansion of SqlMutationIntent

PatroniSqlIntent = -- dhall-typecheck/ClusterIR source; contains no controller child envelope
  { database : DatabaseId
  , budget   : StorageBudgetId
  , storage  : PatroniLogicalStorageIntent
  , volume   : DeclaredVolumeDemand
  , mutation : SqlMutationIntent
  }

PatroniSqlDemand = -- binder output; still unprovisioned
  { database : DatabaseId
  , budget   : StorageBudgetId
  , children : ControllerChildEnvelope
  , storage  : PatroniLogicalStorageDemand
  , volume   : DeclaredVolumeDemand
  , mutationAdmission : SqlMutationAdmission
  }

ProvisionedPatroniSql = -- private constructor
  { database           : DatabaseId
  , children           : ProvisionedControllerChildren
  , volume             : ProvisionedVolumeDemand
  , admissionExecution : PodResourceEnvelope
  , admission           : SqlMutationAdmissionWitness
  , perBackingPeak     : Map BackingId (Quantity Bytes)
  , witness            : PatroniCapacityWitness
  }
```

## 13. Registry storage, bootstrap registry, and backend rehome

```text
RegistryStoredObject =
  { digest      : OciObjectDigest
  , storedBytes : Quantity Bytes
  , kind        : < Index | Manifest | Config | CompressedLayer >
  }

ObservedRegistryStoredObject =
  { digest      : OciObjectDigest
  , storedBytes : Quantity Bytes
  , kind        : < Index | Manifest | Config | CompressedLayer | FailedPartial >
  , observedAt  : ObservationTimestamp
  , source      : RegistryBackendInventorySourceWitness
  }

RegistryStoredArtifact =
  { reference : ImageDigest
  , objects   : NonEmpty RegistryStoredObject
  }

RegistryMutationAdmission =
  { model      : RegistryAdmissionModelVersion
  , publisher  : RegistryPublisherId
  , costModel  : RegistryAdmissionCostModelVersion
  }

RegistryStorageIntent = -- dhall-typecheck/ClusterIR source
  { budget    : StorageBudgetId
  , artifacts : NonEmpty ImageDigest -- exact-joined by binding to selected ImageArtifact metadata
  , upload    :
      { concurrency              : < Serial | BoundedParallel : PositiveNatural >
      , failureWindow            : FiniteDuration
      , maxFailedUploadsPerWindow: PositiveNatural
      , failedUploadGcHorizon    : FiniteDuration
      , model                    : RegistryUploadModelVersion
      }
  , mutationAdmission : RegistryMutationAdmission
  , backend   :
      < InterimEphemeral : { volume : VolumeId }
      | Minio : { store : ObjectStoreId }
      >
  }

RegistryStorageDemand = -- binder output; normalized and exact-joined to ImageArtifact metadata
  { budget    : StorageBudgetId
  , artifacts : NonEmpty RegistryStoredArtifact
  , upload    :
      { concurrency              : < Serial | BoundedParallel : PositiveNatural >
      , failureWindow            : FiniteDuration
      , maxFailedUploadsPerWindow: PositiveNatural
      , failedUploadGcHorizon    : FiniteDuration
      , model                    : RegistryUploadModelVersion
      }
  , mutationAdmission : RegistryMutationAdmission
  , backend   :
      < InterimEphemeral : { volume : VolumeId }
      | Minio : { store : ObjectStoreId }
      >
  }

ProvisionedRegistryStorageDemand = -- private constructor
  { objectSet       : Map OciObjectDigest (Quantity Bytes)
  , objectStorePeak : ProvisionedObjectStoreLogicalPeak
  , derivedPeak     : Quantity Bytes
  , backend         : < InterimEphemeral : VolumeId | Minio : ObjectStoreId >
  , admission       : RegistryMutationAdmissionWitness
  , witness         : RegistryStorageWitness
  }

BootstrapRegistryDemand =
  { image           : ImageArtifact
  , registryUnit    : BoundExecutionUnit
  , mutationProxy   : BoundExecutionUnit
  , storage         : RegistryStorageDemand
  , nodeImport      : NodeImageStorageImportDemand
  , sourceEquality  : BootstrapRegistryDemandSourceWitness
  }

BootstrapRegistryProvisionedVolumeProjection =
  { volume          : VolumeId
  , sizeLimit       : Quantity Bytes
  , backing         : ProvisionedRuntimeOrStorageBackingRef
  , storage         : ProvisionedRegistryStorageDemand
  , nestingEquality : RegistryEmptyDirPodEphemeralBackingEqualityWitness
  }

BootstrapRegistryControllerProjection =
  { deployment      : KubernetesObjectId
  , namespace       : NamespaceId
  , replicas        : Once
  , template        :
      { image       : ProvisionedImageArtifact
      , resource    : PodResourceEnvelope
      , volumes     : Map VolumeId BootstrapRegistryProvisionedVolumeProjection
      , identity    : KubernetesPodTemplateDigest
      }
  , service         : Optional KubernetesObjectId
  , sourceEquality  : BootstrapRegistryControllerSourceWitness
  }

BootstrapRegistryExactPodQuotaProjection =
  { namespace       : NamespaceId
  , units           : NonEmptySet ExecutionUnitId
  , pods            : PositiveNatural
  , requests        : ResourceQuotaRequestVector
  , limits          : ResourceQuotaLimitVector
  , apiObject       : KubernetesApiObjectSource
  , exactProjection : BootstrapRegistryQuotaExecutionDomainEqualityWitness
  }

ProvisionedBootstrapRegistryExecution =
  { units           : NonEmptyMap ExecutionUnitId
      { controller    : BootstrapRegistryControllerProjection
      , schedulerName : DefaultScheduler
      , nodeName      : MustBeAbsent
      , uniqueNodeAffinity : FixedNodeUniqueEligibilityProjection
      , rollout       : Recreate
      }
  , slots           : NonEmptyMap PlannedExecutionSlotId MaterializedExecutionInstance
  , staticReservations : NonEmptyMap
      ExecutionUnitId (CompleteResourceReservation ExecutionUnitId)
  , namespaceQuota  : BootstrapRegistryExactPodQuotaProjection
  , fixedPlacement  : BootstrapRegistryFixedNodePlacementWitness
  , sourceEquality  : BootstrapRegistryExecutionSourceDomainWitness
  , preManagedDomain: DisjointFromManagedAdmissionDomainWitness
  , cutoverRequired : RequireBootstrapAddonSchedulerCutoverMembership
  }

ProvisionedBootstrapRegistry =
  { image           : ProvisionedImageArtifact
  , execution       : ProvisionedBootstrapRegistryExecution
  , storage         : ProvisionedRegistryStorageDemand
  , nodeImport      : ProvisionedNodeImageStorageDemand
  , objectSources   : NonEmptyMap
      K8sObjectIdentity (ProvisionedRenderSource K8sObjectIdentity)
  , objectDomain    : BootstrapRegistryObjectDomainWitness
  , fieldOwnership  : BootstrapRegistryFieldOwnershipWitness
  , laterHandoff    : BootstrapRegistryWholeDeploymentHandoffIdentityDigest
  , capacity        : BootstrapRegistryCompleteCapacityWitness
  }

ObservedBootstrapRegistryInventory =
  { topology          : TopologyFingerprint
  , allocatable       : ObservedCapacity
  , foreignCommitments: Map LiveCommitmentOwner LiveCommitment
  , foreignCommitmentKeys :
      ObservedLiveCommitmentMapKeyOwnerEqualityWitness
  , nodeRuntimeStorage: ObservedNodeRuntimeStorageInventory
  , registryResidents : Map OciObjectDigest ObservedRegistryStoredObject
  , apiObjects        : Map KubernetesObjectId ResourceVersion
  , hostAuthority     : SoleHostBootstrapMutationAuthorityWitness
  , schedulerNotRequiredYet : PreSchedulerBootstrapStageWitness
  , fingerprint       : InventoryFingerprint
  }

BootstrapRegistryTokenState = < Fresh | Consumed >
SingleUseBootstrapRegistryToken state =
  { sourceDigest : BootstrapRegistryWholeDeploymentHandoffIdentityDigest
  , inventory    : InventoryFingerprint
  , nonce        : ContentAddress
  , state        : state
  }

ValidatedBootstrapRegistryTarget =
  { provision       : ProvisionedBootstrapRegistry
  , observed        : ObservedBootstrapRegistryInventory
  , inventory       : InventoryFingerprint
  , resourceVersions: Map KubernetesObjectId ResourceVersion
  , runtimeStorage  : ProvisionedObservedNodeRuntimeStorageAccounting
  , sourceEquality  : BootstrapRegistrySnapshotEqualityWitness
  , singleUse       : SingleUseBootstrapRegistryToken Fresh
  }

SnapshotBoundNodeImageImportCapability =
  { image           : ProvisionedImageArtifact
  , targetNode      : NodeId
  , runtimeStorage  : ProvisionedObservedNodeRuntimeStorageAccounting
  , inventory       : InventoryFingerprint
  , allowedDigest   : OciObjectDigest
  , sourceEquality  :
      BootstrapImageDigestNodeRuntimeStorageSnapshotEqualityWitness
  }

BootstrapRegistryObjectInitializeCapability =
  { objects         : NonEmptyMap K8sObjectIdentity CanonicalProvisionedKubernetesFields
  , resourceVersions: Map KubernetesObjectId ResourceVersion
  , inventory       : InventoryFingerprint
  , fieldOwnership  : BootstrapRegistryFieldOwnershipWitness
  , sourceEquality  :
      BootstrapObjectDomainFieldVersionSnapshotEqualityWitness
  }

SoleHostBootstrapMutationCapability =
  { authority       : SoleHostBootstrapMutationAuthorityWitness
  , inventory       : InventoryFingerprint
  , allowedActions  :
      { importProvisionedImage              : Required
      , initializeBootstrapRegistryObjects  : Required
      }
  , sourceEquality  :
      SoleHostBootstrapAuthorityCompleteActionSetSnapshotEqualityWitness
  }

BootstrapRegistryAction =
  { target          : ValidatedBootstrapRegistryTarget
  , importImage     : SnapshotBoundNodeImageImportCapability
  , initializeObjects : BootstrapRegistryObjectInitializeCapability
  , authority       : SoleHostBootstrapMutationCapability
  , sourceDigest    : BootstrapRegistryWholeDeploymentHandoffIdentityDigest
  , noGenericServiceRenderBoundary : Required
  , sourceEquality  :
      BootstrapRegistryTargetCapabilityAuthoritySourceDigestEqualityWitness
  }

BootstrapRegistryImportAndObjectInitializationAttemptDomain =
  { imageDigest     : OciObjectDigest
  , objects         : NonEmptySet KubernetesObjectId
  , exactProjection :
      BootstrapActionImageAndObjectAttemptDomainEqualityWitness
  }

BootstrapRegistryTransportOutcome =
  < Acknowledged
  | RejectedBeforeEffect
  | TimeoutOrCancelled
  | LostOrAmbiguousResponse
  >

ObservedNodeImageImportResult =
  { imageDigest     : OciObjectDigest
  , node            : NodeId
  , runtimeStorage  : ProvisionedObservedNodeRuntimeStorageAccounting
  , importedObjects : NonEmptyMap OciObjectDigest ObservedRegistryStoredObject
  , fingerprint     : InventoryFingerprint
  , sourceEquality  :
      NodeImageImportDigestNodeRuntimeObjectSnapshotEqualityWitness
  }

FreshNodeImageAndApiObjectObservationRequirement receipt =
  { imageDigest     : OciObjectDigest
  , objects         : NonEmptySet KubernetesObjectId
  , afterAttempt    : receipt.attempt
  , attemptedDomain : receipt.attempted
  , required        : Required
  , sourceEquality  :
      BootstrapReobservationReceiptAttemptDomainEqualityWitness
  }

BootstrapRegistryConsumptionReceipt =
  { sourceDigest    : BootstrapRegistryWholeDeploymentHandoffIdentityDigest
  , inventory       : InventoryFingerprint
  , attempt         : ContentAddress
  , token           : SingleUseBootstrapRegistryToken Consumed
  , attempted       : BootstrapRegistryImportAndObjectInitializationAttemptDomain
  , transport       : BootstrapRegistryTransportOutcome
  , consumptionCas  : BootstrapRegistryFreshToConsumedCompareAndSwapWitness
  , sourceEquality  :
      BootstrapRegistryActionConsumedTokenAttemptIdDomainTransportEqualityWitness
  }

BootstrapRegistryEnactmentResult =
  < Applied :
      { receipt       : BootstrapRegistryConsumptionReceipt
      , importedImage : ObservedNodeImageImportResult
      , initializedObjects : Map KubernetesObjectId ResourceVersion
      , postInventory : ObservedBootstrapRegistryInventory
      , equality      :
          BootstrapRegistryReceiptImportObjectPostInventoryEqualityWitness
      }
  | OutcomeUnknown :
      { receipt       : BootstrapRegistryConsumptionReceipt
      , latestImage   : Optional ObservedNodeImageImportResult
      , latestObjects : Map KubernetesObjectId ResourceVersion
      , reobserve     : FreshNodeImageAndApiObjectObservationRequirement receipt
      , noReplay      : Required
      , equality      :
          BootstrapUnknownOutcomeReceiptLatestStateReobservationEqualityWitness
      }
  >

BootstrapRegistryLiveValidationError =
  < BootstrapRegistryObservedSnapshotMismatch
  | BootstrapRegistryImageImportCapacityUnavailable
  | BootstrapRegistryObjectInitializationConflict
  | BootstrapRegistrySoleHostAuthorityUnavailable
  >

BootstrapRegistryPreEnactmentError =
  < BootstrapRegistrySnapshotChanged
  | BootstrapRegistryTargetAlreadyConsumed
  | BootstrapRegistryCapabilityUnavailable
  | BootstrapRegistryConsumptionCasConflict
  >

provisionBootstrapRegistry
  :: Topology
  -> BootstrapRegistryDemand
  -> Either ProvisionError ProvisionedBootstrapRegistry

validateBootstrapRegistryTarget
  :: ObservedBootstrapRegistryInventory
  -> ProvisionedBootstrapRegistry
  -> Either BootstrapRegistryLiveValidationError BootstrapRegistryAction

enactBootstrapRegistry
  :: BootstrapRegistryAction
  -> Either BootstrapRegistryPreEnactmentError BootstrapRegistryEnactmentResult
-- Left is pre-CAS and proves zero effects. Once the token is consumed, every acknowledged or ambiguous
-- transport outcome returns a receipt; OutcomeUnknown exposes only re-observation, never the old action.

-- This explicit cycle-break exists before the scheduler image can be pulled. It provisions and initializes
-- only the registry/proxy objects through a typed action using the same private source serializer as Phase 20;
-- it does not expose per-service render/apply. A later whole-deployment ProvisionedSpec may adopt those exact
-- identities only after observing equal source/field digests and transfers ownership once.

RegistryBackendMigrationPolicy =
  { model           : RegistryBackendCopyModelVersion
  , workspaceVolume : VolumeId
  , copyConcurrency : PositiveNatural
  }

RegistryBackendMigrationIntent = -- dhall-typecheck/ClusterIR source
  { identity    : RegistryBackendMigrationId
  , source      : PriorProvisionRefSource -- must be the Registry arm
  , replacement : RegistryStorageIntent
  , policy      : RegistryBackendMigrationPolicy
  }

RegistryBackendMigrationDemand =
  { identity    : RegistryBackendMigrationId
  , source      : PriorRegistryProvisionRef
  , replacement : RegistryStorageDemand
  , policy      : RegistryBackendMigrationPolicy
  }

ProvisionedRegistryBackendMigration = -- private constructor
  { identity          : RegistryBackendMigrationId
  , source            : ProvisionedRegistryStorageDemand
  , replacement       : ProvisionedRegistryStorageDemand
  , objectCopyMap     : Map OciObjectDigest ObjectStoreObjectId
  , workspaceBytes    : Quantity Bytes
  , transferExecution : PodResourceEnvelope
  , perBackingPeak    : Map BackingId (Quantity Bytes)
  , witness           : RegistryBackendMigrationWitness
  }
```

## 14. Vault storage and audit

```text
VaultPersistedObjectDemand =
  { identity        : VaultObjectId
  , kind            : < Kv | TransitKey | Pki | Auth | Lease >
  , versions        : PositiveNatural
  , maxPayloadBytes : Quantity Bytes
  }

VaultAuditDemand =
  { maxBytesPerFile : Quantity Bytes
  , maxBackups      : Natural
  , retention       : FiniteDuration
  , backing         :
      < PodEphemeral : { volume : VolumeId }
      | Retained :
          { claim : StatefulSetClaimSlot
          , backing : BackingId
          , presentation : VolumePresentation
          }
      >
  }

VaultStorageDemand =
  { persisted       : NonEmpty VaultPersistedObjectDemand
  , maxActiveLeases : PositiveNatural
  , raftModel       : VaultRaftStorageModelVersion
  , raftVolumes     : NonEmpty
      { claim : StatefulSetClaimSlot
      , backing : BackingId
      , presentation : VolumePresentation
      }
  , audit           : VaultAuditDemand
  }

ProvisionedVaultStorageDemand = -- private constructor
  { raftVolumes : NonEmpty ProvisionedVolumeDemand
  , audit       :
      < PodEphemeral : { volume : VolumeId, peakBytes : Quantity Bytes }
      | Retained : ProvisionedVolumeDemand
      >
  , witness     : VaultStorageWitness
  }
```

## 15. Resource envelopes and reservation axes

```text
PodResourceEnvelope =
  { containers  : NonEmpty ContainerEnvelope
  , overhead    : Optional PodResourceVec
  , headroom    : Optional ComputeHeadroomDemand
  , podLocal    : PodLocalStorageDemand
  , runtimeMetadata : PodRuntimeMetadataSource
  , durable     : List DeclaredVolumeDemand
  , cache       : Optional InClusterCacheDemand
  , accelerator : PodAcceleratorDemand
  }

HostResourceVec =
  { cpu    : Quantity Cpu
  , memory : Quantity Bytes
  }

AppleSupervisorPolicy =
  { sampleInterval                 : FiniteDuration
  , maxConsecutiveOverLimitSamples : PositiveNatural
  , response                       : < Terminate >
  }

HostRuntimeEnforcement =
  < LinuxCgroupV2
  | WindowsJobObject
  | AppleSupervisor : AppleSupervisorPolicy
  >

HostResources =
  { reservation : HostResourceVec
  , ceiling     : HostResourceVec
  , headroom    : Optional HostComputeHeadroomDemand
  , enforcement : HostRuntimeEnforcement
  }

HostResourceEnvelope =
  { runtime      : HostResources
  , localStorage : List { backing : HostStorageBackingId, bytes : Quantity Bytes }
  , cache        : Optional HostCacheDemand
  , accelerator  : HostAcceleratorDemand
  }

ResourceEnvelope =
  < Pod : PodResourceEnvelope | HostWorker : HostResourceEnvelope >

PodComputeReservationAxes =
  { cpuRequest        : Quantity Cpu
  , cpuPad            : Residual Cpu
  , cpuLimitDebit     : Quantity Cpu
  , memoryRequest     : Quantity Bytes
  , memoryPad         : Residual Bytes
  , memoryLimitDebit  : Quantity Bytes
  , logicalEphemeralRequest    : Quantity Bytes
  , logicalEphemeralPad        : Residual Bytes
  , logicalEphemeralLimitDebit : Quantity Bytes
  , renderedRequestLimitEquality : PodRenderedRequestLimitEqualityWitness
  }
-- The pad axes are the declared compute headroom, carried beside the request they
-- extend rather than folded into it, so the required and reserved components stay
-- separable on the ledger: the debit is request + pad, the release returns both, and
-- a row cannot silently reclassify slack as requirement. A pod with no declared
-- headroom carries Zero on all three and the ledger is arithmetically unchanged.

PodSlotReservationAxes =
  { podSlots : Natural
  , cniSlots : Map CniDriverId Natural
  , csiAttachments : Map (CsiDriverId, VolumeIdentity) CsiAttachmentReservation
  , csiCounts       : Map CsiDriverId Natural
  , csiIdentityCountEquality : CsiAttachmentIdentityCountWitness
  }

PodComputeReservationPartitionAxes =
  { cpuRequest                : Residual Cpu
  , cpuPad                    : Residual Cpu
  , cpuLimitDebit             : Residual Cpu
  , memoryRequest             : Residual Bytes
  , memoryPad                 : Residual Bytes
  , memoryLimitDebit          : Residual Bytes
  , logicalEphemeralRequest   : Residual Bytes
  , logicalEphemeralPad       : Residual Bytes
  , logicalEphemeralLimitDebit: Residual Bytes
  }
-- Release/retention partitions every axis the reservation debited, pad included. A
-- partition that returns the request but not its pad leaks headroom permanently, so
-- the pad axes are not optional here: reserved, released, and retained each carry all
-- nine scalars and their partition is exact.

CsiAttachmentReservation =
  { target         : ProvisionedNodeTarget
  , driver         : CsiDriverId
  , volume         : VolumeIdentity
  , slots          : ExactlyOne
  , sourceEquality :
      CsiAttachmentTargetDriverUniqueVolumeOneSlotEqualityWitness
  }

PodSlotReservationPartitionAxes =
  { podSlots      : Natural
  , cniSlots      : Map CniDriverId Natural
  , csiAttachments: Map (CsiDriverId, VolumeIdentity) CsiAttachmentReservation
  , csiCounts     : Map CsiDriverId Natural
  , equality      : CsiAttachmentIdentityCountWitness
  }

PodScopedPhysicalComponentKind =
  < KubeletRuntimeMetadata
  | CriRuntimeMetadata
  | WritableSnapshot
  | ContainerLog
  | PodLocalVolume
  | InClusterCache
  >

PodScopedPhysicalComponent owner =
  { identity : (owner, PodScopedPhysicalComponentKind, LocalComponentId)
  , backing  : ProvisionedRuntimeOrStorageBackingRef
  , bytes    : Quantity Bytes
  , model    : PhysicalStorageModelFingerprint
  , source   : PodPhysicalComponentSourceWitness
  }

ProvisionedNodeTarget =
  < Fixed   : NodeId
  | Elastic :
      { instance  : ProviderInstanceId
      , classSlot : ProviderNodeClassSlotId
      }
  >

RuntimeOrStorageBackingId =
  < NodeFilesystem :
      { node  : NodeId
      , carve : DiskCarveId
      }
  | RetainedStorage : BackingId
  | ProviderVolume  : ProviderVolumeId
  | HostCache       : HostCacheOwner
  | HostStorage     : HostStorageBackingId
  >
-- The closed arm is part of identity. A node filesystem, retained backing, provider volume, cache, and
-- purpose-tagged host extent cannot alias merely because their textual ids or byte counts match.

ProvisionedRuntimeOrStorageBackingRef =
  < Materialized : RuntimeOrStorageBackingId
  | Elastic :
      { instance : ProviderInstanceId
      , disk     : DiskTemplateId
      , carve    : DiskCarveTemplateId
      }
  >

ProvisionedAcceleratorDeviceRef =
  < Materialized : AcceleratorDeviceId
  | Elastic :
      { instance : ProviderInstanceId
      , slot     : AcceleratorSlotTemplateId
      }
  >

ObservedNodeTargetBinding =
  { target       : ProvisionedNodeTarget
  , node         : NodeId
  , provider     : Optional ProviderInstanceAttestation
  , ready        : NodeReadyWitness
  , capacity     : ObservedCapacityEqualityWitness
  , backings     : Map ProvisionedRuntimeOrStorageBackingRef RuntimeOrStorageBackingId
  , devices      : Map ProvisionedAcceleratorDeviceRef AcceleratorDeviceId
  , materializationEquality : NodeBackingDeviceMaterializationWitness
  , fingerprint  : NodeTargetBindingFingerprint
  }

PhysicalAllocationDomain =
  < Node          : ProvisionedNodeTarget
  | GlobalBacking : BackingId
  >

SharedExtentIdentity =
  < OciContent :
      { scope  : ProvisionedNodeTarget
      , digest : OciObjectDigest
      }
  | SnapshotChain :
      { scope    : ProvisionedNodeTarget
      , identity : SnapshotChainId
      }
  | DurableVolume : VolumeIdentity
  >

SharedIdentityExtent =
  < OciContent :
      { scope    : ProvisionedNodeTarget
      , digest   : OciObjectDigest
      , bytes    : Quantity Bytes
      , backing  : ProvisionedRuntimeOrStorageBackingRef
      , model    : OciContentStorageModelFingerprint
      }
  | SnapshotChain :
      { scope    : ProvisionedNodeTarget
      , identity : SnapshotChainId
      , bytes    : Quantity Bytes
      , backing  : ProvisionedRuntimeOrStorageBackingRef
      , model    : SnapshotStorageModelFingerprint
      }
  | DurableVolume :
      { identity : VolumeIdentity
      , backing  : BackingId
      , physical : Quantity Bytes
      , model    : ProvisionedVolumeModelFingerprint
      }
  >

HostCacheAllocationDomain = HostCacheOwner
HostCacheExtentKey = (HostCacheAllocationDomain, CacheExtentId)

HostCacheExtent =
  { identity : CacheExtentId
  , backing  : HostCacheOwner
  , physical : Quantity Bytes
  , model    : CacheStorageModelFingerprint
  , source   : HostCacheDemandProjectionWitness
  }

SharedExtentKey = (PhysicalAllocationDomain, SharedExtentIdentity)

SharedExtentSet =
  { extents     : Map SharedExtentKey SharedIdentityExtent
  , keyEquality :
      SharedExtentKeyDomainAndArmSpecificValueIdentityEqualityWitness
  }

NonEmptySharedExtentSet =
  { extents     : NonEmptyMap SharedExtentKey SharedIdentityExtent
  , keyEquality :
      SharedExtentKeyDomainAndArmSpecificValueIdentityEqualityWitness
  }
-- sharedExtentIdentity is a total arm-specific projection. Key equality also proves the key's physical
-- allocation domain equals the value's scope/backing domain, so two families cannot deduplicate by a
-- coincidentally equal digest/id.

ImagePullReservationIntent =
  { scope           : ProvisionedNodeTarget
  , workItem        : ImagePullWorkItemId
  , digest          : OciManifestDigest
  , content         : NonEmptySharedExtentSet
  , workspaceBacking: ProvisionedRuntimeOrStorageBackingRef
  , maxWorkspace    : Quantity Bytes
  , policy          :
      { concurrency : < Serial | BoundedParallel : PositiveNatural >
      , sameDigest  : CoalesceOnePullPerNode
      , failedPartialRetention : FiniteDuration
      }
  , model           : ImagePullWorkspaceModelFingerprint
  }

CudaDeviceReservation owner =
  { owner           : owner
  , device          : ProvisionedAcceleratorDeviceRef
  , family          : CudaAcceleratorFamily
  , profile         : AcceleratorProfile
  , vramBytes       : Quantity Bytes
  , wholeDevice     : ExclusiveGenericNvidiaGpuAllocation
  , source          : AcceleratorAllocationSourceWitness
  }

RuntimeStorageModelKey =
  < KubeletRuntimeMetadata
  | KubeletFilesystemLayout
  | OciContent
  | SnapshotChain
  | ImagePullWorkspace
  | VolumePresentation
  | CachePopulation
  | ContainerLogs
  | MappedFiles
  >

RuntimeStorageModelFingerprintSet =
  { models      : NonEmptyMap RuntimeStorageModelKey ContentAddress
  , exactDomain : RuntimeStorageModelClosedDomainEqualityWitness
  }

ReservationModelKey =
  < RuntimeStorage
  | Placement
  | PodCniCsiSlots
  | AcceleratorAllocation
  | ApiEtcd
  | ControllerTransition
  >

ReservationModelFingerprintSet =
  { models         : NonEmptyMap ReservationModelKey ContentAddress
  , runtimeStorage : RuntimeStorageModelFingerprintSet
  , exactDomain    : ReservationModelClosedDomainEqualityWitness
  , sourceEquality : ReservationAndRuntimeStorageModelEqualityWitness
  }

-- The reservation-projection witnesses. Each fixes which envelope-derived quantities a
-- ledger row may carry, so no row can be minted from independently authored numbers.
-- Declared compute headroom is the one term that is authored rather than derived, so
-- each witness names it separately and keeps the required component recoverable from
-- the reserved total: the reservation is the projection of the envelope's required
-- demand composed with its declared pad, not the projection alone.

PodRenderedRequestLimitEqualityWitness envelope axes rendered =
  { effectiveRequired             : PodResourceVec
  , declaredPad                   : Residualized PodResourceVec
  , effectiveReserved             : PodResourceVec
  , effectiveLimits               : PodResourceVec
  , requiredFromEnvelope          : Required
  , padFromEnvelopeHeadroom       : Required
  , reservedIsRequiredPlusPad     : Required
  , reservedWithinLimits          : Required
  , axesRequestEqualsRequired     : axes.cpuRequest == effectiveRequired.cpu
  , axesPadEqualsDeclaredPad      : Required
  , axesLimitDebitEqualsLimits    : Required
  , renderedRequestsEqualReserved : Required
  , renderedLimitsEqualLimits     : Required
  }
-- Required and pad are both retained, so "how much of this reservation is slack, and
-- why" is answerable from the row rather than lost in a sum. Kubernetes has one
-- requests field, so the manifest necessarily carries the padded total and the split
-- survives only here; renderedRequestsEqualReserved is that tie, and it is why the
-- renderer projects a pre-summed number instead of adding the pad itself.

ResourceEnvelopeReservationProjectionWitness envelope reservation =
  { envelopeSource            : ResourceEnvelope
  , podArm                    : Required
  , compute                   : PodRenderedRequestLimitEqualityWitness
  , slotsFromLiveEpochs       : Required
  , componentsFromEnvelope    : Required
  , devicesFromWholesaleOwner : Required
  , noIndependentAxis         : Required
  , headroomAbsentImpliesZeroPad : Required
  }
-- noIndependentAxis is the load-bearing clause: every scalar, slot, component, and
-- device hold on the row is a projection of this envelope, and the only authored
-- addend is the envelope's own declared headroom. A pod whose envelope declares no
-- headroom projects Zero pad on all three axes, which is the pre-headroom behaviour.

HostResourceEnvelopeReservationProjectionWitness envelope reservation =
  { envelopeSource         : ResourceEnvelope
  , hostWorkerArm          : Required
  , effectiveReservation   : HostResourceVec
  , declaredPad            : Residualized HostResourceVec
  , effectiveReserved      : HostResourceVec
  , reservedIsReservationPlusPad : Required
  , reservedWithinCeiling  : Required
  , localComponentsFromEnvelope  : Required
  , acceleratorFromHostOwner     : Required
  , noIndependentAxis      : Required
  , headroomAbsentImpliesZeroPad : Required
  }

CompleteResourceReservation owner = -- private, canonical scheduler-ledger value
  { owner                 : owner
  , target                : ProvisionedNodeTarget
  , node                  : NodeId
  , targetBinding         : NodeTargetBindingEqualityWitness
  , compute               : PodComputeReservationAxes
  , slots                 : PodSlotReservationAxes
  , podScopedPhysical     : Map
      (owner, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent owner)
  , sharedIdentityExtents : SharedExtentSet
  , imagePullIntents      : Map ImagePullWorkItemId ImagePullReservationIntent
  , devices               : Map ProvisionedAcceleratorDeviceRef (CudaDeviceReservation owner)
  , podScopedBackingDebits: Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , activePodSlotPositive : PositivePodSlotWitness
  , materializedTargets   : ReservationTargetMaterializationWitness
  , topologyFingerprint   : TopologyFingerprint
  , modelFingerprints     : ReservationModelFingerprintSet
  , backingEquality       : ReservationComponentBackingGroupingWitness
  , sourceEquality        : ResourceEnvelopeReservationProjectionWitness
  }

CompleteResourceReservationTemplate =
  { source                : SchedulerReservationTemplateKey
  , target                : ProvisionedNodeTarget
  , compute               : PodComputeReservationAxes
  , slots                 : PodSlotReservationAxes
  , podScopedComponents   : Map
      (PodScopedPhysicalComponentKind, LocalComponentId)
      UnqualifiedPodScopedPhysicalComponent
  , sharedIdentityExtents : SharedExtentSet
  , imagePullIntents      : Map ImagePullWorkItemId ImagePullReservationIntent
  , devices               : Map ProvisionedAcceleratorDeviceRef (CudaDeviceReservation SchedulerReservationTemplateKey)
  , podScopedBackingDebits: Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , topologyFingerprint   : TopologyFingerprint
  , modelFingerprints     : ReservationModelFingerprintSet
  , backingEquality       : ReservationTemplateBackingGroupingWitness
  , sourceEquality        : ProvisionedPodReservationTemplateWitness
  }

instantiateReservation
  :: ObservedNodeTargetBinding
  -> PodUid
  -> CompleteResourceReservationTemplate
  -> CompleteResourceReservation PodUid
-- replaces the provisioned node target with its attested live NodeId, qualifies every additive component
-- and CUDA device hold with PodUid, and leaves allocation-domain-scoped shared identities stable

ResourceReservationPartition owner =
  { owner                 : owner
  , target                : ProvisionedNodeTarget
  , node                  : NodeId
  , compute               : PodComputeReservationPartitionAxes
  , slots                 : PodSlotReservationPartitionAxes
  , podScopedPhysical     : Map
      (owner, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent owner)
  , sharedIdentityExtents : SharedExtentSet
  , imagePullIntents      : Map ImagePullWorkItemId ImagePullReservationIntent
  , devices               : Map ProvisionedAcceleratorDeviceRef (CudaDeviceReservation owner)
  , podScopedBackingDebits: Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , sourcePartition       : ReservationPartitionSourceWitness
  }

RetainedResourceReservation owner = -- private refinement
  { base             : ResourceReservationPartition owner
  , zeroCompute      : ZeroComputeReservationWitness
  -- zeroCompute covers all nine compute scalars, pad axes included. A terminal-retained
  -- row that zeroes its requests but keeps its pad would hold headroom forever against
  -- a workload that no longer exists. Until release evidence and the whole-root CAS
  -- succeed the row retains the exact full padded debit; at retention it releases all
  -- nine or none.
  , zeroDevices      : EmptyCudaDeviceReservationWitness
  , slotRetention    : PodSlotReleaseAndRetentionEqualityWitness
  , observedResident : ObservedResidentResourceEqualityWitness
  }

PodSlotReleaseEvidence =
  { podUid            : PodUid
  , reserved          : PodSlotReservationAxes
  , released          : PodSlotReservationPartitionAxes
  , retained          : PodSlotReservationPartitionAxes
  , podSlotObservation: ObservedNodePodSlotReleaseOrRetentionWitness
  , cni               : Map CniDriverId ObservedCniAllocationReleaseOrRetentionWitness
  , csi               : Map (CsiDriverId, VolumeIdentity)
      ObservedCsiAttachmentReleaseOrRetentionWitness
  , partitionExact    : PodSlotPartitionExactWitness
  , identityEquality  : PodSlotAttachmentIdentityEqualityWitness
  }

SchedulerReservationAxes state =
  < Active :
      { state : < Reserved | BindingInFlight | Bound | Terminating >
      , axes  : CompleteResourceReservation PodUid
      }
  | TerminalRetained :
      { state : TerminalRetained
      , axes  : RetainedResourceReservation PodUid
      }
  > -- the private constructor requires the embedded state to equal the type index

ObservedImagePullState =
  < Missing
  | Pulling :
      { workItem : ImagePullWorkItemId, partialBytes : Residual Bytes
      , startedAt : ObservationTimestamp }
  | Resident :
      { digest : OciManifestDigest, content : NonEmptySharedExtentSet }
  | FailedPartial :
      { workItem : ImagePullWorkItemId, partialBytes : Residual Bytes
      , retainUntil : FiniteDeadline }
  >

ObservedResidentResourceBaseline =
  { nodeBindings       : NonEmptyMap ProvisionedNodeTarget ObservedNodeTargetBinding
  , imagePullState     : Map (ProvisionedNodeTarget, ImagePullWorkItemId) ObservedImagePullState
  , sharedExtents      : SharedExtentSet
  , activePodArtifacts : Map
      (PodUid, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent PodUid)
  , retainedPodArtifacts : Map
      (PodUid, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent PodUid)
  , activeLedgerJoin   : ActivePodArtifactLedgerEqualityWitness
  , artifactPartition  : ActiveAndRetainedPodArtifactPartitionWitness
  , backingAllocations : Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , modelFingerprints  : ReservationModelFingerprintSet
  , inventoryFingerprint : InventoryFingerprint
  , sourceEquality     : ObservedResidentResourceSourceEqualityWitness
  }

ResidentResourceDebitSet =
  { sharedExtents      : SharedExtentSet
  , retainedPodArtifacts : Map
      (PodUid, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent PodUid)
  , failedPullPartials : Map (ProvisionedNodeTarget, ImagePullWorkItemId)
      { bytes : Residual Bytes, retainUntil : FiniteDeadline }
  , backingTotals      : Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , observation        : InventoryFingerprint
  , equality           : ObservedResidentDebitProjectionWitness
  } -- copied into the control-plane daemon ledger root; removal requires fresh observed-absence/GC evidence and CAS

ValidatedSchedulerLedgerRoot =
  { identity       : SchedulerLedgerRootId
  , entries        : Map PodUid SomeSchedulerReservationRecord
  , retainedDebits : ResidentResourceDebitSet
  , keyOwnerEquality : SchedulerLedgerKeyPodUidAxesOwnerEqualityWitness
  , recordAxesEquality : SchedulerRecordSourceChildTargetAxesEqualityWitness
  , residentFingerprint : InventoryFingerprint
  , foldDigest     : ReservationSetFoldDigest
  , rootResourceVersion : ResourceVersion
  , rootCasVersion   : SchedulerLedgerCasVersion
  , control-plane daemon      : SchedulerLedgerControlPlaneDaemonAuthorityWitness
  }

ReservationFoldInput =
  { staticBaseline    : Map ExecutionUnitId (CompleteResourceReservation ExecutionUnitId)
  , staticKeyEquality : StaticReservationKeyOwnerEqualityWitness
  , staticLedgerDisjoint : StaticAndLiveReservationOwnerDisjointnessWitness
  , liveCommitments   : Map LiveCommitmentOwner LiveCommitment
  , liveKeyEquality   :
      LiveCommitmentMapKeyOwnerDebitEqualityWitness
  , residentBaseline  : ObservedResidentResourceBaseline
  , residentRootEquality : SchedulerRootResidentDebitEqualityWitness
  , activeResidentJoin   : ActivePodArtifactLedgerEqualityWitness
  , podScopedDisjointness: LedgerAndRetainedPodArtifactDisjointnessWitness
  , ledger            : ValidatedSchedulerLedgerRoot
  , candidate         : Optional (CompleteResourceReservation PodUid)
  , candidateLedgerIdempotency : CandidateLedgerPodUidIdempotencyWitness
  , capacityFingerprint : ObservedCapacityFingerprint
  , sourceFingerprint : InventoryFingerprint
  , sourceEquality    : SchedulerFoldInputSourceEqualityWitness
  }

ReservationSetFold =
  { additiveCompute      : Map NodeId PodComputeReservationAxes
  , additiveSlots        : Map NodeId PodSlotReservationAxes
  , podScopedComponents  : Map
      (PodUid, PodScopedPhysicalComponentKind, LocalComponentId)
      (PodScopedPhysicalComponent PodUid)
  , sharedIdentityExtents: SharedExtentSet
  , imagePullWorkspacePeak : Map ProvisionedRuntimeOrStorageBackingRef (Residual Bytes)
  , devices              : Map ProvisionedAcceleratorDeviceRef (CudaDeviceReservation PodUid)
  , backingTotals        : Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , fit                  : CompleteCapacityFitWitness
  , identityUnion        : SharedExtentIdentityDedupWitness
  , modelEquality        : ReservationModelEqualityWitness
  , backingEquality      : ReservationSetBackingGroupingWitness
  }

foldReservationSet
  :: Topology
  -> ReservationFoldInput
  -> Either ProvisionError ReservationSetFold
-- additive rows have disjoint owner-qualified keys. Equal shared identities union once only inside the same
-- physical allocation domain and only when bytes/backing/model agree. Image workspace is the policy-bounded
-- top-n of observed missing/pulling work items after same-node/digest coalescing; Resident contributes zero
-- workspace and FailedPartial remains until its observed deadline. A CUDA device may occur for one PodUid
-- owner only (same-UID retries are idempotent). Every CAS re-folds the control-plane daemon root plus static, foreign,
-- resident, and candidate state under the same capacity/inventory fingerprint.

CompleteResourceReservationSchema owner =
  { owner              : owner
  , computeAxes        : ExactCanonicalFields
  , slotAxes           : ExactCanonicalFields
  , podScopedComponents: CanonicalIdentityMap
  , sharedExtents      : CanonicalIdentityMap
  , imagePullIntents   : CanonicalIdentityMap
  , devices            : CanonicalDeviceMap
  , backingTotals      : DerivedCanonicalMap
  , modelFingerprints  : Required
  , serializer         : CanonicalSchedulerReservationSerializerModel
  , foldRule           : RecomputeWholeLedgerSetBeforeCas
  }
-- computeAxes is canonically pinned, so the three pad scalars are part of the frozen
-- field set: they change the serialized entry size and therefore the ledger's derived
-- maxEntries and etcd churn budget. They are not an optional tail a reader may skip.
```

## 16. Execution units, controllers, and rollout policy

```text
LivePodResourceReservationSchema = CompleteResourceReservationSchema PodUid
StaticResourceReservationSchema = CompleteResourceReservationSchema ExecutionUnitId

CompleteHostResourceReservation owner =
  { owner            : owner
  , host             : HostId
  , runtime          : HostResources
  , localComponents  : Map HostStorageExtentId
      { backing : HostStorageBackingId, bytes : Quantity Bytes }
  , cacheExtents     : Map CacheExtentId HostCacheExtent
  , accelerator     :
      < None
      | Cuda  : Map ProvisionedAcceleratorDeviceRef (CudaDeviceReservation owner)
      | Metal :
          { profile : MetalProfile
          , unifiedMemoryDebit : Quantity Bytes
          , epoch : MetalAllocationEpoch
          }
      >
  , localBackingTotals : Map HostStorageBackingId (Quantity Bytes)
  , cacheBackingTotals : Map CacheBackingId (Quantity Bytes)
  , sourceEquality  : HostResourceEnvelopeReservationProjectionWitness
  , backingEquality : HostReservationBackingGroupingWitness
  }
-- runtime : HostResources carries reservation, ceiling, and the optional declared
-- headroom together, so the host arm needs no separate pad field: its debit is
-- reservation + pad, bounded by ceiling, exactly mirroring the pod arm's
-- requests + pad bounded by limits. The two arms of the closed ResourceEnvelope union
-- stay symmetric on this axis.

CompleteHostResourceReservationSchema owner =
  { identity    : owner
  , axes        : ClosedHostReservationFields
  , serializer  : CanonicalHostReservationSerializerModel
  , foldRule    : RecomputeWholeHostLedgerSetBeforeCas
  }

OrdinaryPodResourceEnvelope = -- opaque gadt-decode refinement
  { base : PodResourceEnvelope, acceleratorIsNone : EqualityWitness }

CudaPodResourceEnvelope = -- opaque gadt-decode refinement
  { base : PodResourceEnvelope
  , demand : CudaOwnerDemand
  , acceleratorEqualsCudaDemand : EqualityWitness
  }

OrdinaryHostResourceEnvelope = -- opaque gadt-decode refinement
  { base : HostResourceEnvelope, acceleratorIsNone : EqualityWitness }

CudaHostResourceEnvelope = -- opaque gadt-decode refinement
  { base : HostResourceEnvelope
  , demand : CudaOwnerDemand
  , acceleratorEqualsCudaDemand : EqualityWitness
  }

MetalHostResourceEnvelope = -- opaque gadt-decode refinement
  { base : HostResourceEnvelope
  , demand : MetalOwnerDemand
  , acceleratorEqualsMetalDemand : EqualityWitness
  }

NodeEligibilityConstraint =
  < EngineRole         : EngineNodeRole
  | ProviderClass      : ProviderNodeClassId
  | Site               : Site
  | AcceleratorProfile : AcceleratorProfile
  | CarriesTaint       : NodeTaintKind
  >

NodeEligibilitySelector =
  { allOf : Set NodeEligibilityConstraint }

ReplicaCardinality =
  < Once
  | Replicated : { desiredReplicas : PositiveNatural }
  >

RawDeploymentRolloutPolicy = -- dhall-typecheck/Dhall input; refined at gadt-decode
  < Recreate
  | RollingUpdate :
      { maxSurge               : Natural
      , maxUnavailable         : Natural
      }
  >

DeploymentRolloutPolicy = -- opaque gadt-decode value; constructors are not exported
  < Recreate
  | RollingUpdate :
      { maxSurge               : Natural
      , maxUnavailable         : Natural
      } -- invariant: maxSurge + maxUnavailable > 0
  >

mkDeploymentRollingUpdate
  :: Natural
  -> Natural
  -> Either DecodeError DeploymentRolloutPolicy
-- succeeds iff maxSurge + maxUnavailable > 0

StatefulSetRolloutPolicy =
  < OnDelete : AmoebiusSerialOnDelete
  | RollingUpdate : NativeSerialPartitionZero
  >

DaemonSetRolloutPolicy =
  < OnDelete : AmoebiusSerialOnDelete
  | RollingUpdate :
      < Surge       : PositiveNatural
      | Unavailable : PositiveNatural
      > -- Kubernetes DaemonSet validation forbids both zero and both positive
  >

JobExecutionPolicy =
  { completions          : PositiveNatural
  , parallelism          : PositiveNatural
  , backoffLimit         : Natural
  , podRestartPolicy     : Never
  , podReplacementPolicy : Failed -- no replacement while predecessor merely Terminating
  , terminalRetention    :
      { cleanupAfter : FiniteDuration -- amoebius cleanup; not ttlSecondsAfterFinished
      , model : JobTerminalRetentionModelVersion
      }
  }

HostProcessReplacementPolicy =
  < RecreateAfterObservedExit
  | CudaRecreateAfterDeviceRelease
  | MetalDrainThenReplaceAfterObservedExit
  >

AmoebiusSerialOnDelete = closed source marker; no parallel/native-automatic arm

PodReleasePolicy =
  < Ordinary :
      { schedulerPartition : RequireObservedPodAbsenceAndResidentResourcePartition
      , slotPartition      : RequireCniCsiReleaseOrTerminalRetainedLedgerDebit
      }
  | Cuda :
      { deviceRelease      : ProvisionedCudaReleasePolicy
      , schedulerPartition : RequireObservedResidentResourcePartition
      , slotPartition      : RequireCniCsiReleaseOrTerminalRetainedLedgerDebit
      }
  >

ProvisionedSerialOnDeletePolicy =
  { priorSlots    : Map PlannedExecutionSlotId PodReleasePolicy
  , order         : ExactOrdinalOrNodeOrderWitness
  , sourceEquality: PriorPodSlotEqualityWitness
  }

ValidatedSerialOnDeletePlan = -- constructed only after live observation/token validation
  { desiredController : ProvisionedPodController
  , desiredTemplateLive : ObservedDesiredControllerTemplateWitness
  , next :
      { priorPod      : PodUid
      , controller    : KubernetesControllerUid
      , ordinalOrNode : < Ordinal : Natural | Node : NodeId >
      , present       : ObservedPodUidPresentWitness
      , delete        : PriorAuthenticatedPodDeleteCapability
      }
  , remaining          : List PlannedExecutionSlotId
  , order              : ExactOrdinalOrNodeOrderWitness
  , preDeleteFingerprint: ExecutionTransitionFingerprint
  }

ValidatedSerialOnDeleteContinuation = -- minted only by a fresh post-delete observation
  { deletedPod          : PodUid
  , absenceAndRelease   : ValidatedPodReleaseEvidence
  , expectedReplacement : PlannedExecutionSlotId
  , resumeController    : ControllerResumeCapability
  , postDeleteFingerprint : ExecutionTransitionFingerprint
  }

ValidatedSerialOnDeleteAdvance = -- minted only after another fresh observation
  { replacementPod   : PodUid
  , expectedSlot     : PlannedExecutionSlotId
  , sourceEquality   : ReplacementPodSourceEqualityWitness
  , boundAndReady    : ReplacementPodBoundReadyWitness
  , next             : Optional ValidatedSerialOnDeletePlan
  , fingerprint      : ExecutionTransitionFingerprint
  }

PodExecutionController =
  < Deployment :
      { cardinality : ReplicaCardinality
      , rollout     : DeploymentRolloutPolicy
      }
  | StatefulSet :
      { cardinality : ReplicaCardinality
      , rollout     : StatefulSetRolloutPolicy
      }
  | DaemonSet :
      { selector : NodeEligibilitySelector
      , rollout  : DaemonSetRolloutPolicy
      }
  | Job : JobExecutionPolicy
  >

HostProcessCardinality =
  < Once
  | PerNode : NodeEligibilitySelector
  >

BoundExecutionBody =
  < Pod :
      < Ordinary :
          { controller : PodExecutionController
          , resource   : OrdinaryPodResourceEnvelope -- accelerator=None
          }
      | CudaOwner :
          { controller :
              { selector : NodeEligibilitySelector
              , rollout  : AmoebiusSerialOnDelete -- DaemonSet replacement is amoebius-gated
              }
          , resource : CudaPodResourceEnvelope
          }
      >
  | HostProcess :
      < Ordinary :
          { cardinality : HostProcessCardinality
          , replacement : RecreateAfterObservedExit
          , resource    : OrdinaryHostResourceEnvelope
          }
      | CudaOwner :
          { cardinality : HostProcessCardinality
          , replacement : CudaRecreateAfterDeviceRelease
          , resource    : CudaHostResourceEnvelope
          }
      | MetalOwner :
          { cardinality : HostProcessCardinality
          , replacement : MetalDrainThenReplaceAfterObservedExit
          , resource    : MetalHostResourceEnvelope
          }
      >
  >

ExecutionUnitScope =
  < Kubernetes : NamespaceId
  | Host       : HostExecutionScopeId
  >

BoundExecutionUnit = -- private gadt-decode constructor; body arms enforce controller/resource/scope compatibility
  { id              : ExecutionUnitId
  , owner           : ResourceOwnerId
  , scope           : ExecutionUnitScope
  , revision        : ExecutionRevisionId
  , body            : BoundExecutionBody
  }

BoundExecutionSet = NonEmptyMap ExecutionUnitId BoundExecutionUnit

ExecutionTransitionSource =
  < FirstDeployment
  | UpdateFrom : PriorExecutionProvisionRef
  >

BoundExecutionInventory = -- required whole-deployment member
  { transition : ExecutionTransitionSource
  , desired    : BoundExecutionSet
  }

ExecutionControllerKind = < Deployment | StatefulSet | DaemonSet | Job | HostProcess >

MaterializedExecutionInstance = -- unprovisioned identity expansion
  { id         : PlannedExecutionSlotId -- capacity slot, not a future Kubernetes Pod UID
  , sourceUnit : ExecutionUnitId
  , revision   : ExecutionRevisionId
  , ordinal    : Natural
  , kind       : ExecutionControllerKind
  , nodeTarget : Optional ProvisionedNodeTarget
  , resource   : ResourceEnvelope
  }

ExecutionEpoch = Map PlannedExecutionSlotId MaterializedExecutionInstance -- transition steps may be empty
```

## 17. Scheduler and host reservation states

```text
SchedulerReservationState =
  < Reserved | BindingInFlight | Bound | Terminating | TerminalRetained >

SchedulerReservationRef state =
  { key             : (DeploymentId, ProvisionGenerationDigest, PodUid)
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , templateSet     : SchedulerTemplateSetDigest
  , child           : SchedulerControllerChildDiscriminator
  , childTemplate   : SchedulerReservationTemplateDigest
  , axes            : SchedulerReservationAxes state
  , state           : state
  , rootResourceVersion : ResourceVersion
  , rootCasVersion   : SchedulerLedgerCasVersion
  , ledgerEquality  : SchedulerLedgerStateEqualityWitness state
  }

ReservedSchedulerReservationRef = SchedulerReservationRef Reserved
BindingInFlightSchedulerReservationRef = SchedulerReservationRef BindingInFlight
BoundSchedulerReservationRef = SchedulerReservationRef Bound
TerminatingSchedulerReservationRef = SchedulerReservationRef Terminating
TerminalRetainedSchedulerReservationRef = SchedulerReservationRef TerminalRetained

PendingPodApiCommitment =
  { podUid          : PodUid
  , deployment      : DeploymentId
  , generation      : ProvisionGenerationDigest
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , templateSet     : SchedulerTemplateSetDigest
  , child           : SchedulerControllerChildDiscriminator
  , childTemplate   : SchedulerReservationTemplateDigest
  , namespace       : NamespaceId
  , podObject       : KubernetesApiObjectSource
  , etcdObject      : EtcdLogicalObjectSource
  , serializerModel : CanonicalKubernetesApiSerializerModel
  , reservation     : SchedulerReservationAbsentWitness
  , nodeRuntimeDebit: EmptyResourceReservationWitness
  , sourceEquality  : PendingPodSourceEqualityWitness
  }

ObservedKubernetesPodCommon =
  { podUid          : PodUid
  , deployment      : DeploymentId
  , generation      : ProvisionGenerationDigest
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , templateSet     : SchedulerTemplateSetDigest
  , child           : SchedulerControllerChildDiscriminator
  , childTemplate   : SchedulerReservationTemplateDigest
  , namespace       : NamespaceId
  , podObject       : KubernetesApiObjectSource
  , etcdObject      : EtcdLogicalObjectSource
  , controller      : KubernetesPodControllerChain
  , resource        : PodResourceEnvelope
  , sourceEquality  : ObservedPodIdentityAndTemplateEqualityWitness
  }

ObservedPodScheduling state =
  < PendingUnscheduled :
      { state : PendingUnscheduled, reservation : SchedulerReservationAbsentWitness }
  | Reserved :
      { state : Reserved, reservation : ReservedSchedulerReservationRef }
  | BindingRecovery :
      { state       : BindingRecovery
      , reservation : BindingInFlightSchedulerReservationRef
      , outcome     :
          < Unknown : KeepReservedAndReobserve
          | ConfirmedBound :
              { node : NodeId, binding : KubernetesBindingObservationWitness
              , repair : BindingInFlightToBoundCasCapability }
          | ConfirmedUnbound :
              { sameUidAndResourceVersion : Required
              , release : BindingInFlightReleaseCapability }
          >
      }
  | Bound :
      { state : Bound, reservation : BoundSchedulerReservationRef }
  | Terminating :
      { state : Terminating, reservation : TerminatingSchedulerReservationRef }
  | Terminal :
      { state            : Terminal
      , outcome          : < Succeeded | Failed >
      , lastNode         : NodeId
      , schedulerReleased: SchedulerResourceReleaseWitness
      , retained         : TerminalPodRetentionDemand
      }
  > -- private constructor requires the selected arm's state to equal the type index

ObservedKubernetesPodExecution state =
  { common     : ObservedKubernetesPodCommon
  , scheduling : ObservedPodScheduling state
  , equality   : ObservedPodCommonSchedulingIdentityTemplateResourceEqualityWitness state
  }

SomeObservedKubernetesPodExecution =
  < PendingUnscheduled : ObservedKubernetesPodExecution PendingUnscheduled
  | Reserved           : ObservedKubernetesPodExecution Reserved
  | BindingRecovery    : ObservedKubernetesPodExecution BindingRecovery
  | Bound              : ObservedKubernetesPodExecution Bound
  | Terminating        : ObservedKubernetesPodExecution Terminating
  | Terminal           : ObservedKubernetesPodExecution Terminal
  >

HostReservationState =
  < Reserved | LaunchInFlight | Running | Draining | RetainedArtifacts >

HostReservationCommon =
  { reservation     : HostReservationId
  , deployment      : DeploymentId
  , generation      : ProvisionGenerationDigest
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , template        : HostReservationTemplateDigest
  , supervisor      : HostSupervisorId
  , host            : HostId
  }

HostReservationAxes state =
  < Active :
      { state : < Reserved | LaunchInFlight | Running | Draining >
      , axes  : CompleteHostResourceReservation HostReservationId
      }
  | Retained :
      { state : RetainedArtifacts
      , axes  : RetainedHostResourceReservation
      }
  > -- private constructor requires embedded state = type index

HostReservationProcess state =
  < Reserved :
      { state : Reserved, process : NotCreated }
  | LaunchInFlight :
      { state : LaunchInFlight
      , process : < NotCreated | Observed : HostProcessInstanceId >
      }
  | Running :
      { state : Running, process : Observed HostProcessInstanceId }
  | Draining :
      { state : Draining, process : Observed HostProcessInstanceId }
  | RetainedArtifacts :
      { state : RetainedArtifacts, process : NotCreated }
  > -- private constructor requires selected arm = state

HostReservationRecord state =
  { common          : HostReservationCommon
  , axes            : HostReservationAxes state
  , state           : state
  , process         : HostReservationProcess state
  , resourceVersion : ResourceVersion
  , casVersion      : HostReservationCasVersion
  , stateEquality   : HostReservationStateEqualityWitness state
  }

HostLaunchInFlightNoProcessRecord = -- opaque refinement
  { record          : HostReservationRecord LaunchInFlight
  , processEquality : record.process == NotCreated
  }

HostLaunchInFlightObservedRecord = -- opaque refinement
  { record          : HostReservationRecord LaunchInFlight
  , process         : HostProcessInstanceId
  , processEquality : record.process == Observed process
  }

SomeHostReservationRecord =
  < Reserved          : HostReservationRecord Reserved
  | LaunchInFlight    : HostReservationRecord LaunchInFlight
  | Running           : HostReservationRecord Running
  | Draining          : HostReservationRecord Draining
  | RetainedArtifacts : HostReservationRecord RetainedArtifacts
  >

ObservedHostProcessReservation state =
  < LaunchRecovery : HostLaunchInFlightObservedRecord
  | Running        : HostReservationRecord Running
  | Draining       : HostReservationRecord Draining
  > -- private constructor requires selected arm = state

ObservedHostProcessExecution state =
  { process         : HostProcessInstanceId
  , reservation     : ObservedHostProcessReservation state
  , state           : state
  , resource        : HostResourceEnvelope
  , sourceEquality  : ObservedHostProcessReservationEqualityWitness
  }

SomeObservedHostProcessExecution =
  < LaunchRecovery : ObservedHostProcessExecution LaunchRecovery
  | Running        : ObservedHostProcessExecution Running
  | Draining       : ObservedHostProcessExecution Draining
  >

LedgerOnlyAbsentRecovery state =
  < Reserved :
      { state       : Reserved
      , reservation : ReservedSchedulerReservationRef
      , podAbsent   : ObservedPodUidAbsentWitness
      , release     : ReservedReleaseByWholeRootCasCapability
      }
  | BindingInFlight :
      { state       : BindingInFlight
      , reservation : BindingInFlightSchedulerReservationRef
      , podAbsent   : ObservedPodUidAbsentWitness
      , release     : BindingInFlightReleaseCapability
      , apiEtcdRelease : PendingPodApiObjectAbsenceWitness
      }
  | Bound :
      { state       : Bound
      , reservation : BoundSchedulerReservationRef
      , podAbsent   : ObservedPodUidAbsentWitness
      , release     : RequireFreshResourceIndexedReleasePartition
      }
  | Terminating :
      { state       : Terminating
      , reservation : TerminatingSchedulerReservationRef
      , podAbsent   : ObservedPodUidAbsentWitness
      , release     : RequireFreshResourceIndexedReleasePartition
      }
  | TerminalRetained :
      { state       : TerminalRetained
      , reservation : TerminalRetainedSchedulerReservationRef
      , podAbsent   : ObservedPodUidAbsentWitness
      , cleanup     : RequirePersistedCompletionDeadlineAndArtifactCleanup
      }
  > -- private constructor requires the selected arm's embedded state to equal the type index.
    -- Its exact identity/source/vector debit is the state-indexed projection of reservation.axes; no
    -- independent debit can be paired with another ledger row.

SomeLedgerOnlyAbsentRecovery =
  < Reserved         : LedgerOnlyAbsentRecovery Reserved
  | BindingInFlight  : LedgerOnlyAbsentRecovery BindingInFlight
  | Bound            : LedgerOnlyAbsentRecovery Bound
  | Terminating      : LedgerOnlyAbsentRecovery Terminating
  | TerminalRetained : LedgerOnlyAbsentRecovery TerminalRetained
  >

ObservedHostReservationLedger =
  { identity       : HostReservationLedgerId
  , entries        : Map HostReservationId SomeHostReservationRecord
  , keyEquality    : HostReservationKeyOwnerEqualityWitness
  , recordAxesEquality : HostReservationCommonHostOwnerTemplateAxesEqualityWitness
  , processJoin    : HostReservationProcessJoinWitness
  , residentStorage: ObservedHostResidentResourceBaseline
  , resourceVersion: ResourceVersion
  , casVersion     : HostReservationCasVersion
  , controlPlanePerHost: HostReservationAuthorityWitness
  }

ObservedHostResidentResourceBaseline =
  { activeByReservation : Map HostReservationId
      { localComponents : Map HostStorageExtentId
          { backing : HostStorageBackingId, bytes : Quantity Bytes }
      , cacheExtents : Map CacheExtentId HostCacheExtent
      }
  , retainedByReservation : Map HostReservationId RetainedHostResourceReservation
  , activeLedgerJoin : ActiveHostArtifactLedgerEqualityWitness
  , activeRetainedPartition : HostActiveRetainedArtifactPartitionWitness
  , localBackingTotals : Map HostStorageBackingId (Quantity Bytes)
  , cacheBackingTotals : Map CacheBackingId (Quantity Bytes)
  , fingerprint      : InventoryFingerprint
  }

HostReservationSetFold =
  { runtimeByHost    : Map HostId
      { cpuReservation : Residual Cpu
      , cpuCeiling     : Residual Cpu
      , memoryReservation : Residual Bytes
      , memoryCeiling : Residual Bytes
      }
  , cudaOwners       : Map ProvisionedAcceleratorDeviceRef HostReservationId
  , metalByHost      : Map HostId (Residual Bytes)
  , cacheExtents     : Map HostCacheExtentKey HostCacheExtent
  , localBackingTotals : Map HostStorageBackingId (Quantity Bytes)
  , cacheBackingTotals : Map CacheBackingId (Quantity Bytes)
  , cacheIdentityUnion : HostCacheExtentIdentityBackingModelUnionWitness
  , fit              : CompleteHostCapacityFitWitness
  , activeResidentJoin : ActiveHostArtifactLedgerEqualityWitness
  , noDoubleDebit    : HostReservationDedupWitness
  }

HostReservationFoldInput =
  { host             : HostId
  , allocatable      : ObservedHostCapacity
  , commitments      : Map HostCommitmentOwner HostCommitment
  , commitmentKeys   :
      HostCommitmentMapKeyOwnerAndEveryValueHostEqualsInputHostWitness
  , ledger           : ObservedHostReservationLedger
  , residentEquality : HostFoldLedgerResidentBaselineEqualityWitness
  , candidate        : Optional (CompleteHostResourceReservation HostReservationId)
  , candidateLedgerIdempotency : HostCandidateLedgerReservationIdAxesIdempotencyWitness
  , inventoryFingerprint : InventoryFingerprint
  , capacityFingerprint  : ObservedCapacityFingerprint
  , domainEquality   : HostReservationFoldInputDomainWitness
  }

foldHostReservationSet
  :: Topology
  -> HostReservationFoldInput
  -> Either ProvisionError HostReservationSetFold
-- re-folds the per-host control-plane daemon ledger plus retained residents; active rows carry full runtime/device axes,
-- RetainedArtifacts rows carry zero runtime/device axes, and every key/owner/process/host join is exact

RetainedHostResourceReservation =
  { reservation      : HostReservationId
  , localComponents  : Map HostStorageExtentId
      { backing : HostStorageBackingId, bytes : Quantity Bytes }
  , cacheExtents     : Map CacheExtentId HostCacheExtent
  , localBackingTotals : Map HostStorageBackingId (Quantity Bytes)
  , cacheBackingTotals : Map CacheBackingId (Quantity Bytes)
  , zeroRuntime      : ZeroHostCpuMemoryReservationWitness
  , zeroAccelerator  : EmptyHostAcceleratorReservationWitness
  , residentEquality : ObservedHostResidentResourceEqualityWitness
  }

HostResourceReservationPartition =
  { reservation      : HostReservationId
  , cpuReservation   : Residual Cpu
  , cpuCeiling       : Residual Cpu
  , memoryReservation: Residual Bytes
  , memoryCeiling    : Residual Bytes
  , localComponents  : Map HostStorageExtentId
      { backing : HostStorageBackingId, bytes : Quantity Bytes }
  , cacheExtents     : Map CacheExtentId HostCacheExtent
  , localBackingTotals : Map HostStorageBackingId (Quantity Bytes)
  , cacheBackingTotals : Map CacheBackingId (Quantity Bytes)
  , cudaDevices      : Map ProvisionedAcceleratorDeviceRef
      (CudaDeviceReservation HostReservationId)
  , metalUnifiedMemory : Residual Bytes
  }

HostReservationReleaseWitness =
  { reservation      : HostReservationId
  , reserved         : CompleteHostResourceReservation HostReservationId
  , released         : HostResourceReservationPartition
  , retained         : RetainedHostResourceReservation
  , partitionExact   : HostReservationPartitionExactWitness
  , intersectionEmpty: HostReservationPartitionDisjointWitness
  , observation      :
      < Ordinary : ObservedProcessAbsent
      | Cuda     : ValidatedCudaReleaseEvidence
      | Metal    : ValidatedMetalReleaseEvidence
      >
  , ledgerCas        : HostReservationReleaseCasWitness
  , sourceEquality   :
      HostReleaseReservationOwnerHostSourceArmObservationCasEqualityWitness
  }
```

## 18. Observed execution and normalization

```text
ObservedExecutionInstance =
  < KubernetesPod : SomeObservedKubernetesPodExecution
  | HostProcess   : SomeObservedHostProcessExecution
  | HostReservation :
      < Reserved          : HostReservationRecord Reserved
      | LaunchInFlight    : HostLaunchInFlightNoProcessRecord
      | RetainedArtifacts : HostReservationRecord RetainedArtifacts
      >
  >

KubernetesPodControllerChain =
  < Deployment :
      { replicaSet         : KubernetesControllerUid
      , deployment         : KubernetesControllerUid
      , podToReplicaSet    : OwnerReferenceWitness
      , replicaSetToDeploy : OwnerReferenceWitness
      , revisionHash       : PodTemplateHash
      , resourceVersions   : NonEmptyMap KubernetesControllerUid ResourceVersion
      }
  | StatefulSet :
      { owner : KubernetesControllerUid, resourceVersion : ResourceVersion }
  | DaemonSet :
      { owner : KubernetesControllerUid, resourceVersion : ResourceVersion }
  | Job :
      { owner : KubernetesControllerUid, resourceVersion : ResourceVersion }
  >

ObservedExecutionId =
  < KubernetesPod : PodUid
  | HostProcess   : HostProcessInstanceId
  | HostReservation : HostReservationId
  >
ObservedExecutionSet = Map ObservedExecutionId ObservedExecutionInstance
-- checked construction proves each map key equals the embedded union identity

NormalizedExecutionCommitment =
  < PendingUnscheduled :
      { execution : ObservedKubernetesPodExecution PendingUnscheduled
      , api       : PendingPodApiCommitment
      , equality  : PendingPodApiCommitmentEqualityWitness
      }
  | Reserved :
      { execution   : ObservedKubernetesPodExecution Reserved }
      -- reservation ref and debit are execution.scheduling.reservation and its axes.
  | BindingRecovery :
      { execution   : ObservedKubernetesPodExecution BindingRecovery }
      -- repaired BindingInFlight ref and debit are projections of execution.scheduling.
  | LedgerOnlyAbsent : SomeLedgerOnlyAbsentRecovery
  | Bound :
      { execution   : ObservedKubernetesPodExecution Bound }
  | Terminating :
      { execution   : ObservedKubernetesPodExecution Terminating }
      -- Bound/Terminating reservation refs and debits are derived only from execution.scheduling.
  | Terminal :
      { execution : ObservedKubernetesPodExecution Terminal }
      -- retained/release are derived only from execution.scheduling.retained/schedulerReleased.
  | HostReservation : HostReservationRecord Reserved
  | HostLaunchRecovery :
      { execution : ObservedHostProcessExecution LaunchRecovery }
      -- the observed LaunchInFlight record is execution.reservation; there is no second record to pair.
  | HostLaunchPending :
      { reservation : HostLaunchInFlightNoProcessRecord }
      -- no-process is already proven by the refinement; the debit is reservation.record.axes.
  | HostProcess :
      < Running  : ObservedHostProcessExecution Running
      | Draining : ObservedHostProcessExecution Draining
      >
  | HostRetainedArtifacts : RetainedHostResourceReservation
  >

NormalizedExecutionCommitmentSet =
  { commitments : Map ObservedExecutionId NormalizedExecutionCommitment
  , sourceDomain : ExecutionCommitmentSourceDomainWitness
  , noDoubleDebit: ExecutionCommitmentDedupWitness
  }

ObservedJobCompletion =
  { executionDigest : JobExecutionIdentityDigest
  , outcome         :
      < Succeeded
      | FailedBackoffExhausted : { retryPolicy : RequireNewExecutionRevision }
      >
  , entry           : ControlPlaneStateId
  , payload         : CanonicalJobCompletionPayload
  , contentDigest   : CanonicalContentDigest
  , storageBudget   : StorageBudgetId
  , objectStore     : ObjectStoreId
  , variantEquality :
      JobCompletionPayloadExecutionOutcomeAndContentDigestEqualityWitness
  , sourceEquality  : JobCompletionSourceEqualityWitness
  , resourceVersion : ObjectVersion
  }

SchedulerResourceReleaseWitness =
  { podUid            : PodUid
  , reservationState  :
      < Removed :
          { absent        : SchedulerReservationAbsenceWitness
          , zeroRetainedSchedulerSlots :
              ZeroRetainedPodCniCsiReservationWitness
          , physicalTransferredToResidentRoot :
              RetainedPhysicalDebitRootTransferWitness
          }
      | TerminalRetained :
          { reservation   : TerminalRetainedSchedulerReservationRef
          , retainedSlots : RetainedPodCniCsiLedgerEqualityWitness
          }
      >
  , reservedAxes      : CompleteResourceReservation PodUid
  , releasedAxes      : ResourceReservationPartition PodUid
  , retainedAxes      : RetainedResourceReservation PodUid
  , partitionExact    : Required
  , intersectionEmpty : Required
  , slotRelease       : PodSlotReleaseEvidence
  , releaseObservation:
      < Ordinary :
          { podAbsent : ObservedPodUidAbsentWitness
          , resident  : ObservedResidentResourceEqualityWitness
          }
      | Cuda :
          { release   : ValidatedCudaReleaseEvidence
          , resident  : ObservedResidentResourceEqualityWitness
          }
      | JobTerminal :
          { terminal  : JobTerminalOutcomeEvidence
          , resident  : ObservedResidentResourceEqualityWitness
          }
      >
  , retainedStateEquality : TerminalReservationStateWitness
  , sourceEquality :
      SchedulerReleasePodReservationAxesSlotsObservationEqualityWitness
  }

TerminalSchedulerReleasePolicy =
  { terminalOutcome      : RequireAuthenticatedJobTerminalOutcome
  , computeRelease       : ReleaseCpuMemoryAndLogicalEphemeral
  , deviceRelease        : None -- gadt-decode permits CUDA Pods only in the serial DaemonSet owner arm
  , slotRelease          : RequirePerPodCniCsiReleaseOrTerminalRetainedLedgerDebit
  , physicalRetention    :
      RequireExactRuntimeMetadataLogSnapshotAndPodLocalResidentPartition
  , apiEtcdRetention     : RequireTerminalPodRetentionDemandUntilCleanup
  , cleanup              :
      RequirePersistedCompletionFreshDeadlineAndObservedResidentRelease
  , partitionEquality    : TerminalSchedulerReleaseAxisCompletenessWitness
  }
```

## 19. Log retention and provisioned controllers

```text
ContainerLogRetentionDemand =
  { container       : ContainerId
  , stream          : ContainerLogStreamId
  , maxBytesPerFile : Quantity Bytes
  , maxBackups      : Natural
  , activeAndRotatedPeak : Quantity Bytes
  , retention       : FiniteDuration
  , model           : ContainerLogStorageModelVersion
  , derivation      : ContainerLogRotationPeakWitness
  }

PodLogRetentionDemand =
  { streams         : NonEmptyMap ContainerId ContainerLogRetentionDemand
  , backing         : ProvisionedRuntimeOrStorageBackingRef
  , retainedBytes   : Quantity Bytes
  , streamDomain    : PodContainerLogDomainEqualityWitness
  , backingEquality : PodLogBackingGroupingWitness
  , derivation      : PodLogRetentionPeakWitness
  }

TerminalPodRetentionDemand =
  { podUid          : PodUid
  , deployment      : DeploymentId
  , generation      : ProvisionGenerationDigest
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , lastNode        : NodeId
  , apiObject       : KubernetesApiObjectSource
  , etcd            : EtcdLogicalObjectSource
  , runtimeMetadata : ObservedKubeletRuntimeMetadataDemand
  , backingResolution : RuntimeMetadataBackingGroupingWitness
  , logs            : PodLogRetentionDemand
  , cleanupDeadline : FiniteDeadline
  , witness         : TerminalPodRetentionWitness
  }

PriorExecutionProvision = -- private projection resolved only from ProvisionContext.priorSpecs
  { source         : PriorExecutionProvisionRef
  , steady         : Map PlannedExecutionSlotId MaterializedExecutionInstance
  , controllers    : Map ExecutionUnitId ProvisionedExecutionController
  , transitionGuards : Map ExecutionUnitId PriorExecutionTransitionGuardProjection
  , sourceEquality : PriorExecutionSourceEqualityWitness
  , witness        : PriorExecutionProvisionWitness
  }

ProvisionedExecutionEpochs = -- private ProvisionedSpec member
  { transitionSource      : ExecutionTransitionSource
  , priorSteady           : Map PlannedExecutionSlotId MaterializedExecutionInstance
  , priorSourceEquality   : PriorExecutionSourceEqualityWitness
  , desiredSourceEquality : ExecutionSourceEqualityWitness
  , desiredControllers    : NonEmptyMap ExecutionUnitId ProvisionedExecutionController
  , controllerEquality    : ExecutionControllerProjectionWitness
  , steady                : ExecutionEpoch
  , rollout               : NonEmpty ExecutionEpoch
  , podScheduling         :
      < NoPodExecution : EmptyPodExecutionDomainWitness
      | Pods :
          { domain   : NonEmptySet ExecutionUnitId
          , guard    : ProvisionedExecutionSchedulingGuard
          , equality : PodExecutionDomainWitness
          }
      >
  , transitionGuards      : NonEmptyMap ExecutionUnitId ProvisionedExecutionTransitionGuard
  , transitionGuardEquality : ExecutionTransitionGuardDomainWitness
  , runtimeStorageByEpoch : NonEmptyMap ExecutionEpochFingerprint
      (Map ProvisionedNodeTarget ProvisionedPlannedNodeRuntimeStorageAccounting)
  , runtimeStorageEquality: ExecutionRuntimeStorageDomainWitness
  , witness               : ExecutionEpochCapacityWitness
  }

ProvisionedExecutionController = -- authority comes from its container, never from this payload alone
  < Deployment  : ProvisionedDeploymentController
  | StatefulSet : ProvisionedStatefulSetController
  | DaemonSet   : ProvisionedDaemonSetController
  | Job         : ProvisionedJobController
  | HostProcess : ProvisionedHostProcessController
  >
-- `ProvisionedExecutionEpochs.desiredControllers` may render/apply desired state. The same payload under
-- `PriorExecutionProvision.controllers` cannot render desired state; only a fresh snapshot-bound transition
-- action may use it to delete/prune the authenticated predecessor.

ProvisionedPodController =
  < Deployment  : ProvisionedDeploymentController
  | StatefulSet : ProvisionedStatefulSetController
  | DaemonSet   : ProvisionedDaemonSetController
  | Job         : ProvisionedJobController
  >

ProvisionedPodControllerTemplateIdentity =
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest
  , sourceUnit : ExecutionUnitId
  , namespace  : NamespaceId
  , revision   : ExecutionRevisionId
  , reservationTemplateSet : SchedulerTemplateSetDigest
  }

ProvisionedHostProcessTemplateIdentity =
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest
  , sourceUnit : ExecutionUnitId
  , revision   : ExecutionRevisionId
  , scope      : HostExecutionScopeId
  , reservationTemplate : HostReservationTemplateDigest
  }

ProvisionedDeploymentController =
  { replicas    : PositiveNatural
  , rollout     : DeploymentRolloutPolicy
  , template    : ProvisionedPodControllerTemplateIdentity
  , scheduler   : AmoebiusCapacityScheduler
  , witness     : DeploymentControllerProjectionWitness
  }

ProvisionedStatefulSetController =
  { replicas    : PositiveNatural
  , rollout     :
      < OnDelete : ProvisionedSerialOnDeletePolicy
      | RollingUpdate : NativeSerialPartitionZero
      >
  , template    : ProvisionedPodControllerTemplateIdentity
  , scheduler   : AmoebiusCapacityScheduler
  , witness     : StatefulSetControllerProjectionWitness
  }

ProvisionedNodeEligibilitySelector =
  { source          : NodeEligibilitySelector
  , eligibleTargets : NonEmptySet ProvisionedNodeTarget
  , affinity        : DerivedNodeAffinityProjection
  , taints          : DerivedTolerationProjection
  , sourceEquality  :
      NodeSelectorTargetAffinityTaintCapabilityEqualityWitness
  }

ProvisionedDaemonSetController =
  { selector        : ProvisionedNodeEligibilitySelector
  , eligibleTargets : NonEmptyMap ProvisionedNodeTarget PlannedExecutionSlotId
  , elasticCover   : PerNodeElasticMaximumCoverWitness
  , observedBindingsRequired : PerNodeTargetBindingBeforeSchedulingWitness
  , rollout       :
      < OnDelete : ProvisionedSerialOnDeletePolicy
      | RollingUpdate : < Surge : PositiveNatural | Unavailable : PositiveNatural >
      >
  , template      : ProvisionedPodControllerTemplateIdentity
  , scheduler     : AmoebiusCapacityScheduler
  , witness       : DaemonSetControllerProjectionWitness
  }

ProvisionedJobController =
  { policy    : JobExecutionPolicy
  , template  : ProvisionedPodControllerTemplateIdentity
  , scheduler : AmoebiusCapacityScheduler
  , terminalRetention : ProvisionedJobTerminalRetention
  , completion         : ProvisionedJobCompletionPlan
  , witness   : JobControllerProjectionWitness
  }

JobExecutionWave =
  { index            : Natural
  , activeAttempts   : NonEmptyMap PlannedExecutionSlotId
      { completionIndex : Optional Natural
      , attempt         : Natural
      , resource        : PodResourceEnvelope
      }
  , completedBefore  : Natural
  , failedBefore     : Natural
  , parallelismBound : JobParallelismEqualityWitness
  , backoffBound     : JobBackoffAttemptEqualityWitness
  }

JobExecutionTemplateDigest =
  canonical digest of the revision-stable executable Pod template operands
  (images, command/config identities, resources, mounts, volumes, runtime class, placement, and policy),
  excluding deployment-generation provenance annotations

JobExecutionIdentity =
  { deployment      : DeploymentId
  , sourceUnit      : ExecutionUnitId
  , revision        : ExecutionRevisionId
  , podTemplate     : JobExecutionTemplateDigest
  , completions     : PositiveNatural
  , parallelism     : PositiveNatural
  , backoffLimit    : Natural
  , replacement     : Failed
  , policyModel     : JobExecutionPolicyModelVersion
  }

JobExecutionIdentityDigest =
  canonical digest of the complete JobExecutionIdentity record

CanonicalJobCompletionOutcome =
  < Succeeded
  | FailedBackoffExhausted : { retryPolicy : RequireNewExecutionRevision }
  >

CanonicalJobCompletionPayload =
  { execution       : JobExecutionIdentity
  , executionDigest : JobExecutionIdentityDigest
  , completedGeneration : ProvisionGenerationDigest -- provenance, not part of execution identity
  , outcome         : CanonicalJobCompletionOutcome
  , canonicalModel  : JobCompletionCanonicalizationModelVersion
  , identityEquality: JobExecutionIdentityDigestEqualityWitness
  , payloadEquality : JobCompletionPayloadOutcomeAndExecutionEqualityWitness
  }

TerminalPodRetentionPeak =
  { scenario         : JobTerminalScenarioId
  , terminalPods     : NonEmptyMap PlannedExecutionSlotId
      { outcome      : < Succeeded | Failed >
      , lastTarget   : ProvisionedNodeTarget
      , apiObject    : KubernetesApiObjectSource
      , etcdObject   : EtcdLogicalObjectSource
      , runtimeShape : PlannedKubeletRuntimeMetadataDemand
      , logs         : PodLogRetentionDemand
      }
  , apiEtcdDemand    : Quantity Bytes
  , runtimeByTarget  : Map ProvisionedNodeTarget ProvisionedPlannedNodeRuntimeStorageAccounting
  , retainedPeakByBacking : Map ProvisionedRuntimeOrStorageBackingRef (Quantity Bytes)
  , completeness     : JobTerminalScenarioCompletenessWitness
  }

JobTerminalCleanupProjection =
  { cleanupAfter     : FiniteDuration
  , deadlineModel    : JobTerminalRetentionModelVersion
  , nativeTtlField   : Absent
  , order            :
      ObserveTerminalThenPersistCompletionThenObserveCompletionThenDeadlineThenCleanup
  , retainedUntil    : RequireFreshDeadlineAndResidentReleaseEvidence
  , witness          : JobTerminalCleanupDerivationWitness
  }

JobCompletionControlPlaneStateEntryDemand = -- opaque refinement
  { base          : ControlPlaneStateEntryDemand
  , kindEquality  : base.kind == JobCompletion
  , identityEquality : JobExecutionIdentityToControlPlaneStateIdWitness
  }

ProvisionedControlPlaneStateProducerRef =
  { source        : ControlPlaneStateObjectDemand
  , peak          : ProvisionedObjectStoreLogicalPeak
  , gateway       : ProvisionedObjectStoreAdmissionGateway
  , writer        : ObjectStoreWriterId
  , budget        : StorageBudgetId
  , sourceEquality: ControlPlaneStateProducerAndGatewayEqualityWitness
  }

ProvisionedJobTerminalRetention =
  { maxTerminalPods : PositiveNatural -- derived from completions/backoff/model, never authored separately
  , activeWaves     : NonEmpty JobExecutionWave
  , retainedPeak   : TerminalPodRetentionPeak
  , apiEtcdPeak    : ApiEtcdTransitionWitness
  , backingPeak    : NodeRuntimeBackingGroupingWitness
  , cleanup        : JobTerminalCleanupProjection
  , witness        : JobTerminalRetentionDerivationWitness
  }

ProvisionedJobCompletionLedgerRef =
  { executionDigest : JobExecutionIdentityDigest
  , entry           : JobCompletionControlPlaneStateEntryDemand
  , producer        : ProvisionedControlPlaneStateProducerRef
  , storageBudget   : StorageBudgetId
  , variants        :
      { succeeded :
          { payload       : CanonicalJobCompletionPayload
          , contentDigest : CanonicalContentDigest
          , outcome       : Succeeded
          }
      , failedBackoffExhausted :
          { payload       : CanonicalJobCompletionPayload
          , contentDigest : CanonicalContentDigest
          , outcome       : FailedBackoffExhausted
          , retryPolicy   : RequireNewExecutionRevision
          }
      }
  , entryBound      : MaxOfClosedCompletionVariantPayloadsWitness
  , objectStoreWitness : ControlPlaneStateProducerEqualityWitness
  , variantEquality :
      JobCompletionLedgerExecutionEntryProducerBudgetVariantEqualityWitness
  , sourceEquality  : JobCompletionLedgerSourceIdentityEqualityWitness
  , noRerun         : ContentAddressedCompletionSuppressionWitness
  }

DeferredJobCompletionDemand =
  { executionDigest : JobExecutionIdentityDigest
  , entry           : JobCompletionControlPlaneStateEntryDemand
  , variants        :
      { succeeded :
          { payload       : CanonicalJobCompletionPayload
          , contentDigest : CanonicalContentDigest
          , outcome       : Succeeded
          }
      , failedBackoffExhausted :
          { payload       : CanonicalJobCompletionPayload
          , contentDigest : CanonicalContentDigest
          , outcome       : FailedBackoffExhausted
          , retryPolicy   : RequireNewExecutionRevision
          }
      }
  , variantEquality : DeferredCompletionVariantPayloadDigestOutcomeEqualityWitness
  , noProducerYet   : AbsentProvisionedControlPlaneStateProducerWitness
  , terminalPolicy  : RetainTerminalPodsUntilProvisionedProducer
  , sourceEquality  : DeferredJobCompletionSourceWitness
  }

ProvisionedJobCompletionPlan =
  < DeferredUntilGateway :
      { demand : DeferredJobCompletionDemand
      , allowedAction : RetainTerminalAwaitingCompletionGatewayOnly
      }
  | Persistable :
      { ledger : ProvisionedJobCompletionLedgerRef
      , producerCapacity : ControlPlaneStateProducerEqualityWitness
      }
  >

JobSucceededEvidence =
  { execution       : JobExecutionIdentity
  , executionDigest : JobExecutionIdentityDigest
  , jobUid          : KubernetesControllerUid
  , terminalPods    : NonEmptyMap PodUid KubernetesSucceededConditionWitness
  , completions     : JobSucceededCompletionCountEqualityWitness
  , sourceEquality  : JobTerminalSourceRevisionPolicyEqualityWitness
  , digestEquality  : JobExecutionIdentityDigestEqualityWitness
  , fingerprint     : InventoryFingerprint
  }

JobBackoffExhaustedEvidence =
  { execution       : JobExecutionIdentity
  , executionDigest : JobExecutionIdentityDigest
  , jobUid          : KubernetesControllerUid
  , terminalPods    : NonEmptyMap PodUid KubernetesFailedConditionWitness
  , attempts        : JobBackoffExhaustionEqualityWitness
  , sourceEquality  : JobTerminalSourceRevisionPolicyEqualityWitness
  , digestEquality  : JobExecutionIdentityDigestEqualityWitness
  , fingerprint     : InventoryFingerprint
  }

ProvisionedHostProcessController =
  { instances   :
      < Once    : { host : HostId, slot : PlannedExecutionSlotId }
      | PerHost : NonEmptyMap HostId PlannedExecutionSlotId
      >
  , replacement : HostProcessReplacementPolicy
  , template    : ProvisionedHostProcessTemplateIdentity
  , topologyEquality : HostProcessTopologyProjectionWitness
  , witness     : HostProcessControllerProjectionWitness
  }

ProvisionedOrdinaryHostProcessController =
  opaque refinement of ProvisionedHostProcessController with RecreateAfterObservedExit
ProvisionedCudaHostProcessController =
  opaque refinement of ProvisionedHostProcessController with CudaRecreateAfterDeviceRelease
ProvisionedMetalHostProcessController =
  opaque refinement of ProvisionedHostProcessController with MetalDrainThenReplaceAfterObservedExit
```

## 20. Execution transition guards and release evidence

```text
ProvisionedExecutionTransitionGuard =
  < Pod :
      { scheduling  : ProvisionedExecutionSchedulingGuardRef
      , replacement : ProvisionedPodReplacementGuard
      }
  | HostProcess :
      < Ordinary :
          { reservation : ProvisionedHostProcessReservationGuard
          , replacement : RecreateAfterObservedExit
          , release     : RequireObservedProcessAbsent
          }
      | CudaOwner :
          { reservation : ProvisionedHostProcessReservationGuard
          , replacement : CudaRecreateAfterDeviceRelease
          , release     : ProvisionedCudaReleasePolicy
          }
      | MetalOwner :
          { reservation : ProvisionedHostProcessReservationGuard
          , replacement : MetalDrainThenReplaceAfterObservedExit
          , release     : ProvisionedMetalReleasePolicy
          }
      >
  >

PriorExecutionTransitionGuardProjection =
  opaque private projection of the prior unit's controller/resource-indexed replacement and release semantics

ProvisionedPodReplacementGuard =
  < Ordinary
  | CudaRecreateAfterDeviceRelease : ProvisionedCudaReleasePolicy
  >

ProvisionedCudaReleasePolicy =
  { owner          : ExecutionUnitId
  , devices        : NonEmptySet ProvisionedAcceleratorDeviceRef
  , requiredFree   : NonEmptyMap ProvisionedAcceleratorDeviceRef (Quantity Bytes)
  , sourceEquality : CudaReleaseSourceEqualityWitness
  }

ProvisionedMetalReleasePolicy =
  { owner          : ExecutionUnitId
  , host           : HostId
  , requiredMemory : Quantity Bytes
  , cacheBackings  : Set CacheBackingId
  , sourceEquality : MetalReleaseSourceEqualityWitness
  }

ValidatedCudaReleaseEvidence =
  { policy                : ProvisionedCudaReleasePolicy
  , oldOwnerAbsent        : ObservedExecutionAbsentWitness
  , deviceMaterialization : NonEmptyMap
      ProvisionedAcceleratorDeviceRef AcceleratorDeviceId
  , materializationSource :
      < KubernetesNode : ObservedNodeTargetBinding
      | NativeHost     : ObservedHostAcceleratorInventory
      >
  , materializationEquality :
      CudaReleaseDeviceMapAuthenticatedInventoryEqualityWitness
  , releasedDeviceHolds   : NonEmptyMap AcceleratorDeviceId DeviceHoldReleasedWitness
  , currentFreeReobserved : NonEmptyMap AcceleratorDeviceId (Residual Bytes)
  , policyDomainEquality  : CudaReleasePolicyMaterializedDeviceDomainWitness
  , observedDomainEquality: MaterializedCudaReleaseObservationDomainWitness
  , fingerprint           : AcceleratorReleaseFingerprint
  , inventoryFingerprint  : InventoryFingerprint
  , sourceEquality        :
      CudaPolicyOwnerAbsenceDeviceMaterializationReleaseSnapshotEqualityWitness
  }

ValidatedMetalReleaseEvidence =
  { policy                     : ProvisionedMetalReleasePolicy
  , drained                    : DrainedWitness
  , processAbsent              : ObservedProcessAbsent
  , hostInventory              : ObservedHostAcceleratorInventory
  , currentAllocatedReobserved : MetalAllocationReleaseWitness
  , cacheStateReobserved       : HostCacheReleaseWitness
  , policyReservationEquality  :
      MetalReleaseOwnerHostMemoryCacheReservationEqualityWitness
  , inventoryEquality          : MetalReleaseHostInventoryEqualityWitness
  , fingerprint                : MetalReleaseFingerprint
  , inventoryFingerprint       : InventoryFingerprint
  , sourceEquality             :
      MetalPolicyOwnerHostDrainProcessAbsenceReservationAllocationCacheSnapshotEqualityWitness
  }

ValidatedPodReleaseEvidence =
  < Ordinary :
      { oldPodAbsent : ObservedPodUidAbsentWitness
      , schedulerRelease : SchedulerResourceReleaseWitness
      , equality : OrdinaryPodAbsenceSchedulerReleaseEqualityWitness
      }
  | Cuda :
      { deviceRelease : ValidatedCudaReleaseEvidence
      , schedulerRelease : SchedulerResourceReleaseWitness
      , equality : CudaPodDeviceSchedulerReleaseEqualityWitness
      }
  >

HostStartAuthorization =
  < NoPrior :
      { controller : ProvisionedHostProcessController
      , host       : HostId
      , source     : AddedOrFirstDeploymentHostWitness
      , equality   : HostStartNoPriorControllerHostSourceEqualityWitness
      }
  | OrdinaryAfterExit :
      { controller : ProvisionedOrdinaryHostProcessController
      , host       : HostId
      , evidence   : ObservedProcessAbsent
      , reservationRelease : HostReservationReleaseWitness
      , equality   : HostStartOrdinaryControllerHostReleaseEqualityWitness
      }
  | CudaAfterDeviceRelease :
      { controller : ProvisionedCudaHostProcessController
      , host       : HostId
      , evidence   : ValidatedCudaReleaseEvidence
      , reservationRelease : HostReservationReleaseWitness
      , equality   : HostStartCudaControllerHostDeviceReleaseEqualityWitness
      }
  | MetalAfterDrain :
      { controller : ProvisionedMetalHostProcessController
      , host       : HostId
      , evidence   : ValidatedMetalReleaseEvidence
      , reservationRelease : HostReservationReleaseWitness
      , equality   : HostStartMetalControllerHostDrainReleaseEqualityWitness
      }
  >
-- Every private equality joins controller source/revision/template and target host to the exact prior
-- process/reservation/device/cache release evidence. No authorization arm can combine different hosts.

HostProcessRecordActionEqualityWitness process record capability =
  { processEqualsRecordProcess : Required
  , reservationIdentityExact   : Required
  , hostSourceRevisionExact    : Required
  , capabilityCasVersionExact  : Required
  }

HostReserveActionEqualityWitness authorization reservation fit cas =
  { authorizationTargetExact : Required
  , reservationAxesExact     : Required
  , fitCandidateExact        : Required
  , fitFingerprintExact      : Required
  , casLedgerVersionExact    : Required
  }

HostReservationActionEqualityWitness record capability =
  { reservationIdentityExact : Required
  , stateAndCasVersionExact  : Required
  , sourceRevisionExact      : Required
  }

ValidatedExecutionTransitionAction =
  < NoOp : ValidatedUnchangedExecutionWitness
  | ApplyDesiredPodController :
      { controller : ProvisionedPodController
      , apply      : PodControllerApplyCapability
      , equality   : PodControllerApplyIdentityGenerationFieldManagerEqualityWitness
      }
  | ApplyDesiredControllerForSerial :
      { controller : ProvisionedPodController
      , apply      : PodControllerApplyCapability
      , nextRequiresFreshTemplateObservation : Required
      , equality   : PodControllerApplyIdentityGenerationFieldManagerEqualityWitness
      }
  | SerialOnDeleteStart : ValidatedSerialOnDeletePlan
  | SerialOnDeleteResume: ValidatedSerialOnDeleteContinuation
  | SerialOnDeleteAdvance: ValidatedSerialOnDeleteAdvance
  | BeginHostProcessDrain :
      { process : HostProcessInstanceId
      , running : HostReservationRecord Running
      , cas     : HostRunningToDrainingCasCapability
      , equality: HostProcessRecordActionEqualityWitness process running cas
      }
  | StopHostProcess :
      { process : HostProcessInstanceId
      , draining : HostReservationRecord Draining
      , stop    : HostProcessStopOrDrainCapability
      , equality: HostProcessRecordActionEqualityWitness process draining stop
      }
  | ReserveHostProcess :
      { authorization : HostStartAuthorization
      , reservation   : CompleteHostResourceReservation HostReservationId
      , fit           : HostReservationSetFold
      , cas           : HostReserveCasCapability
      , equality      : HostReserveActionEqualityWitness authorization reservation fit cas
      }
  | BeginHostProcessLaunch :
      { reserved      : HostReservationRecord Reserved
      , cas           : HostReservedToLaunchInFlightCasCapability
      , equality      : HostReservationActionEqualityWitness reserved cas
      }
  | LaunchHostProcess :
      { launchInFlight: HostLaunchInFlightNoProcessRecord
      , start         : HostProcessStartCapability
      , equality      : HostReservationActionEqualityWitness launchInFlight.record start
      }
  | CleanupHostRetainedArtifacts :
      { retained      : HostReservationRecord RetainedArtifacts
      , evidence      : HostRetainedArtifactCleanupEvidence
      , cas           : HostRetainedArtifactsRemovalCasCapability
      , equality      : HostRetainedCleanupRecordEvidenceCasEqualityWitness
      }
  | PruneRemovedPodController :
      { priorController : ProvisionedPodController
      , prune           : PriorAuthenticatedControllerPruneCapability
      , equality        : PriorControllerPruneIdentityGenerationRvEqualityWitness
      }
  | RecordJobCompletion :
      { terminalEvidence : JobTerminalOutcomeEvidence
      , completion       : ProvisionedJobCompletionLedgerRef
      , variant          : ProvisionedJobCompletionVariant
      , completionEquality :
          JobCompletionVariantOutcomeExecutionDigestAndPayloadEqualityWitness
      , write            : ObjectStoreGatewayWriteCapability
      , writeEquality    : JobCompletionGatewayWriterSourceEqualityWitness
      }
  | RetainTerminalAwaitingCompletionGateway :
      { terminalEvidence : JobTerminalOutcomeEvidence
      , completion       : DeferredJobCompletionDemand
      , retained         : TerminalPodRetentionDemand
      , deferredEquality :
          DeferredJobTerminalEvidenceCompletionAndRetentionEqualityWitness
      , noWriteCapability: AbsentObjectStoreGatewayWriteCapabilityWitness
      }
  | CleanupTerminalPod :
      { authorization : ValidatedTerminalPodCleanupAuthorization
      , delete        : PriorAuthenticatedPodDeleteCapability
      , equality      : TerminalPodCleanupAuthorizationDeleteEqualityWitness
      }
      -- Pod, persisted completion, retained debit, release, and deadline derive from authorization only.
  | CompletedJobNoOp :
      { controller : ProvisionedJobController
      , completion : ObservedJobCompletion
      , equality   :
          JobCompletionControllerDigestOutcomeAndPayloadEqualityWitness
      }
  >

SnapshotBoundCleanupDeadlineReachedEvidence identity =
  { identity           : identity
  , cleanupDeadline    : FiniteDeadline
  , observedAt         : ObservationTimestamp
  , deadlineReached    : Required
  , inventoryFingerprint : InventoryFingerprint
  }

PodCleanupDeadlineReachedEvidence =
  SnapshotBoundCleanupDeadlineReachedEvidence PodUid

HostCleanupDeadlineReachedEvidence =
  SnapshotBoundCleanupDeadlineReachedEvidence HostReservationId

HostRetainedArtifactCleanupEvidence =
  { reservation       : HostReservationId
  , localArtifactsGone: Map HostStorageExtentId ObservedHostArtifactAbsentWitness
  , cacheArtifactsGone: Map CacheExtentId ObservedHostCacheExtentAbsentWitness
  , deadlineReached   : HostCleanupDeadlineReachedEvidence
  , fingerprint       : InventoryFingerprint
  , sourceEquality    : HostRetainedArtifactCleanupSourceWitness
  }

JobTerminalOutcomeEvidence =
  < Succeeded : JobSucceededEvidence
  | FailedBackoffExhausted :
      { evidence         : JobBackoffExhaustedEvidence
      , retryPolicy      : RequireNewExecutionRevision
      , equality         : JobBackoffEvidenceRetryPolicyEqualityWitness
      }
  >

DeferredJobTerminalEvidenceCompletionAndRetentionEqualityWitness =
  { executionDigestExact          : Required
  , outcomeVariantExact           : Required
  , terminalPodMembershipExact    : Required
  , deploymentGenerationExact     : Required
  , sourceRevisionExact           : Required
  , retentionAndRuntimeDebitExact : Required
  }
-- Private construction joins terminalEvidence, completion, and retained from one execution/source row.

ValidatedTerminalPodCleanupAuthorization =
  { terminalOutcome      : JobTerminalOutcomeEvidence
  , completionEquality   : JobCompletionOutcomeAndDigestEqualityWitness
  , retentionEquality    : TerminalPodRetentionEqualityWitness
  , schedulerRelease     : SchedulerResourceReleaseWitness
  , deadlineReached      : PodCleanupDeadlineReachedEvidence
  , observationFreshness : LiveObservationFreshnessWitness
  , sourceEquality       :
      TerminalOutcomeCompletionRetentionReleaseDeadlineSnapshotEqualityWitness
  }

ProvisionedJobCompletionVariant =
  < Succeeded :
      { payload       : CanonicalJobCompletionPayload
      , contentDigest : CanonicalContentDigest
      }
  | FailedBackoffExhausted :
      { payload       : CanonicalJobCompletionPayload
      , contentDigest : CanonicalContentDigest
      , retryPolicy   : RequireNewExecutionRevision
      }
  >
```

## 21. Namespace quota, admission, and the capacity-scheduler system

```text
ExecutionSchedulingGuardId =
  digest of deployment, scheduler config generation, and exact prior+desired Pod source/revision domain

ProvisionedExecutionSchedulingGuardRef =
  { identity       : ExecutionSchedulingGuardId
  , sourceUnit     : ExecutionUnitId
  , podDomain      : NonEmptySet ExecutionUnitId
  , sourceDomain   : NonEmptySet (ExecutionSourceGeneration, ExecutionUnitId, ExecutionRevisionId)
  , member         : PodExecutionDomainMembershipWitness
  , guardFingerprint : ProvisionedExecutionSchedulingGuardFingerprint
  , equality       : SharedSchedulingGuardReferenceEqualityWitness
  }

ResourceQuotaRequestVector =
  { cpu              : Quantity Cpu
  , memory           : Quantity Bytes
  , ephemeralStorage : Quantity Bytes
  , extended         : Map ExtendedResourceName PositiveNatural
  }

ResourceQuotaLimitVector =
  { cpu              : Quantity Cpu
  , memory           : Quantity Bytes
  , ephemeralStorage : Quantity Bytes
  , extended         : Map ExtendedResourceName PositiveNatural
  }

ResourceQuotaObjectCountVector =
  { pods        : Natural
  , deployments : Natural
  , statefulSets: Natural
  , daemonSets  : Natural
  , jobs        : Natural
  }

ExecutionNamespaceQuota =
  { namespace       : NamespaceId
  , sourceUnits     : NonEmptySet ExecutionUnitId
  , requests        : ResourceQuotaRequestVector
  , limits          : ResourceQuotaLimitVector
  , counts          : ResourceQuotaObjectCountVector
  , apiObject       : KubernetesApiObjectSource
  , projection      : ExactGuardedPodQuotaProjectionWitness
  }

ExecutionNamespaceQuotaProjection =
  { namespaces      : NonEmptyMap NamespaceId ExecutionNamespaceQuota
  , podDomain       : NonEmptySet ExecutionUnitId
  , exactDomain     : NamespaceQuotaPodDomainEqualityWitness
  , disjointGrouping: NamespaceQuotaSourceDisjointnessWitness
  , noSchedulerAxisOmission :
      ResourceQuotaExpressibleAxesAndSchedulerOnlyAxesPartitionWitness
  }

ProvisionedExecutionSchedulingGuard = -- private Pod guard; derived, never caller-authored
  { identity            : ExecutionSchedulingGuardId
  , deployment          : DeploymentId
  , podDomain           : NonEmptySet ExecutionUnitId
  , allowedSources      : ExecutionTransitionSourceEqualityWitness
  , capacity            : ExecutionTransitionCapacityWitness
  , namespaceQuota      : ExecutionNamespaceQuotaProjection
  , podAdmission        : ExecutionPodAdmissionProjection
  , schedulerReservation: ExecutionSchedulerReservationProjection
  , witness             : TerminatingCommitmentAdmissionWitness
  }

ExecutionPodAdmissionProjection =
  { namespaces          : NonEmptySet NamespaceId
  , protectedAnnotations:
      { deployment : Required
      , generation : Required
      , sourceUnit : Required
      , revision   : Required
      , reservationTemplateSet : Required
      }
  , createRule          :
      { identityAndScheduler : RequireProvisionedIdentityAndScheduler
      , nodeName            : MustBeAbsent
      , specProjection      : RequireExactProvisionedResourcesImagesVolumesRuntimeClassAffinityAndTolerations
      }
  , updateRule          : RejectProtectedFieldChangeOrRemoval
  , capacityMutationRule:
      { ephemeralContainers : DenyForManagedPods
      , inPlaceResize       : RequireAtomicReservationDeltaBeforeMutation
      , resourceFields      : RequireReservationTemplateEquality
      , volumeAttachments   : RequireProvisionedTransitionAndAtomicReservationDelta
      , pvcExpansion        : RequireNewProvisionedVolumeTransition
      }
  , bindingRule         :
      { writer : SchedulerServiceAccountOnly
      , node   : MustEqualBindingInFlightReservation
      , rbac   : ExclusivePodsBindingSubresourceWriterWitness
      }
  , ownerChainRule      : RequireKindIndexedControllerChain
  , schedulerReserveRule: RecheckIdentityOwnerChainAndGeneration
  , writerScope         : ManagedControllerWriterSet
  , bootstrapException  :
      { unit      : ExecutionUnitId
      , scheduler : DefaultScheduler
      , node      : NodeId
      , staticDebit : CompleteResourceReservation ExecutionUnitId
      , namespaceQuota : ExactPodsOneResourceQuota
      , writerScope : SoleBootstrapControllerWriter
      , equality  : UniqueSchedulerBootstrapExceptionWitness
      }
  , managedNodeAuthority : ManagedCapacityNodeAdmissionProjection
  , witness             : PodIdentityAdmissionWitness
  }

ExecutionSourceGeneration =
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest -- prior or desired source generation
  }

SchedulerControllerChildDiscriminator =
  < DeploymentReplicaClass
  | StatefulOrdinal :
      { ordinal : Natural, slot : PlannedExecutionSlotId }
  | DaemonTarget : ProvisionedNodeTarget
  | JobAttemptClass :
      { completionIndex : Optional Natural
      , slotClass       : PlannedExecutionSlotId
      }
  >

SchedulerReservationTemplateKey =
  (ExecutionSourceGeneration, ExecutionUnitId, ExecutionRevisionId,
   SchedulerControllerChildDiscriminator)

SchedulerReservationTemplate =
  { key               : SchedulerReservationTemplateKey
  , namespace         : NamespaceId
  , controllerKind    : < Deployment | StatefulSet | DaemonSet | Job >
  , podTemplateDigest : KubernetesPodTemplateDigest
  , candidates        : NonEmptyMap ProvisionedNodeTarget CompleteResourceReservationTemplate
  , placementModel    : PlacementCostModelVersion
  , runtimeModels     : RuntimeStorageModelFingerprintSet
  , acceleratorModel  : Optional AcceleratorAllocationModelFingerprint
  , digest            : SchedulerReservationTemplateDigest
  , sourceEquality    : SchedulerTemplateSourceAndAxisEqualityWitness
  }

SchedulerTemplateSet =
  { digest            : SchedulerTemplateSetDigest
  , sourceGenerations : NonEmptySet ExecutionSourceGeneration
  , templates         : NonEmptyMap SchedulerReservationTemplateKey SchedulerReservationTemplate
  , sourceDomain      : NonEmptySet
      (ExecutionSourceGeneration, ExecutionUnitId, ExecutionRevisionId)
  , keyDigestEquality : SchedulerTemplateSetKeyDigestEqualityWitness
  , domainEquality    : SchedulerTemplateSetSourceDomainEqualityWitness
  }

ProvisionedSchedulerGuardConfig =
  { configGeneration  : SchedulerConfigGenerationDigest
  , acceptedTemplateSets : NonEmptyMap SchedulerTemplateSetDigest SchedulerTemplateSet
  , sourceGenerations : NonEmptySet ExecutionSourceGeneration
  , templates         : NonEmptyMap SchedulerReservationTemplateKey SchedulerReservationTemplate
  , configDigest      : CanonicalContentDigest
  , podDomain         : NonEmptySet ExecutionUnitId
  , sourceDomain      : NonEmptySet
      (ExecutionSourceGeneration, ExecutionUnitId, ExecutionRevisionId)
  , canonicalObject   : KubernetesApiObjectSource
  , contentDigest     : CanonicalContentDigest
  , domainEquality    : SchedulerTemplatePodDomainEqualityWitness
  , acceptedSetEquality :
      PriorAndDesiredTemplateSetSourceRecordDomainEqualityWitness
  , canonicalBytes    : CanonicalSchedulerGuardConfigSerializerWitness
  , reload            : AtomicGenerationSwapAfterFullValidation
  , readinessRequirement : ExpectedActiveConfigGenerationAndDigest
  }

ManagedCapacityNodeAdmissionProjection =
  { targets           : NonEmptySet ProvisionedNodeTarget
  , exclusiveTaint    : ManagedCapacityTaint
  , customScheduler   : AmoebiusCapacityScheduler
  , tolerationRule    : RequireCustomSchedulerForManagedCapacityToleration
  , defaultSchedulerWriters :
      < SoleBootstrap :
          { unit        : ExecutionUnitId
          , pinnedNode  : NodeId
          , oneAtATime  : ExactPodsOneQuotaEnforcedRecreate
          , staticDebit : CompleteResourceReservation ExecutionUnitId
          , staticAndLedgerMerge : IdentityAwareStaticBaselineMergeWitness
          }
      >
  , foreignWriterDomain : EmptySetWitness
  , objects          :
      { nodeTaints       : NonEmptyMap ProvisionedNodeTarget KubernetesNodeTaintProjection
      , admissionPolicy  : KubernetesApiObjectSource
      , schedulerRbac    : NonEmptyMap KubernetesObjectId KubernetesApiObjectSource
      , bootstrapQuota   : KubernetesApiObjectSource
      }
  , authorityEquality   : ManagedNodePlacementAuthorityWitness
  }

ManagedCapacityTaint = -- checked refinement of substrate-owned NodeTaint
  { kind          : NodeTaintKind
  , kindEquality  : kind == ManagedCapacity
  , key           : KubernetesTaintKey
  , value         : KubernetesTaintValue
  , effect        : NoSchedule
  , exactMapping  :
      (key, value, effect) == ("amoebius.dev/managed-capacity", "reserved", NoSchedule)
  }

KubernetesNodeTaintProjection =
  { target        : ProvisionedNodeTarget
  , taint         : ManagedCapacityTaint
  , toleration    : DerivedManagedCapacityToleration
  , schedulerRule : TolerationImpliesAmoebiusCapacityScheduler
  , sourceEquality: ManagedCapacityTaintProjectionWitness
  }

ObservedManagedCapacityTaint =
  { node          : NodeId
  , taint         : NodeTaint
  , kindEquality  : taint.kind == ManagedCapacity
  , exactEquality : ObservedManagedCapacityKeyValueEffectEqualityWitness
  , resourceVersion : ResourceVersion
  }

ObservedManagedCapacityNodeAuthority =
  { targetBindings     : NonEmptyMap ProvisionedNodeTarget ObservedNodeTargetBinding
  , taints             : NonEmptyMap NodeId ObservedManagedCapacityTaint
  , admissionConfig    : ObservedAdmissionConfiguration
  , bindingWriterRbac  : ObservedExclusiveBindingWriterRbac
  , bootstrapQuota     : ObservedExactPodsOneResourceQuota
  , authorizedWriters  : ObservedManagedNodeWriterDomain
  , sourceEquality     : ManagedNodePlacementAuthorityReadbackWitness
  , fingerprint        : InventoryFingerprint
  }

ExecutionSchedulerReservationProjection =
  { schedulerName : AmoebiusCapacityScheduler
  , rootIdentity  : SchedulerLedgerRootId
  , guardConfig   : ProvisionedSchedulerGuardConfig
  , axisSchema    : LivePodResourceReservationSchema -- every placed compute/storage/slot/device axis
  , reserve       : WholeRootCompareAndSwapToReserved
  , beginBinding  : WholeRootCompareAndSwapReservedToBindingInFlight
  , bind          : KubernetesBindingApi
  , bindingOutcome:
      < ConfirmedBound : RepairBindingInFlightToBoundByCas
      | ConfirmedUnboundSameUidAndResourceVersion : ReleaseByCas
      | PodAbsent : ReleaseByCas
      | Unknown : KeepChargedAndReobserve
      >
  , recovery      :
      { identicalUidRetry : ReuseExactReservationWithoutDebit
      , retargetUnbound   : WholeRootCasMoveReservedOnly
      , crashAfterBind    : ObserveExactUidNodeThenCasBindingInFlightToBound
      , lostResponse      : NeverReleaseUntilConfirmedUnboundOrAbsent
      , mismatch          : RejectGenerationTemplateChildNodeAxesOrModelMismatch
      }
  , releaseBound  :
      < Ordinary :
          RequireObservedPodAbsentAndResidentPartition
      | Cuda :
          { deviceRelease : ProvisionedCudaReleasePolicy
          , partition     : RequireObservedResidentResourcePartition
          }
      | JobTerminal :
          TerminalSchedulerReleasePolicy
      >
  }

ProvisionedHostProcessReservationGuard =
  { ledger       : HostReservationLedgerDemand
  , keyPrefix    : (DeploymentId, ProvisionGenerationDigest)
  , axisSchema   : CompleteHostResourceReservationSchema HostReservationId
  , reserveStart : WholeHostLedgerCasToReserved
  , beginLaunch  : WholeHostLedgerCasReservedToLaunchInFlight
  , recovery     :
      { sameReservationRetry : Idempotent
      , observedProcess      : CasLaunchInFlightToRunning
      , unknownLaunchOutcome : KeepChargedAndReobserve
      , confirmedNoProcess   : ReleaseOrRetryByCas
      }
  , release      :
      < Ordinary :
          RequireObservedProcessExitAndResidentPartition
      | Cuda :
          { deviceRelease : ProvisionedCudaReleasePolicy
          , retained      : RequireObservedHostResidentResourcePartition }
      | Metal :
          { drainRelease : ProvisionedMetalReleasePolicy
          , retained     : RequireObservedHostResidentResourcePartition }
      >
  }

ProvisionedHostReservationLedgerBacking =
  < KubernetesApi :
      { object         : KubernetesApiObjectSource
      , etcd           : ProvisionedEtcdLogicalDemand
      }
  | HostAtomicFile :
      { host           : HostId
      , backing        : HostStorageBackingId
      , canonicalBytes : Quantity Bytes
      , atomicReplacePeak : Quantity Bytes
      , fsyncModel     : HostAtomicLedgerPersistenceModelVersion
      , capacity       : HostLedgerFileBackingCapacityWitness
      }
  >

HostReservationLedgerDemand =
  { identity      : HostReservationLedgerId
  , maxEntries    : DerivedMaximumHostReservationPopulation
  , maxRetainedArtifacts : DerivedMaximumHostRetainedArtifactPopulation
  , artifactRetention : FiniteDuration
  , maxBytes      : DerivedCanonicalHostLedgerByteBound
  , churn         : DerivedHostReservationCasChurn
  , cleanupChurn  : DerivedHostArtifactCleanupChurn
  , apiOrFileBacking : ProvisionedHostReservationLedgerBacking
  , soleWriter    : HostSupervisorReservationWriterWitness
  , capacity      : HostReservationLedgerCapacityWitness
  }

CapacitySchedulerSystemDemand =
  { execution : BootstrapScheduledExecution
  , implementation : InClusterRole  -- pinned to the CapacityScheduler arm at decode
  , bootstrapApiObjects :
      NonEmptyMap KubernetesObjectId KubernetesApiObjectSource
  , ledger    : SchedulerReservationLedgerDemand
  , managedNodeAuthority : ManagedCapacityNodeAdmissionProjection
  , stageDomain : SchedulerBootstrapManagedObjectStageSourceWitness
  , witness   : SchedulerSystemSourceEqualityWitness
  }

BootstrapScheduledExecution =
  { unit           : BootstrapSchedulerPodUnit
  , schedulerName  : DefaultScheduler
  , pinnedNode     : NodeId
  , staticDebit    : CompleteResourceReservation ExecutionUnitId
  , oneAtATime     : ExactPodsOneQuotaEnforcedRecreate
  , cycleBreak     : BootstrapSchedulerCycleBreakWitness
  , normalDomainDisjoint : SchedulerBootstrapDomainDisjointnessWitness
  , executionDebit : ExactlyOnce
  }

BootstrapSchedulerPodUnit = -- opaque refinement
  { unit       : BoundExecutionUnit
  , body       : Pod Ordinary Deployment
  , accelerator: None
  , resourceEquality : CompleteSchedulerPodEnvelopeWitness
  }

KubernetesDeploymentProjection =
  { object         : KubernetesApiObjectSource
  , replicas       : PositiveNatural
  , template       : KubernetesPodTemplateDigest
  , ownedFields    : NonEmptySet KubernetesFieldPath
  , sourceEquality : DeploymentObjectReplicaTemplateFieldEqualityWitness
  }

FixedNodeUniqueEligibilityProjection =
  { node            : NodeId
  , affinity        : DerivedNodeAffinityProjection
  , exactlyOneMatch : FixedNodeUniqueEligibilityWitness
  }

ExactPodsOneResourceQuotaProjection =
  { namespace       : NamespaceId
  , hardPods        : One
  , object          : KubernetesApiObjectSource
  , sourceEquality  : ExactPodsOneQuotaNamespaceObjectEqualityWitness
  }

SoleBootstrapControllerWriterProjection =
  { serviceAccount  : ServiceAccountId
  , controller      : KubernetesObjectId
  , mutableFields   : NonEmptySet KubernetesFieldPath
  , soleWriter      : Required
  , sourceEquality  : BootstrapControllerWriterScopeEqualityWitness
  }

BootstrapAddonControllerPatchOnlyCapabilityProjection =
  { controllers     : NonEmptySet KubernetesObjectId
  , verbs           : Set < Get | List | Watch | Patch >
  , createDelete    : Forbidden
  , fieldScope      : NonEmptySet KubernetesFieldPath
  , sourceEquality  : BootstrapAddonPatchCapabilityScopeEqualityWitness
  }

BootstrapAddonBindingOnlyRbacProjection =
  { serviceAccount : ServiceAccountId
  , podRead        : Set < Get | List | Watch >
  , bindingCreate  : Allowed
  , podCreatePatchDelete : Forbidden
  , sourceEquality : BootstrapBindingOnlyRbacEqualityWitness
  }

SchedulerExclusiveRbacProjection =
  { serviceAccount : ServiceAccountId
  , podRead        : Set < Get | List | Watch >
  , bindingCreate  : Allowed
  , ledgerCas      : Allowed
  , otherWriters   : Forbidden
  , sourceEquality : SchedulerExclusiveRbacEqualityWitness
  }

ProvisionedBootstrapSchedulerController =
  { deployment      : KubernetesDeploymentProjection
  , template        : ProvisionedPodControllerTemplateIdentity
  , schedulerName   : DefaultScheduler
  , nodeName        : MustBeAbsent
  , uniqueNodeAffinity : FixedNodeUniqueEligibilityProjection
  , rollout         : Recreate
  , namespaceQuota  : ExactPodsOneResourceQuotaProjection
  , writerScope     : SoleBootstrapControllerWriterProjection
  , staticReservation : CompleteResourceReservation ExecutionUnitId
  , sourceEquality  : BootstrapSchedulerControllerProjectionWitness
  }

BootstrapAddonSchedulerCutoverProjection =
  { addons          : NonEmptyMap ExecutionUnitId
      { priorController : KubernetesControllerUid
      , priorPods       : NonEmptyMap PodUid
          (CompleteResourceReservation PodUid)
      , desiredController : ProvisionedPodController
      , desiredTemplates  : NonEmptyMap
          SchedulerReservationTemplateKey SchedulerReservationTemplate
      }
  , overlap         : ReservationSetFold
  , staticPriorJoin : BootstrapAddonStaticReservationEqualityWitness
  , desiredLedgerJoin : BootstrapAddonDesiredReservationEqualityWitness
  , authority       : BootstrapAddonControllerPatchOnlyCapabilityProjection
  , completion      :
      RequirePriorUidsAbsentAndDesiredUidsBoundReservationJoined
  }

ProvisionedCapacitySchedulerSystem = -- private whole-deployment ProvisionedSpec member
  { implementation  : InClusterRole  -- pinned to the CapacityScheduler arm at decode
  , controller      : ProvisionedBootstrapSchedulerController
  , image           : ProvisionedImageArtifact
  , guardConfig     : ProvisionedSchedulerGuardConfig
  , addonCutover    : BootstrapAddonSchedulerCutoverProjection
  , managedAuthority: ManagedCapacityNodeAdmissionProjection
  , ledgerRoot      :
      { demand : SchedulerReservationLedgerDemand
      , schema : SchedulerLedgerRootSchema
      , apiObject : KubernetesApiObjectSource
      }
  , objectsByStage  :
      { bootstrap :
          NonEmptyMap KubernetesObjectId KubernetesApiObjectSource
      , managedAuthority :
          NonEmptyMap KubernetesObjectId KubernetesApiObjectSource
      , disjointOrEqualImmutable :
          SchedulerBootstrapManagedObjectStagePartitionWitness
      }
  , bootstrapRbac   : BootstrapAddonBindingOnlyRbacProjection
  , managedRbac     : SchedulerExclusiveRbacProjection
  , capacity        : SchedulerSystemCapacityWitness
  , objectDomain    : SchedulerGlobalObjectDomainWitness
  , renderOwner     : UniqueWholeDeploymentGlobalRenderOwnerWitness
  , sourceEquality  : SchedulerSystemSourceEqualityWitness
  }

BootstrapCapacitySchedulerReady =
  { deploymentUid    : KubernetesControllerUid
  , podUid           : PodUid
  , podResourceVersion : ResourceVersion
  , configObject     : KubernetesObjectId
  , configResourceVersion : ResourceVersion
  , activeConfigGeneration : SchedulerConfigGenerationDigest
  , activeContentDigest : CanonicalContentDigest
  , ledgerRootResourceVersion : ResourceVersion
  , readyCondition    : KubernetesReadyConditionWitness
  , actionAuthority   : BootstrapAddonControllerPatchOnlyCapability
  , noManagedTaintAuthority : ManagedCapacityAuthorityNotYetInstalledWitness
  , expectedEquality  : BootstrapCapacitySchedulerExpectedGenerationDigestWitness
  , fingerprint       : InventoryFingerprint
  }

ObservedBootstrapAddonSchedulerCutover =
  { priorPodAbsence   : NonEmptyMap PodUid ObservedPodUidAbsentWitness
  , desiredPods       : NonEmptyMap PodUid (ObservedKubernetesPodExecution Bound)
  , reservations      : NonEmptyMap PodUid BoundSchedulerReservationRef
  , desiredJoin       : BootstrapAddonPodReservationEqualityWitness
  , overlapAccounted  : BootstrapAddonTransitionFoldEqualityWitness
  , fingerprint       : InventoryFingerprint
  }

ManagedCapacityReady =
  { scheduler         : BootstrapCapacitySchedulerReady
  , addonCutover      : ObservedBootstrapAddonSchedulerCutover
  , managedAuthority  : ObservedManagedCapacityNodeAuthority
  , admissionInstalledAfterCutover :
      ManagedAuthorityInstallOrderingWitness
  , generalControllerAuthority :
      ManagedCapacityGeneralControllerMutationCapability
  , fingerprint       : InventoryFingerprint
  }

ObservedCapacitySchedulerReady = ManagedCapacityReady

SchedulerReservationLedgerDemand =
  { rootIdentity  : SchedulerLedgerRootId
  , model         : SchedulerLedgerModelVersion
  , entrySchema   : SchedulerReservationRecordSchema
  , maxEntries    : DerivedMaximumNormalizedPodUidPopulation
  , maxRootBytes  : DerivedCanonicalLedgerRootByteBound
  , casChurn      : DerivedSchedulerCasChurn
  , cleanup       : SchedulerLedgerCleanupPolicy
  , apiObjectJoin : KubernetesApiObjectSourceEqualityWitness
  , soleWriter    : SchedulerServiceAccountFieldOwnershipWitness
  } -- canonical API serializer/etcd model derives bytes; no caller scalar

SchedulerLedgerCleanupPolicy =
  { reserved :
      RequireSameUidAndResourceVersionConfirmedUnboundOrPodAbsent
  , bindingInFlight :
      < ConfirmedBound : RepairToBoundBeforeAnyRelease
      | ConfirmedUnboundSameUidAndResourceVersion : ReleaseByWholeRootCas
      | PodAbsent : ReleaseByWholeRootCas
      | Unknown : KeepFullDebitAndReobserve
      >
  , boundOrTerminating :
      RequireResourceIndexedReleasePartitionAndResidentRootTransfer
  , terminalRetained :
      RequirePersistedCompletionFreshDeadlineObservedSlotAndArtifactCleanup
  , stateDomainEquality : SchedulerLedgerCleanupStateCompletenessWitness
  }

SchedulerReservationRecordSchema =
  { fields :
      { podUid     : Required
      , deployment : Required
      , generation : Required
      , sourceUnit : Required
      , revision   : Required
      , templateSet : Required
      , child       : Required
      , childTemplate : Required
      , axes       : Required
      , state      : Required
      }
  , states : < Reserved | BindingInFlight | Bound | Terminating | TerminalRetained >
  , axesByState :
      { active   : CompleteResourceReservation PodUid
      , terminal : RetainedResourceReservation PodUid
      }
  , serializer : CanonicalKubernetesApiSerializerModel
  }

SchedulerLedgerRootSchema =
  { identity       : SchedulerLedgerRootId
  , entries        : Map PodUid SomeSchedulerReservationRecord
  , retainedDebits : ResidentResourceDebitSet
  , residentFingerprint : InventoryFingerprint
  , foldDigest     : ReservationSetFoldDigest
  , casVersion     : SchedulerLedgerCasVersion
  , serializer     : CanonicalKubernetesApiSerializerModel
  } -- one API object/resourceVersion is the serialization boundary for all candidate CAS operations

SchedulerReservationRecord state =
  { podUid      : PodUid
  , deployment  : DeploymentId
  , generation  : ProvisionGenerationDigest
  , sourceUnit  : ExecutionUnitId
  , revision    : ExecutionRevisionId
  , templateSet : SchedulerTemplateSetDigest
  , child       : SchedulerControllerChildDiscriminator
  , childTemplate : SchedulerReservationTemplateDigest
  , axes        : SchedulerReservationAxes state
  , state       : state
  }

SomeSchedulerReservationRecord =
  < Reserved         : SchedulerReservationRecord Reserved
  | BindingInFlight  : SchedulerReservationRecord BindingInFlight
  | Bound            : SchedulerReservationRecord Bound
  | Terminating      : SchedulerReservationRecord Terminating
  | TerminalRetained : SchedulerReservationRecord TerminalRetained
  >
```

## 22. Controller children, builds, and the bootstrap toolchain

```text
MaterializedControllerChild =
  { id        : ControllerChildId
  , execution : BoundExecutionUnit -- Pod arm; lowered through the generic epoch mechanism
  }

ControllerChildEnvelope = -- private binder result, never an authored scalar/list
  { owner             : ControllerResourceId
  , model             : ControllerChildExpansionModelVersion
  , sourceFingerprint : ControllerSourceFingerprint
  , steadyChildren    : NonEmpty MaterializedControllerChild
  }

ProvisionedControllerChildren = -- private provision result
  { envelope           : ControllerChildEnvelope
  , executionEpochs    : ProvisionedExecutionEpochs
  , admissionExecution : ExecutionUnitId
  , witness            : ControllerChildProvisionWitness
  }

BuildStageDemand =
  { id                    : BuildStageId
  , platform              : OsArch
  , dependsOn             : List BuildStageId
  , runtime               : HostResources
  , peakIntermediateBytes : Quantity Bytes
  , peakCacheWriteBytes   : Quantity Bytes
  }

BuildExecutionEnvelope =
  { id               : BuildExecutionId
  , stages           : NonEmpty BuildStageDemand
  , scratchBacking   : HostStorageBackingId
  , cache            : HostCacheDemand
  , cacheEquality    : cache.source == ImageBuild id
  , archConcurrency  : < Serial | BoundedParallel : PositiveNatural >
  , stageConcurrency : < Serial | BoundedParallel : PositiveNatural >
  }

BuildExecutionId =
  { sourceDigest : ContentAddress
  , output       : ImageDigest
  }

ToolInstallDemand =
  { tool                : ToolId
  , backing             : HostStorageBackingId
  , installedBytes      : Quantity Bytes
  , peakDownloadUnpackBytes : Quantity Bytes
  }

BootstrapExecutionEnvelope =
  { runtime  : HostResources
  , installs : NonEmpty ToolInstallDemand
  , build    : BuildExecutionEnvelope
  }

EngineProcessEnvelope =
  { id : EngineProcessId, runtime : HostResources }

EngineNodeRole =
  < KindControlPlane | KindWorker | Rke2Server | Rke2Agent >
```

## 23. Kubernetes API objects and the mandatory reconciler Lease

```text
KubernetesApiObjectDemand =
  { identity        : KubernetesObjectId
  , serializedBytes : Quantity Bytes
  }

KubernetesApiObjectSource =
  { demand          : KubernetesApiObjectDemand
  , owner           : ResourceOwnerId
  , deployment      : DeploymentId
  , generation      : ProvisionGenerationDigest
  , serializerModel : CanonicalKubernetesApiSerializerModel
  , sourceEquality  : KubernetesApiObjectIdentityByteModelSourceEqualityWitness
  }
-- identity and serialized byte demand are projected from one canonical object source; neither is authored
-- independently by retention, scheduler, quota, Lease, or bootstrap consumers.

MandatoryReconcilerLeaseDemand =
  { identity       : KubernetesObjectId
  , namespace      : NamespaceId
  , leaseDuration  : FiniteDuration
  , renewDeadline  : FiniteDuration
  , retryPeriod    : FiniteDuration
  , maxRenewalsPerWindow : PositiveNatural
  , renewalWindow  : FiniteDuration
  , timing         :
      ReconcilerLeaseTimingRefinement retryPeriod renewDeadline leaseDuration
        maxRenewalsPerWindow renewalWindow
  , apiObject      : KubernetesApiObjectDemand
  , maximumMutationBytes : Quantity Bytes
  , mutationByteModel    : CanonicalKubernetesLeaseMutationSerializerModel
  , sourceEquality : ReconcilerLeaseSourceWitness
  }
-- maximumMutationBytes is derived from the finite provisioned bootstrap/control-plane daemon holder identities and every
-- reachable acquire/renew/release/handoff payload under mutationByteModel; it is not an independently authored
-- estimate. apiObject.serializedBytes remains the exact initial object source.

ReconcilerLeaseTimingRefinement retryPeriod renewDeadline leaseDuration
  maxRenewalsPerWindow renewalWindow =
  { retryBeforeRenewDeadline : retryPeriod < renewDeadline
  , renewBeforeLeaseExpiry   : renewDeadline < leaseDuration
  , renewalBoundary          :
      LeftClosedRightOpenWindowWithAttemptAtWindowStart
  , requiredRenewalsPerWindow:
      CeilPositiveDurationRatio renewalWindow retryPeriod
  , renewalBudgetSufficient  :
      CeilPositiveDurationRatio renewalWindow retryPeriod
        <= maxRenewalsPerWindow
  }
-- A renewal window is [windowStart, windowStart + renewalWindow). An attempt at windowStart counts; an
-- attempt exactly at the right boundary belongs to the next window. Therefore attempts at
-- windowStart + k*retryPeriod have cardinality ceil(renewalWindow/retryPeriod), including when the ratio is
-- integral. The old product inequality rounded in the wrong direction and could under-budget a partial period.

ReconcilerExecutionUnitId = -- opaque refinement of the control-plane daemon execution identity
  { unit          : ExecutionUnitId
  , body          : Pod Ordinary Deployment
  , cardinality   : Once
  , rollout       : Recreate
  , sourceEquality: ReconcilerExecutionUnitSourceWitness
  }

KubernetesLeaseHolderIdentity =
  { lease  : KubernetesObjectId
  , holder : ContentAddress
  }

ReconcilerMutationAction =
  < BootstrapRegistryMutation
  | BootstrapSchedulerMutation
  | LeaseAcquireRenewReleaseHandoff
  | DeclarativeApply
  | SchedulerLedgerCas
  | ExecutionTransition
  | TenantProviderMutation
  | StorageWriteAction   -- a reconciler write class; NOT the migration verb union of the same former name,
  >                      -- which is owned by inforcespec_migration_doctrine.md §3

BootstrapMutationActionSubset =
  { actions     : Set ReconcilerMutationAction
  , exactDomain : BootstrapMutationActionClosedSubsetWitness
  }

InClusterReconcilerMutationActionSet =
  { actions     : NonEmptySet ReconcilerMutationAction
  , exactDomain : InClusterMutationActionClosedDomainWitness
  }

StageScopedLeaseExclusiveWriterProjection =
  { lease           : KubernetesObjectId
  , bootstrapHolder : KubernetesLeaseHolderIdentity
  , controlPlaneHolder : KubernetesLeaseHolderIdentity
  , bootstrapActions: BootstrapMutationActionSubset
  , controlPlaneActions: InClusterReconcilerMutationActionSet
  , overlap         : Forbidden
  , sourceEquality  : LeaseHolderStageActionRbacEqualityWitness
  }

BootstrapHostReconcilerLeaseHolder =
  { host           : HostId
  , process        : HostProcessInstanceId
  , holderIdentity : KubernetesLeaseHolderIdentity
  , stage          : HostPrecursorBootstrap
  , sourceEquality : BootstrapLeaseHolderSourceWitness
  }

ParentClusterReconcilerLeaseHolder =
  { parentDeployment : DeploymentId
  , parentExecution  : ReconcilerExecutionUnitId
  , childCluster     : ClusterId
  , holderIdentity   : KubernetesLeaseHolderIdentity
  , stage            : ParentClusterChildBootstrap
  , sourceEquality   : ParentClusterBootstrapLeaseHolderSourceWitness
  }

BootstrapReconcilerLeaseHolder =
  < Host          : BootstrapHostReconcilerLeaseHolder
  | ParentCluster : ParentClusterReconcilerLeaseHolder
  >

InClusterReconcilerLeaseHolder =
  { execution      : ReconcilerExecutionUnitId
  , holderIdentity : KubernetesLeaseHolderIdentity
  , stage          : InClusterControlPlane
  , sourceEquality : ControlPlaneDaemonLeaseHolderSourceWitness
  }

ReconcilerLeaseHolder =
  < BootstrapAuthority : BootstrapReconcilerLeaseHolder
  | InClusterControlPlane : InClusterReconcilerLeaseHolder
  >

ReconcilerLeaseHandoffPolicy =
  { order :
      BootstrapAcquireThenReleaseThenObserveSameLeaseUnheldThenControlPlaneDaemonAcquire
  , sameLeaseIdentity : Required
  , overlap           : Forbidden
  , bootstrapAuthority: BootstrapMutationActionSubset
  , controlPlaneAuthority: InClusterReconcilerMutationActionSet
  , churn             : LeaseAcquireRenewReleaseHandoffChurnWitness
  }

ReconcilerLeaseAuthorityStage =
  < BootstrapAuthorityStage | ControlPlaneAuthorityStage >

ReconcilerLeaseReleasePurpose =
  < BootstrapForHandoff | ControlPlaneForReplacement >

LeaseReleaseSourceState BootstrapForHandoff     = BootstrapHeld
LeaseReleaseSourceState ControlPlaneForReplacement = ControlPlaneHeld

MandatoryReconcilerLeaseState =
  < Absent
  | Expired      : ReconcilerLeaseAuthorityStage
  | BootstrapHeld
  | Released     : ReconcilerLeaseReleasePurpose
  | ControlPlaneHeld
  >

LeaseHolderAbsent =
  { holderIdentity : None
  , sourceEquality : ReleasedLeaseHolderFieldAbsenceWitness
  }

ReconcilerLeaseTarget BootstrapHeld =
  < BootstrapHolder : BootstrapReconcilerLeaseHolder >
ReconcilerLeaseTarget ControlPlaneHeld =
  < ControlPlaneHolder : InClusterReconcilerLeaseHolder >
ReconcilerLeaseTarget (Released purpose) =
  < HolderAbsent : LeaseHolderAbsent >

ReconcilerLeaseMutationKind =
  < Acquire | Renew | Release | HandoffAcquire >

LeaseEtcdChurnDebitState = < Reserved | Committed | ReleasedUnused >

ReconcilerLeaseEtcdChurnDebit debitState kind =
  { kind                    : kind
  , apiObject               : KubernetesApiObjectDemand
  , payload                 : CanonicalKubernetesLeaseMutationPayload kind
  , payloadDigest           : ContentAddress
  , updateSlots             : ExactlyOneEtcdUpdate
  , revisionSlots           : ExactlyOneRetainedEtcdRevision
  , serializedRevisionBytes : Quantity Bytes
  , provisionedMaximumMutationBytes : Quantity Bytes
  , serialization           :
      CanonicalLeasePayloadSerializerAndExactByteCountWitness
  , withinProvisionedMaximum:
      serializedRevisionBytes <= provisionedMaximumMutationBytes
  , debitState              : debitState
  , budgetWindow            : FiniteDuration
  , budget                  : EtcdChurnBudget
  , exactProjection         :
      OneLeaseMutationToEtcdUpdatesRevisionRetentionAndLeaseBytesProjectionWitness
  , sourceEquality          :
      LeaseMutationApiObjectPayloadByteMaximumKindBudgetWindowAndDebitEqualityWitness
  }

ProvisionedReconcilerLeaseEtcdChurnProjection demand etcd =
  { demand                    : demand
  , etcd                      : etcd
  , budget                    : EtcdChurnBudget
  , activeLeaseObjects        : ExactlyOne
  , maximumLeaseBytes         : demand.maximumMutationBytes
  , renewalWritesPerWindow    :
      CeilPositiveDurationRatio demand.renewalWindow demand.retryPeriod
  , reachableActionSchedule   : ReconcilerLeaseReachableActionSchedule
  , derivedPeakWritesPerWindow: PositiveNatural
  , debitFor                  : forall kind.
      CanonicalKubernetesLeaseMutationPayload kind
        -> Either ProvisionError
             (ReconcilerLeaseEtcdChurnDebit Reserved kind)
  , renewalFit                :
      renewalWritesPerWindow <= demand.maxRenewalsPerWindow
  , windowNormalization       :
      LeaseRenewalAndTransitionScheduleNormalizedToBudgetUpdateWindowWitness
  , aggregateBudgetFit        :
      LeaseObjectRevisionAndReachableActionScheduleFitsEtcdChurnBudgetWitness
  , actionDomainEquality      :
      ReachableLeaseActionKindsEqualExactDebitProjectionDomainWitness
  , sourceEquality            :
      LeaseDemandTimingApiObjectReachableScheduleEtcdBudgetAndPeakEqualityWitness
  }
-- Each attempted Lease write reserves exactly one update/revision debit before transport. Success commits
-- that debit. A conflict, timeout, cancelled request, or lost response retains it until a fresh observation
-- proves that this action did not advance the object; it is never optimistically refunded. The reachable
-- acquire/renew/release/handoff schedule and every other etcd producer form a disjoint exact partition of the
-- aggregate EtcdChurnBudget, so Lease activity cannot borrow an unrepresented update or revision.

ProvisionedMandatoryReconcilerLease = -- private whole-deployment render member
  { demand         : MandatoryReconcilerLeaseDemand
  , etcd           : ProvisionedEtcdLogicalDemand
  , bootstrapHolder: BootstrapReconcilerLeaseHolder
  , controlPlaneHolder: InClusterReconcilerLeaseHolder
  , handoff        : ReconcilerLeaseHandoffPolicy
  , rbac           : StageScopedLeaseExclusiveWriterProjection
  , churnProjection:
      ProvisionedReconcilerLeaseEtcdChurnProjection demand etcd
  , capacity       : ReconcilerLeaseCapacityWitness
  , globalOwner    : UniqueWholeDeploymentGlobalRenderOwnerWitness
  , sourceEquality :
      MandatoryLeaseDemandEtcdHolderHandoffRbacChurnCapacityGlobalOwnerEqualityWitness
  }

KubernetesObjectUid = ContentAddress

ObservedKubernetesLease =
  { identity        : KubernetesObjectId
  , namespace       : NamespaceId
  , objectUid       : KubernetesObjectUid
  , holder          : Optional ReconcilerLeaseHolder
  , resourceVersion : ResourceVersion
  , acquireTime     : Optional ObservationTimestamp
  , renewTime       : Optional ObservationTimestamp
  , leaseDuration   : FiniteDuration
  , observedAt      : ObservationTimestamp
  , expiresAt       : Optional FiniteDeadline
  , stillPresent    : ObservedKubernetesObjectPresentWitness
  , timingEquality  :
      ObservedLeaseRenewalExpiryFreshnessDerivationWitness
  , fingerprint     : InventoryFingerprint
  }

ObservedKubernetesLeaseAbsent =
  { identity          : KubernetesObjectId
  , namespace         : NamespaceId
  , observedAt        : ObservationTimestamp
  , collectionVersion : ResourceVersion
  , absent             : ObservedKubernetesObjectAbsentAtCollectionVersionWitness
  , fingerprint        : InventoryFingerprint
  , sourceEquality     : LeaseIdentityNamespaceAbsenceVersionSnapshotEqualityWitness
  }

AbsentReconcilerLeaseCreatePrecondition =
  { observed       : ObservedKubernetesLeaseAbsent
  , createOnly     : KubernetesCreateMustNotAlreadyExist
  , sourceEquality : AbsentLeaseCreatePreconditionEqualityWitness
  }

PresentReconcilerLeaseCasPrecondition state =
  { objectUid       : KubernetesObjectUid
  , expectedVersion : ResourceVersion
  , observed        : ObservedMandatoryReconcilerLeaseState state
  , sourceEquality  : PresentLeaseUidResourceVersionSnapshotEqualityWitness
  }

ReconcilerLeaseCasPrecondition Absent = AbsentReconcilerLeaseCreatePrecondition
ReconcilerLeaseCasPrecondition (Expired stage) =
  PresentReconcilerLeaseCasPrecondition (Expired stage)
ReconcilerLeaseCasPrecondition BootstrapHeld =
  PresentReconcilerLeaseCasPrecondition BootstrapHeld
ReconcilerLeaseCasPrecondition (Released purpose) =
  PresentReconcilerLeaseCasPrecondition (Released purpose)
ReconcilerLeaseCasPrecondition ControlPlaneHeld =
  PresentReconcilerLeaseCasPrecondition ControlPlaneHeld
-- Every transition from a present state carries the exact observed object UID and resourceVersion and is sent
-- as a compare-and-swap update. Kubernetes cannot supply a
-- ResourceVersion for an absent object, so initial acquisition uses create-if-absent rather than a fictional
-- version. Delete/recreate, stale-version, or same-name/different-UID observations cannot continue.

ObservedBootstrapHeldReconcilerLease =
  { lease           : ObservedKubernetesLease
  , holderEquality  : ObservedLeaseHolderIdentityEqualityWitness
  , expiry          : FiniteDeadline
  , expiryDerived   : LeaseExpiryDerivedFromAcquireOrRenewTimeAndDurationWitness
  , unexpired       : lease.observedAt < expiry
  , expiryBoundary  : HeldStrictlyBeforeExpiryBoundaryWitness
  , sourceEquality  : BootstrapHolderLeaseUidRvTimingSnapshotEqualityWitness
  }

ObservedExpiredReconcilerLease authorityStage =
  { lease             : ObservedKubernetesLease
  , priorHolder       : ReconcilerLeaseHolder
  , authorityStage    : authorityStage
  , holderEquality    : ObservedExpiredLeasePriorHolderStageEqualityWitness
  , authorityContinuity:
      ExpiredLeaseAuthorityEpochContinuityWitness authorityStage
  , expiry            : FiniteDeadline
  , expiryDerived     : LeaseExpiryDerivedFromAcquireOrRenewTimeAndDurationWitness
  , expired           : lease.observedAt >= expiry
  , expiryBoundary    : ExpiredAtOrAfterExpiryBoundaryWitness
  , sourceEquality    : ExpiredLeaseUidRvHolderTimingSnapshotEqualityWitness
  }

ObservedLeaseReleaseTransitionReceipt purpose =
  { purpose         : purpose
  , lease           : KubernetesObjectId
  , objectUid       : KubernetesObjectUid
  , actionDigest    : ContentAddress
  , requestUid      : KubernetesApiRequestUid
  , preVersion      : ResourceVersion
  , postVersion     : ResourceVersion
  , versionChanged  : postVersion != preVersion
  , casCausality    :
      ApiAuditRequestUidExpectedVersionAndObservedReleaseEqualityWitness
  , consumedToken   :
      SingleUseReconcilerLeaseMutationToken Consumed Release
        (LeaseReleaseSourceState purpose) (Released purpose)
  , committedDebit  : ReconcilerLeaseEtcdChurnDebit Committed Release
  , sourceEquality  :
      LeaseReleasePurposeActionTokenUidVersionDebitEqualityWitness
  }

ObservedReleasedReconcilerLease purpose =
  { releasePurpose    : purpose
  , releaseReceipt    : ObservedLeaseReleaseTransitionReceipt purpose
  , lease             : ObservedKubernetesLease
  , holderAbsent      : ObservedSameLeaseHolderAbsentWitness
  , sameIdentity      : MandatoryReconcilerLeaseIdentityEqualityWitness
  , fingerprint       : InventoryFingerprint
  , sourceEquality    : ReleaseReceiptLeaseUidRvHolderSnapshotEqualityWitness
  }

ObservedControlPlaneDaemonHeldReconcilerLease =
  { lease           : ObservedKubernetesLease
  , bootstrapGone   : ObservedBootstrapHolderAbsentWitness
  , handoff         : ReconcilerLeaseHandoffEqualityWitness
  , expiry          : FiniteDeadline
  , expiryDerived   : LeaseExpiryDerivedFromAcquireOrRenewTimeAndDurationWitness
  , unexpired       : lease.observedAt < expiry
  , expiryBoundary  : HeldStrictlyBeforeExpiryBoundaryWitness
  , sourceEquality  : ControlPlaneHolderLeaseUidRvTimingHandoffSnapshotEqualityWitness
  }

ObservedMandatoryReconcilerLeaseState Absent =
  < AbsentState : ObservedKubernetesLeaseAbsent >
ObservedMandatoryReconcilerLeaseState (Expired BootstrapAuthorityStage) =
  < ExpiredBootstrapState :
      ObservedExpiredReconcilerLease BootstrapAuthorityStage >
ObservedMandatoryReconcilerLeaseState (Expired ControlPlaneAuthorityStage) =
  < ExpiredControlPlaneDaemonState :
      ObservedExpiredReconcilerLease ControlPlaneAuthorityStage >
ObservedMandatoryReconcilerLeaseState BootstrapHeld =
  < BootstrapHeldState : ObservedBootstrapHeldReconcilerLease >
ObservedMandatoryReconcilerLeaseState (Released BootstrapForHandoff) =
  < ReleasedForHandoffState :
      ObservedReleasedReconcilerLease BootstrapForHandoff >
ObservedMandatoryReconcilerLeaseState (Released ControlPlaneForReplacement) =
  < ReleasedForReplacementState :
      ObservedReleasedReconcilerLease ControlPlaneForReplacement >
ObservedMandatoryReconcilerLeaseState ControlPlaneHeld =
  < ControlPlaneHeldState : ObservedControlPlaneDaemonHeldReconcilerLease >

ObservedMandatoryReconcilerLease =
  < Absent                 : ObservedMandatoryReconcilerLeaseState Absent
  | ExpiredBootstrap       :
      ObservedMandatoryReconcilerLeaseState (Expired BootstrapAuthorityStage)
  | ExpiredControlPlaneDaemon       :
      ObservedMandatoryReconcilerLeaseState (Expired ControlPlaneAuthorityStage)
  | BootstrapHeld          : ObservedMandatoryReconcilerLeaseState BootstrapHeld
  | ReleasedForHandoff     :
      ObservedMandatoryReconcilerLeaseState (Released BootstrapForHandoff)
  | ReleasedForReplacement :
      ObservedMandatoryReconcilerLeaseState (Released ControlPlaneForReplacement)
  | ControlPlaneHeld          : ObservedMandatoryReconcilerLeaseState ControlPlaneHeld
  >
-- These private refinements are exhaustive only over recognized mandatory-Lease states. A present object with
-- an unknown/anonymous holder, missing expiry operands, conflicting UID, or invalid timing has no constructor.
-- BootstrapHeld/ControlPlaneHeld end strictly before expiresAt; Expired begins at expiresAt. Released requires a
-- confirmed typed Release result on the same still-present object, not merely holder=None discovered in an
-- unrelated snapshot. No sibling holder, UID, or resourceVersion field can drift from the observed source.

ReconcilerLeaseMutationTokenState = < Fresh | Consumed >
SingleUseReconcilerLeaseMutationToken tokenState kind from to =
  { lease       : KubernetesObjectId
  , kind        : kind
  , from        : from
  , to          : to
  , observation : InventoryFingerprint
  , actionDigest: ContentAddress
  , nonce       : ContentAddress
  , state       : tokenState
  , equality    : LeaseTokenActionStateSnapshotEqualityWitness
  }

PreparedReconcilerLeaseMutation kind from to =
  { kind           : kind
  , fromState      : from
  , toState        : to
  , provisioned    : ProvisionedMandatoryReconcilerLease
  , observed       : ObservedMandatoryReconcilerLeaseState from
  , precondition   : ReconcilerLeaseCasPrecondition from
  , target         : ReconcilerLeaseTarget to
  , debit          : ReconcilerLeaseEtcdChurnDebit Reserved kind
  , immediateRecheck : RequireSameLeaseUidResourceVersionAndInventoryFingerprint
  , singleUse      :
      SingleUseReconcilerLeaseMutationToken Fresh kind from to
  , sourceEquality :
      LeaseProvisionObservedCasTargetDebitTokenWholeActionEqualityWitness
  }

ReconcilerLeaseAction from to =
  < AcquireBootstrapFromAbsent :
      PreparedReconcilerLeaseMutation Acquire Absent BootstrapHeld
  | AcquireBootstrapFromExpired :
      PreparedReconcilerLeaseMutation Acquire
        (Expired BootstrapAuthorityStage) BootstrapHeld
  | RenewBootstrap :
      PreparedReconcilerLeaseMutation Renew BootstrapHeld BootstrapHeld
  | ReleaseBootstrapForHandoff :
      PreparedReconcilerLeaseMutation Release BootstrapHeld
        (Released BootstrapForHandoff)
  | HandoffAcquireControlPlaneDaemon :
      PreparedReconcilerLeaseMutation HandoffAcquire
        (Released BootstrapForHandoff) ControlPlaneHeld
  | AcquireControlPlaneDaemonFromExpired :
      PreparedReconcilerLeaseMutation Acquire
        (Expired ControlPlaneAuthorityStage) ControlPlaneHeld
  | AcquireControlPlaneDaemonAfterRelease :
      PreparedReconcilerLeaseMutation Acquire
        (Released ControlPlaneForReplacement) ControlPlaneHeld
  | RenewControlPlaneDaemon :
      PreparedReconcilerLeaseMutation Renew ControlPlaneHeld ControlPlaneHeld
  | ReleaseControlPlaneDaemonForReplacement :
      PreparedReconcilerLeaseMutation Release ControlPlaneHeld
        (Released ControlPlaneForReplacement)
  >
-- Renew fixes target to the exact observed holder. Bootstrap release fixes it to HolderAbsent. Handoff fixes it
-- to the authenticated control-plane daemon Pod UID and is the only BootstrapForHandoff -> ControlPlaneHeld transition.
-- An expired bootstrap holder cannot be acquired by a control-plane daemon, and bootstrap authority has no constructor
-- from a control-plane-stage state.

ReconcilerLeaseTransportOutcome =
  < Acknowledged | RejectedConflict | TimeoutOrCancelled | LostOrAmbiguousResponse >

KubernetesApiRequestUid = ContentAddress

AttemptedReconcilerLeaseAction from to =
  { action         : ReconcilerLeaseAction from to
  , requestUid     : KubernetesApiRequestUid
  , transportPolicy: ExactlyOneApiMutationRequestWithNoImplicitWriteRetry
  , transport      : ReconcilerLeaseTransportOutcome
  , singleUse      :
      SingleUseReconcilerLeaseMutationToken Consumed action.kind from to
  , consumptionCas : ReconcilerLeaseActionTokenFreshToConsumedCasWitness
  , retainedDebit  :
      ReconcilerLeaseEtcdChurnDebit Reserved action.kind
  , mustReobserve  : Required
  , noAuthorityFromTransportResponse : Required
  , sourceEquality :
      LeaseAttemptActionRequestUidConsumedTokenCasDebitTransportPolicyEqualityWitness
  }

SomeObservedMandatoryReconcilerLeaseState =
  { state    : MandatoryReconcilerLeaseState
  , observed : ObservedMandatoryReconcilerLeaseState state
  }

ObservedReconcilerLeaseActionResult from to =
  < TransitionObserved :
      { attempt        : AttemptedReconcilerLeaseAction from to
      , post           : ObservedMandatoryReconcilerLeaseState to
      , committedDebit :
          ReconcilerLeaseEtcdChurnDebit Committed attempt.action.kind
      , casAdvanced    : ExpectedResourceVersionTransitionOrAbsentCreateWitness
      , causality      :
          ApiAuditRequestUidExpectedCasPayloadDigestAndPostObjectEqualityWitness
      , equality       :
          LeaseActionAttemptPostStateUidRvHolderCommittedDebitSourceEqualityWitness
      }
  | NoTransitionObserved :
      { attempt        : AttemptedReconcilerLeaseAction from to
      , post           : SomeObservedMandatoryReconcilerLeaseState
      , releasedDebit  :
          ReconcilerLeaseEtcdChurnDebit ReleasedUnused attempt.action.kind
      , noMatchingWrite:
          ObservedRevisionAndApiAuditProveRequestUidDidNotCommitWitness
      , noCapability   : Required
      , equality       :
          LeaseActionAttemptObservedNoWriteReleasedDebitSourceEqualityWitness
      }
  | ObservationStillAmbiguous :
      { attempt        : AttemptedReconcilerLeaseAction from to
      , latest         : Optional SomeObservedMandatoryReconcilerLeaseState
      , retainedDebit  :
          ReconcilerLeaseEtcdChurnDebit Reserved attempt.action.kind
      , reobserveAgain : Required
      , noCapability   : Required
      , equality       :
          LeaseActionAttemptAmbiguousObservationRetainedDebitSourceEqualityWitness
      }
  >

prepareReconcilerLeaseAction
  :: ProvisionedMandatoryReconcilerLease
  -> ObservedMandatoryReconcilerLeaseState from
  -> ReconcilerLeaseTransitionRequest from to
  -> Either ProvisionError (ReconcilerLeaseAction from to)

attemptReconcilerLeaseAction
  :: ReconcilerLeaseAction from to
  -> IO (AttemptedReconcilerLeaseAction from to)

observeReconcilerLeaseActionResult
  :: AttemptedReconcilerLeaseAction from to
  -> IO (ObservedReconcilerLeaseActionResult from to)
-- Acknowledgement is not authority. Every attempt CAS-consumes its fresh token and enters the read-only
-- re-observation path. Lost/ambiguous outcomes retain both the one-update etcd debit and zero mutation
-- capability; only an exact TransitionObserved result at the expected successor state can commit the debit
-- and participate in an authority witness. A new action requires a new observation and a new token.

ValidatedMandatoryReconcilerLease =
  < BootstrapAuthority :
      { observed    : ObservedMandatoryReconcilerLeaseState BootstrapHeld
      , capability  : BootstrapMutationActionSubsetCapability
      , singleHolder: MandatoryLeaseControlPlaneDaemonWriterWitness
      , equality    : BootstrapLeaseObservedCapabilityIdentityRvSnapshotEqualityWitness
      }
  | ControlPlaneAuthority :
      { observed    : ObservedMandatoryReconcilerLeaseState ControlPlaneHeld
      , capability  : InClusterReconcilerMutationCapability
      , handoff     : BootstrapReleaseSameLeaseUnheldControlPlaneDaemonAcquireWitness
      , singleHolder: MandatoryLeaseControlPlaneDaemonWriterWitness
      , equality    : ControlPlaneDaemonLeaseObservedCapabilityIdentityRvHandoffSnapshotEqualityWitness
      }
  >
```

## 24. etcd churn

```text
EtcdChurnBudget =
  { maxUpdatesPerWindow : PositiveNatural
  , updateWindow        : FiniteDuration
  , revisionRetention   : FiniteDuration
  , maxActiveLeases     : PositiveNatural
  , maxLeaseBytes       : Quantity Bytes
  , maxEventsPerWindow  : PositiveNatural
  , eventWindow         : FiniteDuration
  , maxEventBytes       : Quantity Bytes
  , eventRetention      : FiniteDuration
  }

EtcdLogicalDemand =
  { desiredObjects : Map KubernetesObjectId KubernetesApiObjectDemand
  , churn          : EtcdChurnBudget
  , model          : EtcdLogicalStorageModelVersion
  }

EtcdLogicalObjectSource =
  { apiObject      : KubernetesApiObjectSource
  , logicalBytes   : Quantity Bytes
  , model          : EtcdLogicalStorageModelVersion
  , sourceEquality : EtcdLogicalObjectApiIdentityByteModelEqualityWitness
  }

ProvisionedEtcdLogicalDemand = -- private constructor
  { objectSet   : Map KubernetesObjectId (Quantity Bytes)
  , derivedPeak : Quantity Bytes
  , witness     : EtcdLogicalCapacityWitness
  }
```

## 25. Tenant policy derivation and persistence

```text
TenantPolicySourceIdentity =
  { tenant          : TenantId
  , roleGraph       : TenantRoleGraphId
  , canonicalDigest : ContentAddress
  }

TenantPolicyOutputKey = (TenantId, TenantPolicyOutputId)
TenantPolicyActionKey = (TenantId, TenantPolicyActionId)
TenantPolicyExecutorKey = (TenantId, TenantPolicyExecutorId)
QualifiedMinioSystemMetadataId = (TenantId, MinioSystemMetadataId)

CanonicalProviderObjectPayload =
  { identity      : ProviderObjectId
  , kind          : ProviderObjectKind
  , canonicalBody : CanonicalBytes
  , bytes         : Quantity Bytes
  , contentDigest : ContentAddress
  }

KeycloakPolicyOutput =
  { realm   : KeycloakRealmId
  , objects : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

VaultPolicyOutput =
  { mount   : VaultMountId
  , objects : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

PulsarPolicyOutput =
  { tenantNamespace : PulsarTenantNamespaceId
  , objects         : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

MinioPolicyOutput =
  { store   : ObjectStoreId
  , objects : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

NetworkPolicyOutput =
  { namespace : NamespaceId
  , objects   : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

PostgresPolicyOutput =
  { database : DatabaseId
  , schema   : DatabaseSchemaId
  , objects  : NonEmptyMap ProviderObjectId CanonicalProviderObjectPayload
  }

TenantPolicyOutput =
  < Keycloak : KeycloakPolicyOutput
  | Vault    : VaultPolicyOutput
  | Pulsar   : PulsarPolicyOutput
  | Minio    : MinioPolicyOutput
  | Network  : NetworkPolicyOutput
  | Postgres : PostgresPolicyOutput
  >

TenantPolicyOutputDemand =
  { identity       : TenantPolicyOutputId
  , source         : TenantPolicySourceIdentity
  , output         : TenantPolicyOutput
  , canonicalBytes : Quantity Bytes
  , canonicalModel : TenantPolicyCanonicalizationModelVersion
  , canonicalContentDigest : ContentAddress
  }

TenantPolicyMutationWindow =
  { maxMutationsPerWindow       : PositiveNatural
  , mutationWindow              : FiniteDuration
  , maxFailedMutationsPerWindow : PositiveNatural
  , failedMutationRetention     : FiniteDuration
  }

KeycloakPolicyTarget =
  { service : KeycloakServiceId, realm : KeycloakRealmId, database : DatabaseId
  , storageModel : PatroniStorageModelVersion }

VaultPolicyTarget =
  { cluster : VaultClusterId, mount : VaultMountId, raftBacking : BackingId
  , storageModel : VaultRaftStorageModelVersion }

PulsarPolicyTarget =
  { cluster : PulsarClusterId, metadataStore : ZooKeeperClusterId
  , storageModel : ZooKeeperStorageModelVersion }

MinioPolicyTarget =
  { store : ObjectStoreId, budget : StorageBudgetId
  , geometry : MinioErasureGeometryFingerprint
  , model : MinioSystemMetadataModelVersion }

KubernetesApiPolicyTarget =
  { cluster : ClusterId, namespace : NamespaceId
  , storageModel : EtcdLogicalStorageModelVersion }

PostgresPolicyTarget =
  { cluster : PatroniClusterId, database : DatabaseId, schema : DatabaseSchemaId
  , storageModel : PatroniStorageModelVersion }

TenantPolicyProviderTarget =
  < Keycloak      : KeycloakPolicyTarget
  | Vault         : VaultPolicyTarget
  | Pulsar        : PulsarPolicyTarget
  | Minio         : MinioPolicyTarget
  | KubernetesApi : KubernetesApiPolicyTarget
  | Postgres      : PostgresPolicyTarget
  >

TenantPolicyProviderTargetKey = canonical identity of TenantPolicyProviderTarget

TenantPolicyProvider = < Keycloak | Vault | Pulsar | Minio | KubernetesApi | Postgres >

TenantPolicyProvisionError = -- closed arms of ProvisionError
  < PolicySourceDigestMismatch
  | PolicyKeySetMismatch
  | UnexpectedPolicyPersistence
  | PolicyNestedIdentityMismatch
  | MissingPolicyAction
  | MissingPolicyExecutor
  | MissingObservedPolicyState
  | TenantPolicyBudgetResolutionMismatch
  | MinioMetadataComponentMismatch
  | DuplicateTenantPolicyExecutionTarget
  | UncoalescedTenantPolicyExecutionDelta
  | TenantPolicyBaseExecutionDoubleDebit
  | TenantPolicyMinioGroupMismatch
  | UnsupportedTenantPolicyProviderObjectQuota
  | PolicyContentDigestMismatch
  >

TenantPolicyApplyIntent =
  { identity : TenantPolicyActionId
  , output   : TenantPolicyOutputId
  , source   : TenantPolicySourceIdentity
  , provider : TenantPolicyProvider
  , target   : TenantPolicyProviderTarget
  , executor : TenantPolicyExecutorId
  }

TenantPolicyExecutorAttachment =
  < Dedicated
  | SharedControlPlaneRole : TenantPolicyControlPlaneRole
  >

TenantPolicyExecutorIntent =
  { identity                    : TenantPolicyExecutorId
  , source                      : TenantPolicySourceIdentity
  , actions                     : NonEmpty TenantPolicyActionId
  , concurrency                 : < Serial | BoundedParallel : PositiveNatural >
  , maxAttemptsPerWindow        : PositiveNatural
  , attemptWindow               : FiniteDuration
  , maxFailedActionsPerWindow   : PositiveNatural
  , failedActionRetention       : FiniteDuration
  , costModel                   : TenantPolicyExecutionCostModelVersion
  , attachment                  : TenantPolicyExecutorAttachment
  }

TenantKeycloakPolicyPersistenceDemand =
  { output                   : TenantPolicyOutputId
  , source                   : TenantPolicySourceIdentity
  , objects                  : NonEmpty SchemaObjectDemand
  , mutation                 : TenantPolicyMutationWindow
  , maxWalBytesPerMutation   : Quantity Bytes
  , retainedWalWindows       : PositiveNatural
  }

TenantPostgresPolicyPersistenceDemand =
  { output                   : TenantPolicyOutputId
  , source                   : TenantPolicySourceIdentity
  , objects                  : NonEmpty SchemaObjectDemand
  , mutation                 : TenantPolicyMutationWindow
  , maxWalBytesPerMutation   : Quantity Bytes
  , retainedWalWindows       : PositiveNatural
  }

TenantVaultPolicyPersistenceDemand =
  { output             : TenantPolicyOutputId
  , source             : TenantPolicySourceIdentity
  , persisted          : NonEmpty VaultPersistedObjectDemand
  , mutation           : TenantPolicyMutationWindow
  , maxRaftBytesPerMutation : Quantity Bytes
  , retainedRaftLogs   : PositiveNatural
  , retainedSnapshots : PositiveNatural
  }

TenantPulsarPolicyPersistenceDemand =
  { output  : TenantPolicyOutputId
  , source  : TenantPolicySourceIdentity
  , entries : NonEmpty ZooKeeperMetadataEntryDemand
  , churn   : ZooKeeperChurnBudget
  }

MinioSystemMetadataEntryDemand =
  { identity        : MinioSystemMetadataId
  , output          : TenantPolicyOutputKey
  , source          : TenantPolicySourceIdentity
  , kind            : < IamPolicy | IamBinding | BucketPolicy | ServiceAccount >
  , maxPayloadBytes : Quantity Bytes
  , retainedVersions: PositiveNatural
  }

TenantMinioPolicyPersistenceDemand =
  { output                     : TenantPolicyOutputKey
  , source                     : TenantPolicySourceIdentity
  , store                      : ObjectStoreId
  , budget                     : StorageBudgetId
  , entries                    : NonEmpty MinioSystemMetadataEntryDemand
  , mutation                   : TenantPolicyMutationWindow
  , maxJournalBytesPerMutation : Quantity Bytes
  , retainedJournalWindows     : PositiveNatural
  , model                      : MinioSystemMetadataModelVersion
  , exactOutput                : MinioEntryOutputKeyEqualityWitness
  }

MinioSystemMetadataGroupKey =
  { store    : ObjectStoreId
  , budget   : StorageBudgetId
  , geometry : MinioErasureGeometryFingerprint
  , model    : MinioSystemMetadataModelVersion
  }

MergedMinioSystemMetadataDemand = -- private all-tenant binder result
  { key                      : MinioSystemMetadataGroupKey
  , tenantSources            : NonEmptyMap TenantId TenantPolicySourceIdentity
  , entries                  : NonEmptyMap TenantPolicyOutputKey (NonEmpty MinioSystemMetadataEntryDemand)
  , mutationWindows          : NonEmptyMap TenantPolicyOutputKey TenantPolicyMutationWindow
  , dynamicJournalExtents    : LogicalObjectSet
  , model                    : MinioSystemMetadataModelVersion
  , modelEquality            : AllTenantMinioMetadataModelsEqualWitness
  , witness                  : MinioSystemMetadataMergeWitness
  }

RetainedMinioStorageBacking = opaque exact RetainedBacking/StorageBacking join for the selected MinIO store

ResolvedRetainedMinioBudgetSupply = -- private binder result; ProviderObjectQuota has no constructor
  { identity            : StorageBudgetId
  , budget              : StorageBudget
  , owner               : BackingId
  , supply              : RetainedMinioStorageBacking
  , budgetInventoryHash : BoundStorageBudgetInventoryFingerprint
  , topologyFingerprint : TopologyFingerprint
  , witness             : StorageBudgetResolutionWitness
  }

ResolvedMinioSystemMetadataGroup = -- private binder result; still unprovisioned
  { demand   : MergedMinioSystemMetadataDemand
  , budget   : ResolvedRetainedMinioBudgetSupply
  , geometry : MinioErasureGeometry
  , witness  : MinioSystemMetadataResolutionWitness
  }

ResolvedMinioSystemMetadataStoreDemand = -- one store, all tenant groups, one physical call
  { store    : ObjectStoreId
  , geometry : MinioErasureGeometry
  , model    : MinioSystemMetadataModelVersion
  , groups   : NonEmptyMap MinioSystemMetadataGroupKey ResolvedMinioSystemMetadataGroup
  , modelEquality : AllStoreGroupModelsEqualTopologyModelWitness
  , witness  : MinioSystemMetadataStoreMergeWitness
  }

ProvisionedMinioSystemMetadataStoreDemand = -- private constructor
  { store                 : ObjectStoreId
  , model                 : MinioSystemMetadataModelVersion
  , dynamicGroups         : NonEmptyMap MinioSystemMetadataGroupKey MinioSystemMetadataGroupProvisionWitness
  , dynamicEntrySet       : Map QualifiedMinioSystemMetadataId (Quantity Bytes)
  , dynamicJournalExtents : LogicalObjectSet
  , dynamicPerDrivePeak   : Map MinioDriveId (Quantity Bytes) -- excludes geometry.metadataReservePerDrive
  , budgetWitnesses       : NonEmptyMap StorageBudgetId StorageBudgetWitness
  , geometryWitness       : MinioSystemMetadataGeometryWitness
  , modelWitness          : MinioSystemMetadataModelEqualityWitness
  }

TenantApiPolicyPersistenceDemand =
  { output  : TenantPolicyOutputId
  , source  : TenantPolicySourceIdentity
  , objects : NonEmpty KubernetesApiObjectDemand
  , mutation: TenantPolicyMutationWindow
  }

DesiredProviderPolicy target payload persistence =
  { key             : TenantPolicyOutputKey
  , action          : TenantPolicyActionKey
  , source          : TenantPolicySourceIdentity
  , executor        : TenantPolicyExecutorKey
  , target          : target
  , payload         : payload
  , persistence     : persistence
  , canonicalBytes  : Quantity Bytes
  , canonicalModel  : TenantPolicyCanonicalizationModelVersion
  , contentDigest   : ContentAddress
  , sourceEquality  : DesiredTenantPolicyProjectionWitness
  }

DesiredTenantPolicyProjection =
  < Keycloak :
      DesiredProviderPolicy KeycloakPolicyTarget KeycloakPolicyOutput
        TenantKeycloakPolicyPersistenceDemand
  | Vault :
      DesiredProviderPolicy VaultPolicyTarget VaultPolicyOutput
        TenantVaultPolicyPersistenceDemand
  | Pulsar :
      DesiredProviderPolicy PulsarPolicyTarget PulsarPolicyOutput
        TenantPulsarPolicyPersistenceDemand
  | Minio :
      DesiredProviderPolicy MinioPolicyTarget MinioPolicyOutput
        TenantMinioPolicyPersistenceDemand
  | Network :
      DesiredProviderPolicy KubernetesApiPolicyTarget NetworkPolicyOutput
        TenantApiPolicyPersistenceDemand
  | Postgres :
      DesiredProviderPolicy PostgresPolicyTarget PostgresPolicyOutput
        TenantPostgresPolicyPersistenceDemand
  >

ObservedKeycloakPolicyPersistence =
  { objects : Map DatabaseSchemaObjectId (Quantity Bytes)
  , wal     : Map SqlWalSegmentId (Quantity Bytes)
  , model   : PatroniStorageModelVersion
  }

ObservedPostgresPolicyPersistence =
  { objects : Map DatabaseSchemaObjectId (Quantity Bytes)
  , wal     : Map SqlWalSegmentId (Quantity Bytes)
  , model   : PatroniStorageModelVersion
  }

ObservedVaultPolicyPersistence =
  { persisted : Map VaultObjectId (Quantity Bytes)
  , raftLogs  : Map VaultRaftLogId (Quantity Bytes)
  , snapshots : Map VaultSnapshotId (Quantity Bytes)
  , model     : VaultRaftStorageModelVersion
  }

ObservedPulsarPolicyPersistence =
  { entries         : Map ZooKeeperPath (Quantity Bytes)
  , transactionLogs : Map ZooKeeperTransactionLogId (Quantity Bytes)
  , snapshots       : Map ZooKeeperSnapshotId (Quantity Bytes)
  , model           : ZooKeeperStorageModelVersion
  }

ObservedMinioPolicyPersistence =
  { group            : MinioSystemMetadataGroupKey
  , entries          : Map QualifiedMinioSystemMetadataId (Quantity Bytes)
  , journals         : Map (TenantId, MinioMetadataJournalId) (Quantity Bytes)
  , dynamicPerDrive  : Map MinioDriveId (Quantity Bytes)
  , model            : MinioSystemMetadataModelVersion
  }

ObservedApiPolicyPersistence =
  { objects   : Map KubernetesObjectId (Quantity Bytes)
  , revisions : Map EtcdRevisionId (Quantity Bytes)
  , model     : EtcdLogicalStorageModelVersion
  }

ObservedProviderPolicy target payload persistence =
  { key             : TenantPolicyOutputKey
  , action          : TenantPolicyActionKey
  , source          : TenantPolicySourceIdentity
  , executor        : TenantPolicyExecutorKey
  , target          : target
  , payload         : payload
  , persistence     : persistence
  , canonicalBytes  : Quantity Bytes
  , canonicalModel  : TenantPolicyCanonicalizationModelVersion
  , contentDigest   : ContentAddress
  , providerVersion : ProviderObjectVersion
  , lifecycle       : < Active | ReplacingOld | ReplacingNew | DeleteRetained >
  , sourceEquality  : ObservedTenantPolicyProjectionWitness
  }

ObservedTenantPolicyProjection =
  < Keycloak :
      ObservedProviderPolicy KeycloakPolicyTarget KeycloakPolicyOutput
        ObservedKeycloakPolicyPersistence
  | Vault :
      ObservedProviderPolicy VaultPolicyTarget VaultPolicyOutput
        ObservedVaultPolicyPersistence
  | Pulsar :
      ObservedProviderPolicy PulsarPolicyTarget PulsarPolicyOutput
        ObservedPulsarPolicyPersistence
  | Minio :
      ObservedProviderPolicy MinioPolicyTarget MinioPolicyOutput
        ObservedMinioPolicyPersistence
  | Network :
      ObservedProviderPolicy KubernetesApiPolicyTarget NetworkPolicyOutput
        ObservedApiPolicyPersistence
  | Postgres :
      ObservedProviderPolicy PostgresPolicyTarget PostgresPolicyOutput
        ObservedPostgresPolicyPersistence
  >

ObservedTenantPolicyOutput =
  { key          : TenantPolicyOutputKey
  , realizations : NonEmptyMap ProviderRealizationId ObservedTenantPolicyProjection
  , active       : Optional ProviderRealizationId
  , keyEquality  : ObservedPolicyRealizationKeyEqualityWitness
  , sourceEquality : ObservedPolicyRealizationSourceEqualityWitness
  }

ObservedTenantPolicyState = -- one tenant only; executors and MinIO stores are deployment-global
  { tenant               : TenantId
  , inventoryFingerprint : InventoryFingerprint
  , outputs              : Map TenantPolicyOutputKey ObservedTenantPolicyOutput
  , tenantKeyEquality    : TenantPolicyOuterKeyEqualityWitness
  , outputDomain         : ObservedTenantPolicyOutputDomainWitness
  }

ObservedTenantPolicyExecutorMember =
  { key          : TenantPolicyExecutorKey
  , source       : TenantPolicySourceIdentity
  , actions      : Set TenantPolicyActionKey
  , attachment   : TenantPolicyExecutorAttachment
  , policy       : TenantPolicyExecutorIntent
  , live         : LiveCommitment
  , sourceEquality : ObservedTenantPolicyExecutorSourceWitness
  }

ObservedTenantPolicyExecutorInventory =
  { targets :
      Map ExecutionUnitId
        { target      : ExecutionUnitId
        , base        : Optional LiveCommitment
        , members     : NonEmptyMap TenantPolicyExecutorKey ObservedTenantPolicyExecutorMember
        , actionDomain: Set TenantPolicyActionKey
        }
  , membership  : ExactTenantPolicyExecutorMembershipWitness
  , actionDomain: ExactTenantPolicyActionExecutorDomainWitness
  , noDoubleDebit: TenantPolicyObservedExecutorDedupWitness
  }

ObservedMinioDynamicGroup =
  { key             : MinioSystemMetadataGroupKey
  , outputs         : NonEmptySet TenantPolicyOutputKey
  , entries         : Map QualifiedMinioSystemMetadataId (Quantity Bytes)
  , journals        : Map (TenantId, MinioMetadataJournalId) (Quantity Bytes)
  , dynamicPerDrive : Map MinioDriveId (Quantity Bytes)
  , modelEquality   : MinioSystemMetadataModelEqualityWitness
  }

ObservedMinioMetadataStore =
  { store                 : ObjectStoreId
  , geometry              : MinioErasureGeometryFingerprint
  , model                 : MinioSystemMetadataModelVersion
  , staticReservePerDrive : Map MinioDriveId (Quantity Bytes)
  , dynamicGroups         : Map MinioSystemMetadataGroupKey ObservedMinioDynamicGroup
  , dynamicPerDrive       : Map MinioDriveId (Quantity Bytes)
  , inventoryFingerprint  : InventoryFingerprint
  , staticDynamicEquality : ObservedMinioStaticDynamicPartitionWitness
  }

ObservedTenantPolicyWholeDeploymentSnapshot =
  { tenants              : Map TenantId ObservedTenantPolicyState
  , executors            : ObservedTenantPolicyExecutorInventory
  , minioStores          : Map ObjectStoreId ObservedMinioMetadataStore
  , inventoryFingerprint : InventoryFingerprint
  , outerKeyEquality     : ObservedTenantPolicyWholeDeploymentKeyWitness
  }

ProviderPolicyTransition observed desired =
  < Create :
      { new : desired }
  | Replace :
      { old : NonEmptyMap ProviderRealizationId observed
      , new : desired
      }
  | Delete :
      { old : NonEmptyMap ProviderRealizationId observed }
  | NoOp :
      { old : NonEmptyMap ProviderRealizationId observed
      , new : desired
      , equality : IdentityProviderTargetContentEqualityWitness
      , noResidualRealizations : ExactOneActiveNoTransitionResidueWitness
      }
  >

KeycloakTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy KeycloakPolicyTarget KeycloakPolicyOutput ObservedKeycloakPolicyPersistence)
    (DesiredProviderPolicy KeycloakPolicyTarget KeycloakPolicyOutput TenantKeycloakPolicyPersistenceDemand)
VaultTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy VaultPolicyTarget VaultPolicyOutput ObservedVaultPolicyPersistence)
    (DesiredProviderPolicy VaultPolicyTarget VaultPolicyOutput TenantVaultPolicyPersistenceDemand)
PulsarTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy PulsarPolicyTarget PulsarPolicyOutput ObservedPulsarPolicyPersistence)
    (DesiredProviderPolicy PulsarPolicyTarget PulsarPolicyOutput TenantPulsarPolicyPersistenceDemand)
MinioTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy MinioPolicyTarget MinioPolicyOutput ObservedMinioPolicyPersistence)
    (DesiredProviderPolicy MinioPolicyTarget MinioPolicyOutput TenantMinioPolicyPersistenceDemand)
NetworkTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy KubernetesApiPolicyTarget NetworkPolicyOutput ObservedApiPolicyPersistence)
    (DesiredProviderPolicy KubernetesApiPolicyTarget NetworkPolicyOutput TenantApiPolicyPersistenceDemand)
PostgresTenantPolicyTransition =
  ProviderPolicyTransition
    (ObservedProviderPolicy PostgresPolicyTarget PostgresPolicyOutput ObservedPostgresPolicyPersistence)
    (DesiredProviderPolicy PostgresPolicyTarget PostgresPolicyOutput TenantPostgresPolicyPersistenceDemand)

TenantPolicyTransitionAction =
  < Keycloak : KeycloakTenantPolicyTransition
  | Vault    : VaultTenantPolicyTransition
  | Pulsar   : PulsarTenantPolicyTransition
  | Minio    : MinioTenantPolicyTransition
  | Network  : NetworkTenantPolicyTransition
  | Postgres : PostgresTenantPolicyTransition
  >

NoProviderCleanup =
  { required : Forbidden }

ProviderCleanupRequirement =
  < None : NoProviderCleanup
  | RetainUntilVerifiedCutover :
      { targets          : NonEmptySet TenantPolicyProviderTargetKey
      , cutover          : ProviderCutoverVerificationRequirement
      , rollbackRetained : Required
      , deadline         : FiniteDeadline
      , sourceEquality   : ProviderCleanupTargetTransitionEqualityWitness
      }
  >

ProviderTargetHighWater target persistence =
  { target    : target
  , old       : Optional persistence
  , new       : Optional persistence
  , nonEmptySide : OldOrNewPersistencePresentWitness
  , overlap   : ProviderTransitionOverlapWitness
  , rollback  : ProviderRollbackRetentionWitness
  , cleanup   : ProviderCleanupRequirement
  , equality  : ProviderTargetHighWaterEqualityWitness target persistence
  }

TenantPolicyProviderTargetHighWater =
  < Keycloak :
      ProviderTargetHighWater KeycloakPolicyTarget PatroniLogicalStorageDemand
  | Vault :
      ProviderTargetHighWater VaultPolicyTarget VaultStorageDemand
  | Pulsar :
      ProviderTargetHighWater PulsarPolicyTarget ZooKeeperMetadataStoreDemand
  | Minio :
      ProviderTargetHighWater MinioPolicyTarget MergedMinioSystemMetadataDemand
  | Network :
      ProviderTargetHighWater KubernetesApiPolicyTarget EtcdLogicalDemand
  | Postgres :
      ProviderTargetHighWater PostgresPolicyTarget PatroniLogicalStorageDemand
  >

ProvisionedProviderTargetHighWater target provision =
  { target    : target
  , old       : Optional provision
  , new       : Optional provision
  , nonEmptySide : OldOrNewProvisionPresentWitness
  , physicalHighWater : ProviderPhysicalHighWaterWitness
  , cleanup   : ProviderCleanupRequirement
  , equality  : ProvisionedProviderTargetHighWaterEqualityWitness target provision
  }

ProvisionedTenantPolicyTargetHighWater =
  < Keycloak :
      ProvisionedProviderTargetHighWater KeycloakPolicyTarget PatroniCapacityWitness
  | Vault :
      ProvisionedProviderTargetHighWater VaultPolicyTarget VaultStorageWitness
  | Pulsar :
      ProvisionedProviderTargetHighWater PulsarPolicyTarget ZooKeeperCapacityWitness
  | Minio :
      ProvisionedProviderTargetHighWater MinioPolicyTarget MinioSystemMetadataGroupProvisionWitness
  | Network :
      ProvisionedProviderTargetHighWater KubernetesApiPolicyTarget EtcdLogicalCapacityWitness
  | Postgres :
      ProvisionedProviderTargetHighWater PostgresPolicyTarget PatroniCapacityWitness
  >

-- The closed provider arm fixes the target and persistence/provision family together. A Keycloak target
-- therefore cannot carry Vault demand merely because both values inhabit deployment-wide inventories.

MinioStoreTransitionHighWater =
  { store           : ObjectStoreId
  , old             : Optional ObservedMinioMetadataStore
  , new             : Optional ResolvedMinioSystemMetadataStoreDemand
  , staticUnionOnce : MinioStaticReserveUnionWitness
  , dynamicUnionOnce: MinioDynamicGroupUnionWitness
  , cleanup         : ProviderCleanupRequirement
  , witness         : MinioStoreTransitionHighWaterWitness
  }

TenantPolicyTransitionExecutorDemand = -- desired plus authenticated observed-only deletes
  { key      : TenantPolicyExecutorKey
  , source   : TenantPolicySourceIdentity
  , actions  : NonEmptySet TenantPolicyActionKey
  , policy   : TenantPolicyExecutorIntent
  , provenance :
      < Desired : TenantPolicyExecutorIntent
      | ObservedDelete : ObservedTenantPolicyExecutorMember
      >
  }

TenantPolicyTransitionPlan = -- private result of read-only observed-state diff; never authored
  { tenant              : TenantId
  , old                 : Optional ObservedTenantPolicyState
  , desired             : Optional TenantPolicyDerivation
  , nonEmptySide        : OldOrDesiredPresentWitness
  , actions             : Map TenantPolicyActionKey TenantPolicyTransitionAction
  , targetHighWater     : Map TenantPolicyProviderTargetKey TenantPolicyProviderTargetHighWater
  , executorMembers     : Map TenantPolicyExecutorKey TenantPolicyTransitionExecutorDemand
  , failedApplyRetention: FiniteDuration
  , rollbackRetention   : FiniteDuration
  , cleanup             : RequiresObservedCutoverAndCleanup
  , witness             : TenantPolicyTransitionPlanWitness
  }

TenantPolicyWholeDeploymentInventory = -- zero tenants and final-tenant deletion are representable
  { derivations      : Map TenantId TenantPolicyDerivation
  , observed         : Map TenantId ObservedTenantPolicyState
  , observedExecutors: ObservedTenantPolicyExecutorInventory
  , observedMinio    : Map ObjectStoreId ObservedMinioMetadataStore
  , transitions      : Map TenantId TenantPolicyTransitionPlan
  , minioStoreTransitions : Map ObjectStoreId MinioStoreTransitionHighWater
  , minioStoreDomain : WholeDeploymentMinioStoreTransitionDomainWitness
  , tenantDomain     : DesiredObservedTenantUnionDomainWitness
  , population       :
      < Empty    : TenantPolicyZeroInventoryWitness
      | NonEmpty : TenantPolicyNonEmptyInventoryWitness
      >
  , witness          : TenantPolicyWholeDeploymentInventoryWitness
  }

ResourceEnvelopeArm = < Pod | HostWorker >

PodResourceVecAddition =
  { cpu              : Residual Cpu
  , memory           : Residual Bytes
  , ephemeralStorage : Residual Bytes
  }

ContainerResourceSourceAddition =
  < NewContainer : ContainerEnvelope
  | ExistingContainer :
      { id                       : ContainerId
      , requests                 : PodResourceVecAddition
      , limits                   : PodResourceVecAddition
      , runtimeMemoryWorkingSet  : Residual Bytes
      , writableRootfsAllowance  : Residual Bytes
      , logHeadroom              : Residual Bytes
      , immutableImageLifecycle  : ExistingContainerImageLifecycleEqualityWitness
      }
  >

PodLocalStorageSourceAddition =
  { diskBackedVolumes : Map VolumeId (Quantity Bytes)
  , mappedFiles       : Map MappedFileVolumeId KubeletMappedFileDemand
  , memoryBackedVolumes : Map VolumeId
      { sizeLimit   : Quantity Bytes
      , persistence : < StageLocal : ContainerId | PodLifetime >
      , access      : NonEmptyMap ContainerId < ReadOnly | ReadWrite >
      }
  , identityModels : PodLocalStorageAdditionIdentityModelWitness
  }

PodRuntimeMetadataSourceAddition =
  { networkAttachments : Set NetworkAttachmentId
  , mounts             : Map PodVolumeMountId
      { container : ContainerId
      , volume    : PodVolumeId
      }
  , structuralOnly     : NoAuthoredRuntimeMetadataBytesWitness
  }

PodAcceleratorSourceAddition =
  < NoChange
  | CudaWorkloads :
      { owner       : ContainerId
      , sources     : NonEmptyMap AcceleratorWorkloadId AcceleratorWorkloadSource
      , workloads   : NonEmptyMap AcceleratorWorkloadId CudaWorkloadDemand
      , coexistence : AcceleratorCoexistencePolicy
      , domain      : AcceleratorWorkloadSourceDemandDomainWitness
      }
  >

HostAcceleratorSourceAddition =
  < NoChange
  | CudaWorkloads :
      { sources     : NonEmptyMap AcceleratorWorkloadId AcceleratorWorkloadSource
      , workloads   : NonEmptyMap AcceleratorWorkloadId CudaWorkloadDemand
      , coexistence : AcceleratorCoexistencePolicy
      , domain      : AcceleratorWorkloadSourceDemandDomainWitness
      }
  | MetalWorkloads :
      { sources     : NonEmptyMap AcceleratorWorkloadId AcceleratorWorkloadSource
      , workloads   : NonEmptyMap AcceleratorWorkloadId MetalWorkloadDemand
      , coexistence : AcceleratorCoexistencePolicy
      , domain      : AcceleratorWorkloadSourceDemandDomainWitness
      }
  >

TenantPolicyExecutionResourceDelta =
  < Pod :
      { containers      : Map ContainerId ContainerResourceSourceAddition
      , overhead        : PodResourceVecAddition
      , podLocal        : PodLocalStorageSourceAddition
      , runtimeMetadata : PodRuntimeMetadataSourceAddition
      , durable         : Map StatefulSetClaimSlot DeclaredVolumeDemand
      , caches          : Map VolumeId InClusterCacheDemand
      , accelerator     : PodAcceleratorSourceAddition
      , completeAxes    : PodResourceEnvelopeSourceAdditionCompletenessWitness
      }
  | HostWorker :
      { runtime :
          { cpuReservation    : Residual Cpu
          , cpuCeiling        : Residual Cpu
          , memoryReservation : Residual Bytes
          , memoryCeiling     : Residual Bytes
          }
      , localStorage : Map HostStorageExtentId
          { backing : HostStorageBackingId, bytes : Quantity Bytes }
      , caches       : Map CacheExtentId HostCacheDemand
      , accelerator  : HostAcceleratorSourceAddition
      , completeAxes : HostResourceEnvelopeSourceAdditionCompletenessWitness
      }
  >

emptyTenantPolicyExecutionDelta
  :: ResourceEnvelopeArm
  -> TenantPolicyExecutionResourceDelta

mergeTenantPolicyExecutionDelta
  :: TenantPolicyExecutionResourceDelta
  -> TenantPolicyExecutionResourceDelta
  -> Either ProvisionError TenantPolicyExecutionResourceDelta
-- same-arm, identity-keyed, associative and commutative; non-negative numeric source axes add. New structural
-- members union by identity only when their immutable image/lifecycle, backing, presentation, attachment,
-- cache, or accelerator model agrees. Runtime metadata additions are attachments and mounts, never caller-
-- supplied component bytes. The empty value is the identity.

applyTenantPolicyExecutionDelta
  :: BoundExecutionUnit
  -> TenantPolicyExecutionResourceDelta
  -> Either ProvisionError BoundExecutionUnit
-- arm mismatch, conflicting identity/model, or an accelerator-family/owner conflict rejects. The complete
-- source-level replacement is re-run through gadt-decode, which re-derives runtime metadata components, cache
-- peaks, physical storage, accelerator allocation/VRAM, and the ordinary/CUDA/Metal controller-resource
-- refinement before the unit may enter BoundExecutionSet.

TenantPolicyExecutionDeltaDemand = -- binder-derived from one abstract executor intent
  { tenant     : TenantId
  , executor   : TenantPolicyExecutorId
  , actions    : NonEmptyMap TenantPolicyActionId TenantPolicyTransitionAction
  , attachment : TenantPolicyExecutorAttachment
  , delta      : TenantPolicyExecutionResourceDelta
  }

BoundTenantPolicyExecutionTarget = -- private plural-binder result keyed by resolved target
  { target      : ExecutionUnitId
  , attachment  : < DedicatedTarget | SharedControlPlaneTarget : TenantPolicyControlPlaneRole >
  , members     : NonEmptyMap (TenantId, TenantPolicyExecutorId) TenantPolicyExecutionDeltaDemand
  , baseline    :
      < ExistingTarget  : BoundExecutionUnit
      | DedicatedSeed   : BoundExecutionUnit
      >
  , summedDelta : TenantPolicyExecutionResourceDelta
  , replacement : BoundExecutionUnit -- complete unit inserted/replaced exactly once
  , algebra     : TenantPolicyExecutionDeltaAssociativeIdentityWitness
  , witness     : TenantPolicyExecutionCoalescingWitness
  }

BoundTenantPolicyExecutionSet = -- private binder result; never stored under ProvisionedSpec
  { targets      : Map ExecutionUnitId BoundTenantPolicyExecutionTarget
  , executionSet : BoundExecutionSet
  , observed     : ObservedTenantPolicyExecutorInventory
  , witness      : TenantPolicyExecutionBindingWitness
  }

ProvisionedTenantPolicyExecutionRef = opaque private reference to one provisioned ExecutionUnitId/epoch witness

ProvisionedTenantPolicyExecution = -- private ProvisionedSpec member
  { targets    : Map ExecutionUnitId ProvisionedTenantPolicyExecutionRef
  , capacity   : TenantPolicyExecutionCapacityWitness
  , coalescing : TenantPolicyExecutionCoalescingWitness
  }

TenantPolicyDerivation =
  { source       : TenantPolicySourceIdentity
  , outputs      : NonEmptyMap TenantPolicyOutputId DesiredTenantPolicyProjection
  , actions      : NonEmptyMap TenantPolicyActionId TenantPolicyApplyIntent
  , executors    : NonEmptyMap TenantPolicyExecutorId TenantPolicyExecutorIntent
  , providerDomains : ProviderIndexedOutputActionPersistenceEqualityWitness
  }

SealedProviderCommand target payload =
  < Create :
      { newTarget       : target
      , desiredPayload  : payload
      , canonicalRequest: CanonicalBytes
      , requestDigest   : ContentAddress
      , cleanup         : ProviderCleanupRequirement
      , projection      : ProviderCreateCommandProjectionWitness
      }
  | Replace :
      { oldTargets      : NonEmptySet target
      , newTarget       : target
      , desiredPayload  : payload
      , canonicalRequest: CanonicalBytes
      , requestDigest   : ContentAddress
      , cleanup         : ProviderCleanupRequirement
      , projection      : ProviderReplaceCommandProjectionWitness
      }
  | Delete :
      { oldTargets      : NonEmptySet target
      , canonicalRequest: CanonicalBytes
      , requestDigest   : ContentAddress
      , cleanup         : ProviderCleanupRequirement
      , projection      : ProviderDeleteCommandProjectionWitness
      }
  | NoOp :
      { oldTarget       : target
      , desiredTarget   : target
      , desiredPayload  : payload
      , equality        : IdentityProviderTargetContentEqualityWitness
      , canonicalRequest: CanonicalBytes
      , requestDigest   : ContentAddress
      , cleanup         : NoProviderCleanup
      , projection      : ProviderNoOpCommandProjectionWitness
      }
  >

ProviderTransitionCommandEqualityWitness action transition command =
  { actionIdentityExact : Required
  , selectedArmExact    : Required
  , oldTargetsExact     : Required
  , newTargetExact      : Required
  , desiredPayloadExact : Required
  , requestDigestExact  : Required
  }
-- Private construction indexes the sealed command by the exact action and transition arm; Create cannot
-- carry Delete/Replace/NoOp bytes, and old/new target or payload identities cannot be cross-paired.

TenantPolicyTargetSnapshotPrecondition target =
  { key       : TenantPolicyProviderTargetKey
  , observed  :
      < Absent : ObservedProviderTargetAbsentWitness
      | Present :
          { target          : target
          , contentDigest   : ContentAddress
          , providerVersion : ProviderObjectVersion
          , resourceVersion : Optional ResourceVersion
          }
      >
  , fingerprint : InventoryFingerprint
  }

TenantPolicyActionSnapshotPreconditionSet action command highWater target =
  { action             : action
  , commandDigest      : command.requestDigest
  , targets            : NonEmptyMap
      TenantPolicyProviderTargetKey (TenantPolicyTargetSnapshotPrecondition target)
  , targetDomainExact  : targets.keys == highWater.keys
  , oldNewContentExact : Required
  , highWaterExact     : Required
  , snapshot           : InventoryFingerprint
  }

ProvisionedProviderAction transition target payload provision =
  { action          : TenantPolicyActionId
  , transition      : transition
  , command         : SealedProviderCommand target payload
  , transitionCommandEquality :
      ProviderTransitionCommandEqualityWitness action transition command
  , executor        : ProvisionedTenantPolicyExecutionRef
  , highWater       : NonEmptyMap
      TenantPolicyProviderTargetKey (ProvisionedProviderTargetHighWater target provision)
  , providerHighWaterDomain : ActionTargetHighWaterKeyDomainEqualityWitness
  , capacity        : TenantPolicyActionCapacityWitness
  , snapshotPreconditions :
      TenantPolicyActionSnapshotPreconditionSet action command highWater target
  }

ProvisionedTenantPolicyAction =
  < Keycloak :
      ProvisionedProviderAction KeycloakTenantPolicyTransition KeycloakPolicyTarget
        KeycloakPolicyOutput PatroniCapacityWitness
  | Vault :
      ProvisionedProviderAction VaultTenantPolicyTransition VaultPolicyTarget
        VaultPolicyOutput VaultStorageWitness
  | Pulsar :
      ProvisionedProviderAction PulsarTenantPolicyTransition PulsarPolicyTarget
        PulsarPolicyOutput ZooKeeperCapacityWitness
  | Minio :
      ProvisionedProviderAction MinioTenantPolicyTransition MinioPolicyTarget
        MinioPolicyOutput MinioSystemMetadataGroupProvisionWitness
  | Network :
      ProvisionedProviderAction NetworkTenantPolicyTransition KubernetesApiPolicyTarget
        NetworkPolicyOutput EtcdLogicalCapacityWitness
  | Postgres :
      ProvisionedProviderAction PostgresTenantPolicyTransition PostgresPolicyTarget
        PostgresPolicyOutput PatroniCapacityWitness
  >

ProvisionedProviderPolicyOutput desired target provision =
  { key          : TenantPolicyOutputKey
  , projection   : desired
  , action       : TenantPolicyActionKey
  , executor     : ProvisionedTenantPolicyExecutionRef
  , persistence  : ProvisionedProviderTargetHighWater target provision
  , sourceEquality :
      ProvisionedProviderPolicyOutputSourceTargetProvisionEqualityWitness desired target provision
  }

ProvisionedTenantPolicyOutput =
  < Keycloak :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy KeycloakPolicyTarget KeycloakPolicyOutput
          TenantKeycloakPolicyPersistenceDemand)
        KeycloakPolicyTarget PatroniCapacityWitness
  | Vault :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy VaultPolicyTarget VaultPolicyOutput
          TenantVaultPolicyPersistenceDemand)
        VaultPolicyTarget VaultStorageWitness
  | Pulsar :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy PulsarPolicyTarget PulsarPolicyOutput
          TenantPulsarPolicyPersistenceDemand)
        PulsarPolicyTarget ZooKeeperCapacityWitness
  | Minio :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy MinioPolicyTarget MinioPolicyOutput
          TenantMinioPolicyPersistenceDemand)
        MinioPolicyTarget MinioSystemMetadataGroupProvisionWitness
  | Network :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy KubernetesApiPolicyTarget NetworkPolicyOutput
          TenantApiPolicyPersistenceDemand)
        KubernetesApiPolicyTarget EtcdLogicalCapacityWitness
  | Postgres :
      ProvisionedProviderPolicyOutput
        (DesiredProviderPolicy PostgresPolicyTarget PostgresPolicyOutput
          TenantPostgresPolicyPersistenceDemand)
        PostgresPolicyTarget PatroniCapacityWitness
  >

ProvisionedTenantPolicyPersistence = -- private nested member of ProvisionedSpec; provider enactor input only through validated actions
  { sourceEquality : TenantPolicyWholeDeploymentSourceEqualityWitness
  , transition     : TenantPolicyWholeDeploymentTransitionProvisionWitness
  , outputs        : Map TenantPolicyOutputKey ProvisionedTenantPolicyOutput
  , actions        : Map TenantPolicyActionKey ProvisionedTenantPolicyAction
  , actionDomain   : TenantPolicyProvisionedActionDomainWitness
  , execution      : ProvisionedTenantPolicyExecution
  , targetHighWater: Map
      TenantPolicyProviderTargetKey ProvisionedTenantPolicyTargetHighWater
  , keycloak       : Map KeycloakPolicyTarget PatroniCapacityWitness
  , vault          : Map VaultPolicyTarget VaultStorageWitness
  , pulsar         : Map PulsarPolicyTarget ZooKeeperCapacityWitness
  , minio          : Map ObjectStoreId ProvisionedMinioSystemMetadataStoreDemand
  , minioTransitions : Map ObjectStoreId ProvisionedMinioStoreTransition
  , apiObjects     : Map KubernetesApiPolicyTarget EtcdLogicalCapacityWitness
  , postgres       : Map PostgresPolicyTarget PatroniCapacityWitness
  , minioStoreEquality : TenantPolicyMinioStorePhysicalSealWitness
  , population     :
      < Empty    : TenantPolicyZeroInventoryWitness
      | NonEmpty : TenantPolicyNonEmptyInventoryWitness
      >
  }

ProvisionedMinioPhysicalDemand = -- private constructor
  { store                 : ObjectStoreId
  , dynamicGroups         : Set MinioSystemMetadataGroupKey
  , payloadPerDrive       : Map MinioDriveId (Quantity Bytes)
  , staticReservePerDrive : Map MinioDriveId (Quantity Bytes)
  , dynamicMetadataPerDrive : Map MinioDriveId (Quantity Bytes)
  , healingPerDrive       : Map MinioDriveId (Quantity Bytes)
  , totalPerDrive         : Map MinioDriveId (Quantity Bytes)
  , exactlyOnceWitness    : MinioPhysicalComponentDisjointnessWitness
  }

ProvisionedMinioStoreTransition =
  { store              : ObjectStoreId
  , observedOld        : Optional ObservedMinioMetadataStore
  , desiredNew         : Optional ProvisionedMinioSystemMetadataStoreDemand
  , highWaterPhysical  : ProvisionedMinioPhysicalDemand
  , postCleanupPhysical: ProvisionedMinioPhysicalDemand
  , nonEmptyTransition : OldOrNewMinioStorePresentWitness
  , oldNewUnion        : MinioStoreOldNewGroupIdentityUnionWitness
  , staticUnionOnce    : MinioStaticReserveUnionWitness
  , cleanup            : ProviderCleanupRequirement
  , zeroAfterFinalDelete : FinalMinioStoreDeletionZeroDynamicWitness
  , sourceEquality     : ProvisionedMinioStoreTransitionSourceWitness
  }
```

## 26. Engine, kind host, network fabric, and monitoring budgets

```text
ControlPlaneStorageDemand =
  { staticEngineBytes : Quantity Bytes
  , etcd              :
      { backendQuotaBytes : Quantity Bytes
      , maxWalFiles       : PositiveNatural
      , retainedSnapshots : Natural
      , maintenance       : < SerializedSnapshotAndDefrag >
      , storageModel      : EtcdStorageModelVersion
      , logical           : EtcdLogicalDemand
      }
  , audit             :
      { maxBytesPerFile : Quantity Bytes, maxBackups : Natural, retention : FiniteDuration }
  , kubeletRuntimeLogs:
      { maxBytesPerFile : Quantity Bytes, maxBackups : Natural, retention : FiniteDuration }
  , historyRequirement : FiniteDuration
  }

WorkerEngineStorageDemand =
  { staticEngineBytes : Quantity Bytes
  , kubeletRuntimeLogs:
      { maxBytesPerFile : Quantity Bytes, maxBackups : Natural, retention : FiniteDuration }
  }

EngineStorageDemand =
  < ControlPlane : ControlPlaneStorageDemand
  | Worker       : WorkerEngineStorageDemand
  >

EngineSystemReserve =
  { role      : EngineNodeRole
  , processes : NonEmpty EngineProcessEnvelope
  , storage   :
      { carve : DiskCarveId
      , demand : EngineStorageDemand
      }
  }

KindHostEngineReserve =
  { processes : NonEmpty EngineProcessEnvelope
  , storage   : KindHostRuntimeStorageDemand
  }

KindHostRuntimeStorageDemand =
  { carve            : DiskCarveId
  , processStorage   : WorkerEngineStorageDemand
  , nodeImage        : ImageArtifact
  , nodeContainers   : NonEmpty
      { ordinal                : Natural
      , writableLayerAllowance : Quantity Bytes
      , logHeadroom             : Quantity Bytes
      }
  , storageModel     : HostContainerStorageModelVersion
  , pullConcurrency  : ImagePullConcurrencyPolicy
  }

ProvisionedKindHostRuntimeStorageDemand = -- private constructor
  { contentObjects  : Map OciObjectDigest (Quantity Bytes)
  , activeSnapshots : Map Natural (Quantity Bytes)
  , pullWorkspace   : Quantity Bytes
  , derivedPeak     : Quantity Bytes
  , carve           : DiskCarveId
  , witness         : KindHostRuntimeStorageWitness
  }

KindNodeContainerDemand =
  { ordinal      : Natural
  , runtime      : HostResources
  , capacity     : NodeCapacity
  , systemReserve: EngineSystemReserve
  }

KindEngineDemand =
  { nodeContainers : NonEmpty KindNodeContainerDemand
  , hostReserve    : KindHostEngineReserve
  }

NetworkFabricSystemDemand =
  { maxPacketsPerSecond : PositiveNatural
  , maxQueuedBytes      : Quantity Bytes
  , logs                :
      { maxBytesPerFile : Quantity Bytes
      , maxBackups      : Natural
      , retention       : FiniteDuration
      }
  , costModel           : NetworkFabricCostModelVersion
  }

ProvisionedNetworkFabricSystemDemand = -- private constructor
  { perNode :
      NonEmpty
        { node    : NodeId
        , peers   : NonEmpty FabricPeerId
        , runtime : HostResources
        , nodefsBytes : Quantity Bytes
        }
  , witness : NetworkFabricCapacityWitness
  }

QueryWorkBudget =
  { maxConcurrentQueries : PositiveNatural
  , maxSeriesPerQuery    : PositiveNatural
  , maxSamplesPerQuery   : PositiveNatural
  , maxRange             : FiniteDuration
  , timeout              : FiniteDuration
  , costModel            : MonitoringQueryCostModelVersion
  }

MonitoringWorkBudget =
  { maxWorkflows       : PositiveNatural
  , maxRules           : PositiveNatural
  , maxSeries          : PositiveNatural
  , maxScrapeSamplesPerSecond : PositiveNatural
  , evaluationInterval : FiniteDuration
  , evaluationCpu      : Quantity Cpu
  , evaluationMemory   : Quantity Bytes
  , retention          : FiniteDuration
  , query              : QueryWorkBudget
  , volume             :
      { claim : StatefulSetClaimSlot
      , backing : BackingId
      , presentation : VolumePresentation
      }
  , tsdbCostModel      : MonitoringStorageModelVersion
  }
```

---

## Related Documents
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the hub of this family; every rule about these types lives there or in a sibling slice
- [Engineering Doctrine Index](./README.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order and status for the work these types describe
