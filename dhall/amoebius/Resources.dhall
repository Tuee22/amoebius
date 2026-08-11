let Storage = ./Storage.dhall

let Image = ./Image.dhall

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let Entry = \(k : Type) -> \(v : Type) -> { key : k, value : v }

let PodResourceVec =
      { cpu : { millis : Natural }
      , memory : Storage.ByteQuantity
      , ephemeralStorage : Storage.ByteQuantity
      }

let Resources = { requests : PodResourceVec, limits : PodResourceVec }

let ComputeHeadroomReason =
      < VerticalGrowth : { horizon : Storage.FiniteDuration }
      | BurstAbsorption
      | NeighbourIsolation
      | DefragmentationReserve
      >

let ResidualizedPodResourceVec =
      { cpu : < Zero | Remaining : { millis : Natural } >
      , memory : < Zero | Remaining : Storage.ByteQuantity >
      , ephemeralStorage : < Zero | Remaining : Storage.ByteQuantity >
      }

let ComputeHeadroomDemand =
      { reason : ComputeHeadroomReason, pad : ResidualizedPodResourceVec }

let ContainerLifecycle = < App | Sidecar | Init | RestartableInit >

let RootFilesystem =
      < ReadOnlyRootfs | WritableRootfs : { allowance : Storage.ByteQuantity } >

let ContainerEnvelope =
      { id : Text
      , lifecycle : ContainerLifecycle
      , image : Image.ImageArtifact
      , process : Image.ContainerProcess
      , runtimeMemoryWorkingSet : Storage.ByteQuantity
      , privateEphemeral :
          { rootFilesystem : RootFilesystem
          , logHeadroom : Storage.ByteQuantity
          }
      , resources : Resources
      }

let KubeletMappedFileDemand =
      { id : Text
      , source : < ConfigMap | Secret | DownwardApi | ServiceAccountToken >
      , payloadBytes : Storage.ByteQuantity
      , accounting : < NodefsEphemeral | Memory >
      , model : Text
      }

let PodRuntimeMetadataSource =
      { networkAttachments : NonEmpty Text
      , mounts : List { key : Text, container : Text, volume : Text }
      }

let DiskBackedPodVolume = { id : Text, sizeLimit : Storage.ByteQuantity }

let MemoryBackedPodVolume =
      { id : Text
      , sizeLimit : Storage.ByteQuantity
      , persistence : < StageLocal : Text | PodLifetime >
      , access : NonEmpty { container : Text, mode : < ReadOnly | ReadWrite > }
      }

let PodLocalStorageDemand =
      { diskBackedVolumes : List DiskBackedPodVolume
      , mappedFiles : List KubeletMappedFileDemand
      , memoryBackedVolumes : List MemoryBackedPodVolume
      }

let VramShard = { id : Text, bytes : Storage.ByteQuantity }

let AcceleratorInterconnectRequirement =
      < NoPeerRequirement | FullyConnectedPeerAccess | FullyConnectedNvLink >

let ShardingPlan =
      { shards : NonEmpty VramShard
      , interconnect : AcceleratorInterconnectRequirement
      }

let AcceleratorWorkloadClass =
      < ServedModel | TrainingJob | JitCompilation | LibraryWork >

let AcceleratorWorkloadSource =
      < ServedModel : Text
      | TrainingJob : Text
      | JitCompilation : Text
      | LibraryWork : Text
      >

let AcceleratorResidencyClass =
      < Weights
      | ServingKvCache
      | Activations
      | OptimizerState
      | JitWorkspace
      | LibraryWorkspace
      >

let AcceleratorResidencyPlacement =
      < Unsharded | ReplicatedPerDevice | Sharded : ShardingPlan >

let AcceleratorResidencyDemand =
      { id : Text
      , class : AcceleratorResidencyClass
      , bytes : Storage.ByteQuantity
      , placement : AcceleratorResidencyPlacement
      }

let AcceleratorCoexistencePolicy =
      { maxResidentByClass : NonEmpty (Entry AcceleratorWorkloadClass Natural)
      , maxRunningByClass : NonEmpty (Entry AcceleratorWorkloadClass Natural)
      , model : Text
      }

let CudaWorkloadDemand =
      { residency : NonEmpty (Entry Text AcceleratorResidencyDemand) }

let MetalResidencyDemand =
      { class : AcceleratorResidencyClass, bytes : Storage.ByteQuantity }

let MetalWorkloadDemand =
      { residency : NonEmpty (Entry Text MetalResidencyDemand) }

let CudaOwnerDemand =
      { profile : Text
      , devices : Natural
      , sources : NonEmpty (Entry Text AcceleratorWorkloadSource)
      , workloads : NonEmpty (Entry Text CudaWorkloadDemand)
      , coexistence : AcceleratorCoexistencePolicy
      }

let MetalOwnerDemand =
      { profile : Text
      , sources : NonEmpty (Entry Text AcceleratorWorkloadSource)
      , workloads : NonEmpty (Entry Text MetalWorkloadDemand)
      , coexistence : AcceleratorCoexistencePolicy
      }

let PodAcceleratorDemand =
      < None | Cuda : { owner : Text, demand : CudaOwnerDemand } >

let HostAcceleratorDemand =
      < None | Cuda : CudaOwnerDemand | AppleMetal : MetalOwnerDemand >

let PodResourceEnvelope =
      { containers : NonEmpty ContainerEnvelope
      , overhead : Optional PodResourceVec
      , headroom : Optional ComputeHeadroomDemand
      , podLocal : PodLocalStorageDemand
      , runtimeMetadata : PodRuntimeMetadataSource
      , durable : List Storage.DeclaredVolumeDemand
      , cache : Optional Storage.InClusterCacheDemand
      , accelerator : PodAcceleratorDemand
      }

let HostResourceVec =
      { cpu : { millis : Natural }, memory : Storage.ByteQuantity }

let ResidualizedHostResourceVec =
      { cpu : < Zero | Remaining : { millis : Natural } >
      , memory : < Zero | Remaining : Storage.ByteQuantity >
      }

let HostComputeHeadroomDemand =
      { reason : ComputeHeadroomReason, pad : ResidualizedHostResourceVec }

let HostResources =
      { requests : HostResourceVec
      , limits : HostResourceVec
      , headroom : Optional HostComputeHeadroomDemand
      }

let HostResourceEnvelope =
      { process : Image.ContainerProcess
      , resources : HostResources
      , localBacking : Text
      , cache : Optional Storage.HostCacheDemand
      , accelerator : HostAcceleratorDemand
      }

let ResourceEnvelope =
      < Pod : PodResourceEnvelope | Host : HostResourceEnvelope >

let NodeEligibilityConstraint =
      < EngineRole : < ControlPlane | Worker >
      | ProviderClass : Text
      | Site : Text
      | AcceleratorProfile : Text
      | CarriesTaint : Text
      >

let NodeEligibilitySelector = { allOf : List NodeEligibilityConstraint }

let Cardinality = < Once | Replicated : { desiredReplicas : Natural } >

let DeploymentRollout =
      < Recreate
      | RollingUpdate : { maxSurge : Natural, maxUnavailable : Natural }
      >

let StatefulSetRollout =
      < OnDelete | RollingUpdate : < NativeSerialPartitionZero > >

let DaemonSetRollout =
      < OnDelete | RollingUpdate : < Surge : Natural | Unavailable : Natural > >

let Controller =
      < Deployment : { cardinality : Cardinality, rollout : DeploymentRollout }
      | StatefulSet :
          { cardinality : Cardinality, rollout : StatefulSetRollout }
      | DaemonSet :
          { selector : NodeEligibilitySelector, rollout : DaemonSetRollout }
      | Job :
          { completions : Natural
          , parallelism : Natural
          , backoffLimit : Natural
          , podRestartPolicy : < Never >
          , podReplacementPolicy : < Failed >
          , terminalRetention :
              { horizon : Storage.FiniteDuration, model : Text }
          }
      | HostProcess : { cardinality : < Once | PerNode >, replacement : Text }
      >

let ExecutionUnitIntent =
      { id : Text
      , revision : Natural
      , controller : Controller
      , resource : ResourceEnvelope
      }

let ZooKeeperMetadataEntryDemand =
      { path : Text
      , maxPayloadBytes : Storage.ByteQuantity
      , lifetime : < Persistent | SessionEphemeral : Text >
      }

let ZooKeeperChurnBudget =
      { maxTransactionsPerWindow : Natural
      , transactionWindow : Storage.FiniteDuration
      , maxConcurrentSessions : Natural
      , maxWatches : Natural
      , retainedSnapshots : Natural
      , retainedTransactionLogs : Natural
      , maxUnavailableMembers : Natural
      }

let ZooKeeperMemberDemand =
      { id : Text
      , resource : PodResourceEnvelope
      , volume : Storage.DeclaredVolumeDemand
      }

let ZooKeeperMetadataStoreDemand =
      { members : NonEmpty ZooKeeperMemberDemand
      , entries : NonEmpty ZooKeeperMetadataEntryDemand
      , churn : ZooKeeperChurnBudget
      , model : Text
      }

let PulsarMetadataStoreDemand = < ZooKeeper : ZooKeeperMetadataStoreDemand >

in  { PodResourceVec
    , Resources
    , ComputeHeadroomReason
    , ComputeHeadroomDemand
    , ContainerLifecycle
    , RootFilesystem
    , ContainerEnvelope
    , KubeletMappedFileDemand
    , PodRuntimeMetadataSource
    , PodLocalStorageDemand
    , VramShard
    , ShardingPlan
    , AcceleratorWorkloadClass
    , AcceleratorWorkloadSource
    , AcceleratorResidencyClass
    , AcceleratorResidencyPlacement
    , AcceleratorResidencyDemand
    , AcceleratorCoexistencePolicy
    , CudaWorkloadDemand
    , MetalResidencyDemand
    , MetalWorkloadDemand
    , CudaOwnerDemand
    , MetalOwnerDemand
    , PodAcceleratorDemand
    , HostAcceleratorDemand
    , PodResourceEnvelope
    , HostResources
    , HostComputeHeadroomDemand
    , HostResourceEnvelope
    , ResourceEnvelope
    , NodeEligibilityConstraint
    , NodeEligibilitySelector
    , Cardinality
    , DeploymentRollout
    , StatefulSetRollout
    , DaemonSetRollout
    , Controller
    , ExecutionUnitIntent
    , ZooKeeperMetadataEntryDemand
    , ZooKeeperChurnBudget
    , ZooKeeperMemberDemand
    , ZooKeeperMetadataStoreDemand
    , PulsarMetadataStoreDemand
    }
