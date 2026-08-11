let Storage = ../amoebius/Storage.dhall

let Image = ../amoebius/Image.dhall

let Resources = ../amoebius/Resources.dhall

let Capacity = ../amoebius/Capacity.dhall

let b = \(bytes : Natural) -> { bytes }

let d = \(seconds : Natural) -> { seconds }

let allocation
    : Storage.BackingAllocationPolicy
    = { minimumBytes = b 4096, quantumBytes = b 4096 }

let filesystem
    : Storage.FilesystemPresentation
    = { fsType = "ext4", overheadModel = "ext4-v1", allocation }

let volumePresentation
    : Storage.VolumePresentation
    = Storage.VolumePresentation.Filesystem filesystem

let claim
    : Storage.StatefulSetClaimSlot
    = { statefulSet = "app", template = "data", ordinal = 0 }

let layer
    : Image.ImageLayer
    = { blobDigest = "sha256:layer"
      , compressedBytes = b 1048576
      , chainId = "chain-0"
      , unpackedBytes = b 2097152
      }

let image
    : Image.ImageArtifact
    = { identity =
          Image.ImageIdentity.Runtime { name = "app", linked = [ "base" ] }
      , manifestListDigest = "sha256:index"
      , manifestListBytes = b 2048
      , platforms =
        { head =
          { platform = Image.OsArch.LinuxAmd64
          , childDigest = "sha256:manifest"
          , childManifestBytes = b 4096
          , configDigest = "sha256:config"
          , configBytes = b 1024
          , layers = { head = layer, tail = [] : List Image.ImageLayer }
          , peakImportWorkspace = b 3145728
          }
        , tail = [] : List Image.ImagePlatformArtifact
        }
      }

let hostResources
    : Resources.HostResources
    = { requests = { cpu.millis = 250, memory = b 268435456 }
      , limits = { cpu.millis = 500, memory = b 536870912 }
      , headroom = None Resources.HostComputeHeadroomDemand
      }

let cacheAsset =
      { identity = "model-a"
      , digest = "sha256:model-a"
      , residentBytes = b 1048576
      , temporaryBytes = b 524288
      }

let cachePopulation
    : Storage.CachePopulationDemand
    = { assets =
        { head = cacheAsset
        , tail =
            [] : List
                   { identity : Text
                   , digest : Text
                   , residentBytes : Storage.ByteQuantity
                   , temporaryBytes : Storage.ByteQuantity
                   }
        }
      , firstMissConcurrency = 1
      , model = "cache-v1"
      }

let cacheBudget
    : Storage.CacheBudget
    = { id = "cache-budget", maximumBytes = b 4194304, retention = d 86400 }

let hostCache
    : Storage.HostCacheDemand
    = { id = "build-cache"
      , backing = "host-cache"
      , budget = cacheBudget
      , population = cachePopulation
      , source =
          < ImageBuild : Text | AssetMaterialization : Text >.ImageBuild "build"
      }

let buildStage
    : Image.BuildStageDemand
    = { id = "build"
      , platform = Image.OsArch.LinuxAmd64
      , dependsOn = [] : List Text
      , runtime =
        { reservations = { cpuMillis = 250, memoryBytes = b 268435456 }
        , ceilings = { cpuMillis = 1000, memoryBytes = b 1073741824 }
        , headroom = Some
          { reason =
              < VerticalGrowth : { horizon : Storage.FiniteDuration }
              | BurstAbsorption
              | NeighbourIsolation
              | DefragmentationReserve
              >.VerticalGrowth
                { horizon = d 3600 }
          , cpuMillis = 100
          , memoryBytes = b 67108864
          }
        }
      , peakIntermediateBytes = b 10485760
      , peakCacheWriteBytes = b 4194304
      , steps =
        { head =
            Image.BakeStep.InstallPackage { name = "app", version = "1.0.0" }
        , tail = [] : List Image.BakeStep
        }
      }

let build
    : Image.BuildExecutionEnvelope
    = { id = { sourceDigest = "sha256:source", output = "sha256:index" }
      , stages = { head = buildStage, tail = [] : List Image.BuildStageDemand }
      , scratchBacking = "build-scratch"
      , cache = hostCache
      , archConcurrency = < Serial | BoundedParallel : Natural >.Serial
      , stageConcurrency =
          < Serial | BoundedParallel : Natural >.BoundedParallel 2
      }

let podVec =
      { cpu.millis = 250
      , memory = b 268435456
      , ephemeralStorage = b 1073741824
      }

let container
    : Resources.ContainerEnvelope
    = { id = "app"
      , lifecycle = Resources.ContainerLifecycle.App
      , image
      , process =
          Image.ContainerProcess.BakedService
            { binary = "/app", args = [] : List Text }
      , runtimeMemoryWorkingSet = b 201326592
      , privateEphemeral =
        { rootFilesystem = Resources.RootFilesystem.ReadOnlyRootfs
        , logHeadroom = b 10485760
        }
      , resources =
        { requests = podVec
        , limits =
          { cpu.millis = 1000
          , memory = b 1073741824
          , ephemeralStorage = b 2147483648
          }
        }
      }

let volume
    : Storage.DeclaredVolumeDemand
    = { id = "app-data"
      , claim
      , backing = "retained"
      , logicalBytes = b 10737418240
      , geometry =
          < Direct : { replicaCount : Natural }
          | BookKeeper : Storage.BookKeeperGeometry
          | Minio : Storage.MinioErasureGeometry
          >.Direct
            { replicaCount = 1 }
      , presentation = volumePresentation
      }

let bookie =
      { id = "bookie-0"
      , claim =
        { statefulSet = "bookkeeper", template = "journal", ordinal = 0 }
      , backing = "retained"
      , journalAndIndexReserve = b 1073741824
      }

let bookKeeperVolume
    : Storage.DeclaredVolumeDemand
    = { id = "bookkeeper-data"
      , claim = bookie.claim
      , backing = "retained"
      , logicalBytes = b 10737418240
      , geometry =
          < Direct : { replicaCount : Natural }
          | BookKeeper : Storage.BookKeeperGeometry
          | Minio : Storage.MinioErasureGeometry
          >.BookKeeper
            { bookies = { head = bookie, tail = [] : List Storage.BookieSlot }
            , ensembleSize = 1
            , writeQuorum = 1
            , ackQuorum = 1
            , ledgerSegmentBytes = b 134217728
            , faultPolicy.maxSimultaneousUnavailableBookies = 1
            }
      , presentation = volumePresentation
      }

let minioDrive =
      { id = "minio-0"
      , claim = { statefulSet = "minio", template = "data", ordinal = 0 }
      , backing = "retained"
      }

let minioVolume
    : Storage.DeclaredVolumeDemand
    = { id = "minio-data"
      , claim = minioDrive.claim
      , backing = "retained"
      , logicalBytes = b 10737418240
      , geometry =
          < Direct : { replicaCount : Natural }
          | BookKeeper : Storage.BookKeeperGeometry
          | Minio : Storage.MinioErasureGeometry
          >.Minio
            { sets =
              { head =
                { id = "set-0"
                , drives =
                  { head = minioDrive, tail = [] : List Storage.MinioDrive }
                , dataShards = 1
                , parityShards = 1
                }
              , tail = [] : List Storage.MinioErasureSet
              }
            , shardBlockBytes = b 1048576
            , metadataReservePerDrive = b 134217728
            , healingWorkspacePerDrive = b 1073741824
            , faultPolicy =
              { maxUnavailablePerErasureSet = 1
              , replacementDrives =
                { head = minioDrive, tail = [] : List Storage.MinioDrive }
              }
            }
      , presentation = volumePresentation
      }

let inClusterCache
    : Storage.InClusterCacheDemand
    = { id = "pod-cache"
      , volume = "cache"
      , budget = cacheBudget
      , population = cachePopulation
      }

let residency
    : Resources.AcceleratorResidencyDemand
    = { id = "weights"
      , class = Resources.AcceleratorResidencyClass.Weights
      , bytes = b 1073741824
      , placement = Resources.AcceleratorResidencyPlacement.Unsharded
      }

let cudaOwner
    : Resources.CudaOwnerDemand
    = { profile = "nvidia-l4"
      , devices = 1
      , sources =
        { head =
          { key = "served-model"
          , value = Resources.AcceleratorWorkloadSource.ServedModel "model-a"
          }
        , tail =
            [] : List
                   { key : Text, value : Resources.AcceleratorWorkloadSource }
        }
      , workloads =
        { head =
          { key = "served-model"
          , value.residency
            =
            { head = { key = "weights", value = residency }
            , tail =
                [] : List
                       { key : Text
                       , value : Resources.AcceleratorResidencyDemand
                       }
            }
          }
        , tail = [] : List { key : Text, value : Resources.CudaWorkloadDemand }
        }
      , coexistence =
        { maxResidentByClass =
          { head =
            { key = Resources.AcceleratorWorkloadClass.ServedModel, value = 1 }
          , tail =
              [] : List
                     { key : Resources.AcceleratorWorkloadClass
                     , value : Natural
                     }
          }
        , maxRunningByClass =
          { head =
            { key = Resources.AcceleratorWorkloadClass.ServedModel, value = 1 }
          , tail =
              [] : List
                     { key : Resources.AcceleratorWorkloadClass
                     , value : Natural
                     }
          }
        , model = "accelerator-coexistence-v1"
        }
      }

let workload
    : Resources.ExecutionUnitIntent
    = { id = "trivial-api"
      , revision = 1
      , controller =
          Resources.Controller.Deployment
            { cardinality =
                Resources.Cardinality.Replicated { desiredReplicas = 2 }
            , rollout = Resources.DeploymentRollout.Recreate
            }
      , resource =
          Resources.ResourceEnvelope.Pod
            { containers =
              { head = container, tail = [] : List Resources.ContainerEnvelope }
            , overhead = Some podVec
            , headroom = Some
              { reason = Resources.ComputeHeadroomReason.BurstAbsorption
              , pad =
                { cpu =
                    < Zero | Remaining : { millis : Natural } >.Remaining
                      { millis = 50 }
                , memory =
                    < Zero | Remaining : Storage.ByteQuantity >.Remaining
                      (b 33554432)
                , ephemeralStorage =
                    < Zero | Remaining : Storage.ByteQuantity >.Zero
                }
              }
            , podLocal =
              { diskBackedVolumes = [ { id = "cache", sizeLimit = b 4194304 } ]
              , mappedFiles =
                [ { id = "config"
                  , source =
                      < ConfigMap
                      | Secret
                      | DownwardApi
                      | ServiceAccountToken
                      >.ConfigMap
                  , payloadBytes = b 4096
                  , accounting = < NodefsEphemeral | Memory >.NodefsEphemeral
                  , model = "kubelet-mapped-v1"
                  }
                ]
              , memoryBackedVolumes =
                [ { id = "scratch"
                  , sizeLimit = b 1048576
                  , persistence =
                      < StageLocal : Text | PodLifetime >.StageLocal "app"
                  , access =
                    { head =
                      { container = "app"
                      , mode = < ReadOnly | ReadWrite >.ReadWrite
                      }
                    , tail =
                        [] : List
                               { container : Text
                               , mode : < ReadOnly | ReadWrite >
                               }
                    }
                  }
                ]
              }
            , runtimeMetadata =
              { networkAttachments = { head = "default", tail = [] : List Text }
              , mounts =
                [ { key = "cache-app", container = "app", volume = "cache" } ]
              }
            , durable = [ volume, bookKeeperVolume, minioVolume ]
            , cache = Some inClusterCache
            , accelerator =
                Resources.PodAcceleratorDemand.Cuda
                  { owner = "app", demand = cudaOwner }
            }
      }

let cpuOvercommit =
      Capacity.CpuOvercommitPolicy.BoundedCpuOvercommit
        { maxLimitToAllocatablePermille = 1250 }

let nodefs = { carve = "nodefs", allocatableBytes = b 53687091200 }

let cudaOffering
    : Capacity.CudaDeviceOffering
    = { family = "nvidia"
      , devices =
        { head =
          { id = "gpu-0"
          , profile = "nvidia-l4"
          , rawVram = b 25769803776
          , driverRuntimeReserve = b 1073741824
          , allocatableVram = b 24696061952
          }
        , tail = [] : List Capacity.AcceleratorDevice
        }
      , links = [] : List Capacity.AcceleratorLink
      }

let nodeCapacity
    : Capacity.NodeCapacity
    = { allocatableCpu.millis = 8000
      , allocatableMemory = b 34359738368
      , allocatablePods = 110
      , allocatableCniSlots = [ { key = "cilium", value = 110 } ]
      , attachableVolumes =
        [ { key = "local.csi.amoebius", value = 8 }
        , { key = "ebs.csi.aws.com", value = 25 }
        ]
      , cpuOvercommit
      , localStorage =
        { podEphemeralAllocatable = b 42949672960
        , filesystems = Capacity.KubeletFilesystemLayout.Unified { nodefs }
        , imageStorageModel = "containerd-v1"
        , imagePullConcurrency =
            Capacity.ImagePullConcurrencyPolicy.BoundedParallel 4
        , kubeletMetadataModel = "kubelet-v1"
        }
      , accelerator = Capacity.NodeAcceleratorOffering.CudaOffering cudaOffering
      }

let logDemand =
      { maxBytesPerFile = b 10485760, maxBackups = 4, retention = d 86400 }

let workerStorage
    : Capacity.WorkerEngineStorageDemand
    = { staticEngineBytes = b 1073741824, kubeletRuntimeLogs = logDemand }

let process
    : Capacity.EngineProcessEnvelope
    = { id = "rke2-agent", runtime = hostResources }

let rke2Node
    : Capacity.Rke2NodeDemand
    = { host = "linux-host"
      , capacity = nodeCapacity
      , systemReserve =
        { role = Capacity.EngineNodeRole.Rke2Agent
        , processes =
          { head = process, tail = [] : List Capacity.EngineProcessEnvelope }
        , storage =
          { carve = "system"
          , demand = Capacity.EngineStorageDemand.Worker workerStorage
          }
        }
      }

let controlPlaneStorage
    : Capacity.ControlPlaneStorageDemand
    = { staticEngineBytes = b 2147483648
      , etcd =
        { backendQuotaBytes = b 8589934592
        , maxWalFiles = 8
        , retainedSnapshots = 3
        , maintenance =
            < SerializedSnapshotAndDefrag >.SerializedSnapshotAndDefrag
        , storageModel = "etcd-v1"
        , logical =
          { desiredObjects =
            [ { key = "deployment/app"
              , value =
                { identity = "deployment/app", serializedBytes = b 4096 }
              }
            ]
          , churn =
            { maxUpdatesPerWindow = 1000
            , updateWindow = d 60
            , revisionRetention = d 3600
            , maxActiveLeases = 100
            , maxLeaseBytes = b 1024
            , maxEventsPerWindow = 2000
            , eventWindow = d 60
            , maxEventBytes = b 4096
            , eventRetention = d 600
            }
          , model = "etcd-logical-v1"
          }
        }
      , audit = logDemand
      , kubeletRuntimeLogs = logDemand
      , historyRequirement = d 86400
      }

let rke2Server
    : Capacity.Rke2NodeDemand
    = { host = "linux-server"
      , capacity = nodeCapacity
      , systemReserve =
        { role = Capacity.EngineNodeRole.Rke2Server
        , processes =
          { head = { id = "rke2-server", runtime = hostResources }
          , tail = [] : List Capacity.EngineProcessEnvelope
          }
        , storage =
          { carve = "system"
          , demand =
              Capacity.EngineStorageDemand.ControlPlane controlPlaneStorage
          }
        }
      }

let kindNode
    : Capacity.KindNodeContainerDemand
    = { ordinal = 0
      , runtime = hostResources
      , capacity = nodeCapacity
      , systemReserve =
        { role = Capacity.EngineNodeRole.KindControlPlane
        , processes =
          { head = { id = "kube-apiserver", runtime = hostResources }
          , tail = [] : List Capacity.EngineProcessEnvelope
          }
        , storage =
          { carve = "kind-system"
          , demand =
              Capacity.EngineStorageDemand.ControlPlane controlPlaneStorage
          }
        }
      }

let kindEngine
    : Capacity.KindEngineDemand
    = { nodeContainers =
        { head = kindNode, tail = [] : List Capacity.KindNodeContainerDemand }
      , hostReserve =
        { processes =
          { head = { id = "containerd", runtime = hostResources }
          , tail = [] : List Capacity.EngineProcessEnvelope
          }
        , storage =
          { carve = "kind-host"
          , processStorage = workerStorage
          , nodeImage = image
          , nodeContainers =
            { head =
              { ordinal = 0
              , writableLayerAllowance = b 1073741824
              , logHeadroom = b 104857600
              }
            , tail =
                [] : List
                       { ordinal : Natural
                       , writableLayerAllowance : Storage.ByteQuantity
                       , logHeadroom : Storage.ByteQuantity
                       }
            }
          , storageModel = "host-container-v1"
          , pullConcurrency = Capacity.ImagePullConcurrencyPolicy.Serial
          }
        }
      }

let exactRawCarve
    : Capacity.NamedDiskCarve
    = { parent = Capacity.DiskParentExtent.PhysicalRawExtent
      , extent =
          Capacity.NamedDiskCarveExtent.ExactParentExtent
            { id = "system", parentBytes = b 2147483648 }
      }

let exactGuestCarve
    : Capacity.NamedDiskCarve
    = { parent = Capacity.DiskParentExtent.VmGuestUsableExtent
      , extent =
          Capacity.NamedDiskCarveExtent.ExactParentExtent
            { id = "guest-nodefs", parentBytes = b 53687091200 }
      }

let vmDisk
    : Capacity.VmDiskCarve
    = { id = "vm-root"
      , presentation = filesystem
      , allocation
      , guestSystem =
        { parent = Capacity.DiskParentExtent.VmGuestUsableExtent
        , extent =
            Capacity.NamedDiskCarveExtent.PresentedUsableExtent
              { id = "guest-system"
              , requiredUsableBytes = b 10737418240
              , presentation = volumePresentation
              , allocation
              }
        }
      , kubelet =
          Capacity.KubeletFilesystemCarves.SplitRuntime
            { nodefs = exactGuestCarve, imagefs = exactGuestCarve }
      }

let physicalHost
    : Capacity.PhysicalHostCapacity
    = { allocatableCpu.millis = 16000
      , allocatableMemory = b 68719476736
      , diskPartitions =
        { head =
          { backing = "disk0"
          , allocatableRawBytes = b 1099511627776
          , systemReserve = exactRawCarve
          , vmDisks = [ vmDisk ]
          , directNodePools =
            [ Capacity.KubeletFilesystemCarves.Unified
                { nodefs = exactRawCarve }
            ]
          , retainedPools = [ { id = "retained", carve = exactRawCarve } ]
          , hostCachePools = [ { id = "host-cache", carve = exactRawCarve } ]
          , hostStoragePools =
            [ { id = "build-scratch"
              , purpose =
                  < HostWorkerLocal | BuildScratch | ToolInstall >.BuildScratch
              , carve = exactRawCarve
              }
            ]
          }
        , tail = [] : List Capacity.PhysicalDiskPartition
        }
      , accelerator =
          Capacity.HostAcceleratorOffering.AppleMetalOffering
            { profile = "apple-m2-ultra", unifiedMemory = b 68719476736 }
      }

let providerCarve
    : Capacity.ProviderUsableDiskCarveTemplate
    = { id = "nodefs", requiredUsableBytes = b 107374182400 }

let providerDisk
    : Capacity.PerInstanceDiskTemplate
    = { id = "root"
      , backing =
          Capacity.PerInstanceDiskBacking.InstanceStore
            { skuDevice = "/dev/nvme0n1"
            , provisionedRawBytes = b 214748364800
            , presentation = filesystem
            }
      , systemReserve = { id = "system", requiredUsableBytes = b 10737418240 }
      , carves =
        { head = providerCarve
        , tail = [] : List Capacity.ProviderUsableDiskCarveTemplate
        }
      }

let providerEbsDisk
    : Capacity.PerInstanceDiskTemplate
    = { id = "root-ebs"
      , backing =
          Capacity.PerInstanceDiskBacking.EphemeralRootEbs
            { policy =
              { volumeType = "gp3", presentation = filesystem, allocation }
            }
      , systemReserve =
        { id = "system-ebs", requiredUsableBytes = b 10737418240 }
      , carves =
        { head = { id = "nodefs-ebs", requiredUsableBytes = b 53687091200 }
        , tail = [] : List Capacity.ProviderUsableDiskCarveTemplate
        }
      }

let providerNodeTemplate
    : Capacity.ProviderNodeCapacityTemplate
    = { allocatableCpu.millis = 7800
      , allocatableMemory = b 32212254720
      , podSlots =
        { catalogMaximum = 110, systemReserve = 20, allocatable = 90 }
      , cniSlots =
        [ { key = "vpc-cni"
          , value =
            { catalogMaximum = 120, systemReserve = 30, allocatable = 90 }
          }
        ]
      , attachableVolumes =
        [ { key = "ebs.csi.aws.com"
          , value = { catalogMaximum = 39, systemReserve = 4, allocatable = 35 }
          }
        , { key = "fsx.csi.aws.com"
          , value = { catalogMaximum = 12, systemReserve = 2, allocatable = 10 }
          }
        ]
      , localDisks = { head = providerDisk, tail = [ providerEbsDisk ] }
      , cpuOvercommit
      , localStorage =
        { podEphemeralAllocatable = b 85899345920
        , filesystems =
            Capacity.PerInstanceKubeletFilesystemLayout.SplitRuntime
              { nodefs =
                { carve = { disk = "root", carve = "nodefs" }
                , allocatableBytes = b 53687091200
                }
              , imagefs =
                { carve = { disk = "root", carve = "nodefs" }
                , allocatableBytes = b 32212254720
                }
              }
        , imageStorageModel = "containerd-v1"
        , imagePullConcurrency =
            Capacity.ImagePullConcurrencyPolicy.BoundedParallel 8
        , kubeletMetadataModel = "eks-kubelet-v1"
        }
      , accelerator =
          Capacity.PerInstanceAcceleratorOffering.CudaOffering
            { family = "nvidia"
            , devices =
              { head =
                { id = "gpu-slot-0"
                , profile = "nvidia-l4"
                , rawVram = b 25769803776
                , driverRuntimeReserve = b 1073741824
                , allocatableVram = b 24696061952
                }
              , tail = [] : List Capacity.PerInstanceAcceleratorSlot
              }
            , links = [] : List Capacity.PerInstanceAcceleratorLink
            }
      }

let providerNodeClass
    : Capacity.ProviderNodeClass
    = { name = "cpu-general"
      , sku =
        { provider = < AwsEc2 >.AwsEc2
        , region = "ca-central-1"
        , machineType = "m7i.2xlarge"
        , catalogVersion = "2026-08"
        }
      , allocatable = providerNodeTemplate
      , quotaVcpu = 8
      , zones = { head = "ca-central-1a", tail = [ "ca-central-1b" ] }
      , price.microsPerHour = 476000
      , baseCount = 3
      , maxCount = 12
      }

let providerQuota
    : Capacity.ProviderQuota
    = { maxInstances = 20
      , maxVcpu = 160
      , acceleratorCaps = [] : List { key : Text, value : Natural }
      , nodeRootStorage =
          Capacity.NodeRootStorageQuota.BoundedNodeRootEbs
            { bytes = b 2199023255552, volumeCount = 20 }
      , durable =
          Capacity.DurableQuota.Bounded
            { bytes = b 10995116277760, volumeCount = 100 }
      }

let podEnvelope
    : Resources.PodResourceEnvelope
    = { containers =
        { head = container, tail = [] : List Resources.ContainerEnvelope }
      , overhead = None Resources.PodResourceVec
      , headroom = None Resources.ComputeHeadroomDemand
      , podLocal =
        { diskBackedVolumes =
            [] : List { id : Text, sizeLimit : Storage.ByteQuantity }
        , mappedFiles = [] : List Resources.KubeletMappedFileDemand
        , memoryBackedVolumes =
            [] : List
                   { id : Text
                   , sizeLimit : Storage.ByteQuantity
                   , persistence : < StageLocal : Text | PodLifetime >
                   , access :
                       { head :
                           { container : Text, mode : < ReadOnly | ReadWrite > }
                       , tail :
                           List
                             { container : Text
                             , mode : < ReadOnly | ReadWrite >
                             }
                       }
                   }
        }
      , runtimeMetadata =
        { networkAttachments = { head = "default", tail = [] : List Text }
        , mounts = [] : List { key : Text, container : Text, volume : Text }
        }
      , durable = [] : List Storage.DeclaredVolumeDemand
      , cache = None Storage.InClusterCacheDemand
      , accelerator = Resources.PodAcceleratorDemand.None
      }

in  { b
    , d
    , allocation
    , filesystem
    , volumePresentation
    , claim
    , image
    , build
    , container
    , volume
    , workload
    , nodeCapacity
    , rke2Server
    , rke2Node
    , kindEngine
    , physicalHost
    , providerNodeClass
    , providerQuota
    , podEnvelope
    , cachePopulation
    , cacheBudget
    , inClusterCache
    , hostCache
    }
