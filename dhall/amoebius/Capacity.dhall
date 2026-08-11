let Storage = ./Storage.dhall

let Image = ./Image.dhall

let Resources = ./Resources.dhall

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let Entry = \(k : Type) -> \(v : Type) -> { key : k, value : v }

let CpuOvercommitPolicy =
      < NoCpuOvercommit
      | BoundedCpuOvercommit : { maxLimitToAllocatablePermille : Natural }
      >

let ImagePullConcurrencyPolicy = < Serial | BoundedParallel : Natural >

let NodeFilesystemBacking =
      { carve : Text, allocatableBytes : Storage.ByteQuantity }

let KubeletFilesystemLayout =
      < Unified : { nodefs : NodeFilesystemBacking }
      | SplitRuntime :
          { nodefs : NodeFilesystemBacking, imagefs : NodeFilesystemBacking }
      | SplitImage :
          { nodefs : NodeFilesystemBacking
          , imagefs : NodeFilesystemBacking
          , support : < ContainerdSplitImageV1 >
          }
      >

let NodeLocalStorageCapacity =
      { podEphemeralAllocatable : Storage.ByteQuantity
      , filesystems : KubeletFilesystemLayout
      , imageStorageModel : Text
      , imagePullConcurrency : ImagePullConcurrencyPolicy
      , kubeletMetadataModel : Text
      }

let AcceleratorLink =
      { from : Text, to : Text, kind : < PciePeerAccess | NvLink > }

let AcceleratorDevice =
      { id : Text
      , profile : Text
      , rawVram : Storage.ByteQuantity
      , driverRuntimeReserve : Storage.ByteQuantity
      , allocatableVram : Storage.ByteQuantity
      }

let CudaDeviceOffering =
      { family : Text
      , devices : NonEmpty AcceleratorDevice
      , links : List AcceleratorLink
      }

let NodeAcceleratorOffering = < None | CudaOffering : CudaDeviceOffering >

let HostAcceleratorOffering =
      < None
      | CudaOffering : CudaDeviceOffering
      | AppleMetalOffering :
          { profile : Text, unifiedMemory : Storage.ByteQuantity }
      >

let ProviderPodSlotPolicy =
      { catalogMaximum : Natural
      , systemReserve : Natural
      , allocatable : Natural
      }

let ProviderCniSlotPolicy =
      { catalogMaximum : Natural
      , systemReserve : Natural
      , allocatable : Natural
      }

let ProviderAttachSlotPolicy =
      { catalogMaximum : Natural
      , systemReserve : Natural
      , allocatable : Natural
      }

let ProviderUsableDiskCarveTemplate =
      { id : Text, requiredUsableBytes : Storage.ByteQuantity }

let ProviderNodeRootVolumePolicy =
      { volumeType : Text
      , presentation : Storage.FilesystemPresentation
      , allocation : Storage.BackingAllocationPolicy
      }

let PerInstanceDiskBacking =
      < InstanceStore :
          { skuDevice : Text
          , provisionedRawBytes : Storage.ByteQuantity
          , presentation : Storage.FilesystemPresentation
          }
      | EphemeralRootEbs : { policy : ProviderNodeRootVolumePolicy }
      >

let PerInstanceDiskTemplate =
      { id : Text
      , backing : PerInstanceDiskBacking
      , systemReserve : ProviderUsableDiskCarveTemplate
      , carves : NonEmpty ProviderUsableDiskCarveTemplate
      }

let PerInstanceCarveRef = { disk : Text, carve : Text }

let PerInstanceFilesystemRef =
      { carve : PerInstanceCarveRef, allocatableBytes : Storage.ByteQuantity }

let PerInstanceKubeletFilesystemLayout =
      < Unified : { nodefs : PerInstanceFilesystemRef }
      | SplitRuntime :
          { nodefs : PerInstanceFilesystemRef
          , imagefs : PerInstanceFilesystemRef
          }
      | SplitImage :
          { nodefs : PerInstanceFilesystemRef
          , imagefs : PerInstanceFilesystemRef
          , requiredRuntime : < ContainerdSplitImageV1 >
          }
      >

let PerInstanceNodeLocalStorageTemplate =
      { podEphemeralAllocatable : Storage.ByteQuantity
      , filesystems : PerInstanceKubeletFilesystemLayout
      , imageStorageModel : Text
      , imagePullConcurrency : ImagePullConcurrencyPolicy
      , kubeletMetadataModel : Text
      }

let PerInstanceAcceleratorSlot =
      { id : Text
      , profile : Text
      , rawVram : Storage.ByteQuantity
      , driverRuntimeReserve : Storage.ByteQuantity
      , allocatableVram : Storage.ByteQuantity
      }

let PerInstanceAcceleratorLink =
      { from : Text, to : Text, kind : < PciePeerAccess | NvLink > }

let PerInstanceAcceleratorOffering =
      < None
      | CudaOffering :
          { family : Text
          , devices : NonEmpty PerInstanceAcceleratorSlot
          , links : List PerInstanceAcceleratorLink
          }
      >

let ProviderNodeCapacityTemplate =
      { allocatableCpu : { millis : Natural }
      , allocatableMemory : Storage.ByteQuantity
      , podSlots : ProviderPodSlotPolicy
      , cniSlots : List (Entry Text ProviderCniSlotPolicy)
      , attachableVolumes : List (Entry Text ProviderAttachSlotPolicy)
      , localDisks : NonEmpty PerInstanceDiskTemplate
      , cpuOvercommit : CpuOvercommitPolicy
      , localStorage : PerInstanceNodeLocalStorageTemplate
      , accelerator : PerInstanceAcceleratorOffering
      }

let ProviderSkuRef =
      { provider : < AwsEc2 >
      , region : Text
      , machineType : Text
      , catalogVersion : Text
      }

let ProviderNodeClass =
      { name : Text
      , sku : ProviderSkuRef
      , allocatable : ProviderNodeCapacityTemplate
      , quotaVcpu : Natural
      , zones : NonEmpty Text
      , price : { microsPerHour : Natural }
      , baseCount : Natural
      , maxCount : Natural
      }

let NodeRootStorageQuota =
      < NoNodeRootEbs
      | BoundedNodeRootEbs :
          { bytes : Storage.ByteQuantity, volumeCount : Natural }
      >

let DurableQuota =
      < NoDurable
      | Bounded : { bytes : Storage.ByteQuantity, volumeCount : Natural }
      >

let ProviderQuota =
      { maxInstances : Natural
      , maxVcpu : Natural
      , acceleratorCaps : List (Entry Text Natural)
      , nodeRootStorage : NodeRootStorageQuota
      , durable : DurableQuota
      }

let NodeCapacity =
      { allocatableCpu : { millis : Natural }
      , allocatableMemory : Storage.ByteQuantity
      , allocatablePods : Natural
      , allocatableCniSlots : List (Entry Text Natural)
      , attachableVolumes : List (Entry Text Natural)
      , cpuOvercommit : CpuOvercommitPolicy
      , localStorage : NodeLocalStorageCapacity
      , accelerator : NodeAcceleratorOffering
      }

let DiskParentExtent = < PhysicalRawExtent | VmGuestUsableExtent >

let NamedDiskCarveExtent =
      < ExactParentExtent : { id : Text, parentBytes : Storage.ByteQuantity }
      | PresentedUsableExtent :
          { id : Text
          , requiredUsableBytes : Storage.ByteQuantity
          , presentation : Storage.VolumePresentation
          , allocation : Storage.BackingAllocationPolicy
          }
      >

let NamedDiskCarve =
      { parent : DiskParentExtent, extent : NamedDiskCarveExtent }

let KubeletFilesystemCarves =
      < Unified : { nodefs : NamedDiskCarve }
      | SplitRuntime : { nodefs : NamedDiskCarve, imagefs : NamedDiskCarve }
      | SplitImage : { nodefs : NamedDiskCarve, imagefs : NamedDiskCarve }
      >

let VmDiskCarve =
      { id : Text
      , presentation : Storage.FilesystemPresentation
      , allocation : Storage.BackingAllocationPolicy
      , guestSystem : NamedDiskCarve
      , kubelet : KubeletFilesystemCarves
      }

let RetainedStoragePool = { id : Text, carve : NamedDiskCarve }

let HostCachePool = { id : Text, carve : NamedDiskCarve }

let HostStoragePool =
      { id : Text
      , purpose : < HostWorkerLocal | BuildScratch | ToolInstall >
      , carve : NamedDiskCarve
      }

let PhysicalDiskPartition =
      { backing : Text
      , allocatableRawBytes : Storage.ByteQuantity
      , systemReserve : NamedDiskCarve
      , vmDisks : List VmDiskCarve
      , directNodePools : List KubeletFilesystemCarves
      , retainedPools : List RetainedStoragePool
      , hostCachePools : List HostCachePool
      , hostStoragePools : List HostStoragePool
      }

let PhysicalHostCapacity =
      { allocatableCpu : { millis : Natural }
      , allocatableMemory : Storage.ByteQuantity
      , diskPartitions : NonEmpty PhysicalDiskPartition
      , accelerator : HostAcceleratorOffering
      }

let EngineProcessEnvelope = { id : Text, runtime : Resources.HostResources }

let EngineNodeRole = < KindControlPlane | KindWorker | Rke2Server | Rke2Agent >

let EtcdChurnBudget =
      { maxUpdatesPerWindow : Natural
      , updateWindow : Storage.FiniteDuration
      , revisionRetention : Storage.FiniteDuration
      , maxActiveLeases : Natural
      , maxLeaseBytes : Storage.ByteQuantity
      , maxEventsPerWindow : Natural
      , eventWindow : Storage.FiniteDuration
      , maxEventBytes : Storage.ByteQuantity
      , eventRetention : Storage.FiniteDuration
      }

let KubernetesApiObjectDemand =
      { identity : Text, serializedBytes : Storage.ByteQuantity }

let EtcdLogicalDemand =
      { desiredObjects : List (Entry Text KubernetesApiObjectDemand)
      , churn : EtcdChurnBudget
      , model : Text
      }

let RotatedLogDemand =
      { maxBytesPerFile : Storage.ByteQuantity
      , maxBackups : Natural
      , retention : Storage.FiniteDuration
      }

let ControlPlaneStorageDemand =
      { staticEngineBytes : Storage.ByteQuantity
      , etcd :
          { backendQuotaBytes : Storage.ByteQuantity
          , maxWalFiles : Natural
          , retainedSnapshots : Natural
          , maintenance : < SerializedSnapshotAndDefrag >
          , storageModel : Text
          , logical : EtcdLogicalDemand
          }
      , audit : RotatedLogDemand
      , kubeletRuntimeLogs : RotatedLogDemand
      , historyRequirement : Storage.FiniteDuration
      }

let WorkerEngineStorageDemand =
      { staticEngineBytes : Storage.ByteQuantity
      , kubeletRuntimeLogs : RotatedLogDemand
      }

let EngineStorageDemand =
      < ControlPlane : ControlPlaneStorageDemand
      | Worker : WorkerEngineStorageDemand
      >

let EngineSystemReserve =
      { role : EngineNodeRole
      , processes : NonEmpty EngineProcessEnvelope
      , storage : { carve : Text, demand : EngineStorageDemand }
      }

let KindHostRuntimeStorageDemand =
      { carve : Text
      , processStorage : WorkerEngineStorageDemand
      , nodeImage : Image.ImageArtifact
      , nodeContainers :
          NonEmpty
            { ordinal : Natural
            , writableLayerAllowance : Storage.ByteQuantity
            , logHeadroom : Storage.ByteQuantity
            }
      , storageModel : Text
      , pullConcurrency : ImagePullConcurrencyPolicy
      }

let KindHostEngineReserve =
      { processes : NonEmpty EngineProcessEnvelope
      , storage : KindHostRuntimeStorageDemand
      }

let KindNodeContainerDemand =
      { ordinal : Natural
      , runtime : Resources.HostResources
      , capacity : NodeCapacity
      , systemReserve : EngineSystemReserve
      }

let KindEngineDemand =
      { nodeContainers : NonEmpty KindNodeContainerDemand
      , hostReserve : KindHostEngineReserve
      }

let Rke2NodeDemand =
      { host : Text
      , capacity : NodeCapacity
      , systemReserve : EngineSystemReserve
      }

let NodeSupply =
      < Fixed : { nodes : NonEmpty NodeCapacity }
      | Elastic :
          { floor : NonEmpty ProviderNodeClass
          , candidates : NonEmpty ProviderNodeClass
          , quota : ProviderQuota
          }
      >

let Capacity =
      < Materialized :
          { hosts : NonEmpty { id : Text, capacity : PhysicalHostCapacity }
          , nodes : NonEmpty { id : Text, capacity : NodeCapacity }
          , kindEngine : Optional KindEngineDemand
          , rke2Nodes : List Rke2NodeDemand
          }
      | ProviderTemplate :
          { account : Text
          , nodeClasses : NonEmpty ProviderNodeClass
          , quota : ProviderQuota
          }
      >

in  { Type = Capacity
    , CpuOvercommitPolicy
    , ImagePullConcurrencyPolicy
    , NodeFilesystemBacking
    , KubeletFilesystemLayout
    , NodeLocalStorageCapacity
    , AcceleratorDevice
    , AcceleratorLink
    , CudaDeviceOffering
    , NodeAcceleratorOffering
    , HostAcceleratorOffering
    , ProviderPodSlotPolicy
    , ProviderCniSlotPolicy
    , ProviderAttachSlotPolicy
    , ProviderUsableDiskCarveTemplate
    , ProviderNodeRootVolumePolicy
    , PerInstanceDiskBacking
    , PerInstanceDiskTemplate
    , PerInstanceCarveRef
    , PerInstanceFilesystemRef
    , PerInstanceKubeletFilesystemLayout
    , PerInstanceNodeLocalStorageTemplate
    , PerInstanceAcceleratorSlot
    , PerInstanceAcceleratorLink
    , PerInstanceAcceleratorOffering
    , ProviderNodeCapacityTemplate
    , ProviderSkuRef
    , ProviderNodeClass
    , NodeRootStorageQuota
    , DurableQuota
    , ProviderQuota
    , NodeCapacity
    , DiskParentExtent
    , NamedDiskCarveExtent
    , NamedDiskCarve
    , KubeletFilesystemCarves
    , VmDiskCarve
    , PhysicalDiskPartition
    , PhysicalHostCapacity
    , EngineProcessEnvelope
    , EngineNodeRole
    , EtcdChurnBudget
    , EtcdLogicalDemand
    , ControlPlaneStorageDemand
    , WorkerEngineStorageDemand
    , EngineStorageDemand
    , EngineSystemReserve
    , KindHostRuntimeStorageDemand
    , KindHostEngineReserve
    , KindNodeContainerDemand
    , KindEngineDemand
    , Rke2NodeDemand
    , NodeSupply
    }
