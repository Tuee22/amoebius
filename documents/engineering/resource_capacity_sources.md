# Resource Capacity Sources and Boundaries

> **Purpose**: Where every capacity number comes from — declared in pure input, provisioned before render, cross-checked at runtime — and what the capacity model deliberately does not own.
> **Read this if**: a number in the capacity model has to be traced to its source, or a boundary of the model has to be settled.

This slice of the resource-capacity family carries the three loci a number passes through and the explicit
non-ownership boundaries. It does not carry the folds that consume those numbers, owned by
[resource_capacity_folds.md](./resource_capacity_folds.md). The honesty rule governing which locus may be
claimed as evidence is owned by
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_11_provision_seal.md, documents/engineering/monitoring_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/resource_capacity_folds.md, documents/engineering/resource_capacity_types.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Phase-run and implementation-result statements predate the 2026-08-11 reopen unless the owning phase is Done; target doctrine remains normative, and current state is in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [8. Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime](#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)
- [9. What this doctrine deliberately does not own](#9-what-this-doctrine-deliberately-does-not-own)
- [Related Documents](#related-documents)

---

## 8. Where the numbers come from: declared in pure input, provisioned before render, cross-checked at runtime

For overcommit to be a pure checked rejection rather than only a runtime error, the capacity the fold checks
against must be a **pure-model input** — a demand cannot be provisioned against a number learned only after
effects. amoebius therefore **declares** capacity in the spec/inventory model, completes bind/expansion, runs
the fold at the Phase-11 `provision-seal`, and then **cross-checks** the declaration against reality at
reconcile (runtime-checked). Gate-2 decode never constructs `ProvisionedSpec`.

- **Declared in pure input; checked at the provision seal.** Each host/node advertises an **allocatable**
  `Capacity` in the substrate node
  inventory ([substrate_doctrine.md §8](./substrate_doctrine.md#8-the-node-inventory-the-single-owner-of-hosts-capacity-and-taints)) —
  CPU, memory, logical pod-local ephemeral storage, a closed kubelet filesystem layout with named physical
  backing(s), a pinned content/snapshot storage model, disjoint
  retained/native-host-cache backing pools, and a closed accelerator offering containing a non-empty device
  vector with family/profile and per-device raw/reserved/allocatable VRAM.
  In-cluster cache remains nested in pod ephemeral rather than advertised as another backing.
  Kube/system-reserved and eviction headroom are already netted out; engine/control-plane DB, snapshot, Event,
  audit, and runtime-log bytes are derived explicitly inside `EngineSystemReserve`, while OCI content,
  snapshotter bytes, pod scratch/logs, and writable layers are routed to the layout's explicit filesystem
  backing(s). These are not raw hardware figures. Each provider candidate node class declares the
  corresponding **per-instance template** shape (never pre-existing physical ids), and each cloud account declares
  node/storage quotas ([pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md)); each `StorageBacking` declares its
  physical size or its provider-object selected-unit byte/count maximum. The [§4](./resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting) fold runs over these declarations after
  bind/expand during pure provisioning, so an over-committed or capability-mismatched target never produces
  a `ProvisionedSpec`.

At reconcile, “observed capacity” is not merely those totals. It is a snapshot containing the supply and
every allocation that can survive into the planned transition:

```text
ObservedNodeFilesystemCapacity =
  { carve             : DiskCarveId
  , backing           : RuntimeOrStorageBackingId
  , rawCapacity       : StorageCapacity
  , mountedUsableBytes: Quantity Bytes
  , presentation      : VolumePresentation
  , readback          :
      NodeFilesystemDeviceRawMountedUsablePresentationReadbackWitness
  , fingerprint       : InventoryFingerprint
  , sourceEquality    :
      NodeFilesystemCarveBackingRawUsablePresentationSnapshotEqualityWitness
  }

ObservedNodeCapacity =
  { node             : NodeId
  , declared         : NodeCapacity
  , allocatableCpu      : Quantity Cpu
  , allocatableMemory   : Quantity Bytes
  , allocatablePodSlots : PositiveNatural
  , allocatableCniSlots : Map CniDriverId Natural
  , allocatableCsiSlots : Map CsiDriverId Natural
  , allocatablePodEphemeral : Quantity Bytes
  , storageCarves     : Map DiskCarveId ObservedNodeFilesystemCapacity
  , storageCarveKeys  :
      ObservedNodeFilesystemMapKeyEmbeddedCarveEqualityWitness
  , cudaDevices      : Map AcceleratorDeviceId ObservedAcceleratorDevice
  , sourceEquality   : ObservedNodeDeclaredResidualIdentityEqualityWitness
  , fingerprint      : InventoryFingerprint
  }

ObservedCapacity =
  { topology         : TopologyFingerprint
  , nodes            : Map NodeId ObservedNodeCapacity
  , providerAccounts : Map CloudAccountId ObservedProviderAccount
  , storageBackings  : Map BackingId SharedBackingSupply
  , apiEtcdAllocatable : Quantity Bytes
  , nodeKeyEquality  : ObservedNodeCapacityKeyEqualityWitness
  , accountKeyEquality : ObservedProviderAccountMapKeyIdentityEqualityWitness
  , backingKeyEquality : ObservedSharedBackingMapKeyEmbeddedIdentityEqualityWitness
  , fingerprint      : InventoryFingerprint
  , sourceEquality   :
      ObservedCapacityTopologyNodeAccountBackingApiEtcdFingerprintEqualityWitness
  }

ProviderQuotaUsage =
  { instances        : Natural
  , vcpu             : Residual Vcpu
  , accelerators     : Map AcceleratorProfile Natural
  , nodeRootBytes    : Residual Bytes
  , nodeRootVolumes  : Natural
  , durableBytes     : Residual Bytes
  , durableVolumes   : Natural
  }

ProviderQuotaResidual = ProviderQuotaUsage

ObservedProviderObjectQuota =
  { quota               : StorageQuota
  , currentBytes        :
      ProviderObjectByteAmount quota.accounting (Residual Bytes)
  , currentObjectCount  : Natural
  , residualBytes       :
      ProviderObjectByteAmount quota.accounting (Residual Bytes)
  , residualObjectCount : Natural
  , partitionExact      :
      ProviderObjectQuotaSelectedUnitMaximumCurrentResidualByteAndCountEqualityWitness
  , completeInventory   :
      ProviderObjectQuotaCompleteSelectedUnitAndObjectCountAccountInventoryWitness
  , fingerprint         : InventoryFingerprint
  , sourceEquality      :
      ProviderObjectQuotaAccountAccountingUsageResidualSnapshotEqualityWitness
  }

ObservedProviderAccount =
  { account          : CloudAccountId
  , declared         : ProviderQuota
  , currentUsage     : ProviderQuotaUsage
  , residual         : ProviderQuotaResidual
  , partitionExact   : ProviderQuotaDeclaredUsageResidualEqualityWitness
  , catalogVersion   : ProviderCatalogVersion
  , offerings        : Map ProviderNodeClassId ObservedProviderNodeClassOffering
  , offeringKeys     : ObservedProviderNodeClassMapKeyIdentityEqualityWitness
  , objectStorageQuotas : Map ProviderStorageQuotaId ObservedProviderObjectQuota
  , objectQuotaKeys  : ObservedProviderObjectQuotaMapKeyEmbeddedIdentityEqualityWitness
  , observation      : ProviderReadOnlyQuotaAndUsageObservationWitness
  , fingerprint      : InventoryFingerprint
  , sourceEquality   :
      ProviderAccountQuotaUsageCatalogOfferingObjectQuotaWholeSnapshotEqualityWitness
  }

ObservedProviderNodeClassOffering =
  { class          : ProviderNodeClassId
  , sku            : ProviderSkuRef
  , zones          : NonEmpty Zone
  , price          : Price
  , quotaVcpu      : Quantity Vcpu
  , allocatable    : ProviderNodeCapacityTemplate
  , catalogVersion : ProviderCatalogVersion
  , rawShapeReadback:
      ProviderRawCpuMemoryDiskAcceleratorAndLinkObservationWitness
  , sourceEquality :
      ProviderClassSkuZonePriceQuotaCapacityCatalogEqualityWitness
  , fingerprint    : InventoryFingerprint
  }

LiveCommitmentOwner =
  < ForeignPod       : ForeignCommitmentId
  | BootstrapUnit    : ExecutionUnitId
  | TenantExecutor   : TenantPolicyExecutorKey
  | ExistingExecution: ObservedExecutionId
  >

LiveCommitment =
  { owner          : LiveCommitmentOwner
  , debit          : CompleteResourceReservation LiveCommitmentOwner
  , sourceEquality : LiveCommitmentOwnerTargetAxesEqualityWitness
  , fingerprint    : InventoryFingerprint
  }
-- Placement is debit.target/node; there is no optional sibling node field.

ObservedHostStorageChildCapacity =
  { identity         : HostStorageAllocationKey
  , parent           : PhysicalDiskBackingId
  , requiredUsableBytes : Quantity Bytes
  , allocatedRawBytes: Quantity Bytes
  , presentation     : VolumePresentation
  , quotaReadback    : HostStorageChildQuotaOrFixedExtentReadbackWitness
  , parentNesting    : HostStorageChildRawDebitParentEqualityWitness
  , fingerprint      : InventoryFingerprint
  , sourceEquality   :
      HostStorageChildIdentityParentUsableRawPresentationSnapshotEqualityWitness
  }

ObservedHostCapacity =
  { host             : HostId
  , declared         : PhysicalHostCapacity
  , allocatableCpu   : Quantity Cpu
  , allocatableMemory: Quantity Bytes
  , diskCapacities   : Map PhysicalDiskBackingId StorageCapacity
  , storageChildren  : Map HostStorageAllocationKey ObservedHostStorageChildCapacity
  , accelerator      : ObservedHostAcceleratorInventory
  , diskKeyEquality  : ObservedHostDiskMapKeyEmbeddedIdentityEqualityWitness
  , childKeyEquality : ObservedHostStorageChildMapKeyEmbeddedIdentityEqualityWitness
  , childParentDomain:
      ObservedHostEveryStorageChildJoinsOneDeclaredPhysicalPartitionWitness
  , sourceEquality   : ObservedHostDeclaredResidualIdentityEqualityWitness
  , fingerprint      : InventoryFingerprint
  }

HostCommitmentOwner =
  < ForeignProcess : ForeignHostProcessId
  | VirtualMachine : VmId
  >

HostCommitment =
  { owner          : HostCommitmentOwner
  , host           : HostId
  , debit          : CompleteHostResourceReservation HostCommitmentOwner
  , sourceEquality : HostCommitmentOwnerHostAxesEqualityWitness
  , fingerprint    : InventoryFingerprint
  }

ProviderObjectAllocationId =
  { object  : ObjectStoreObjectId
  , version : ObjectVersion
  }

BackingAllocationId =
  < HostRetained   : (BackingId, StatefulSetClaimSlot)
  | ProviderVolume : ProviderVolumeSlotId
  | ProviderObject : ProviderObjectAllocationId
  >

BackingAllocation =
  < HostRetained :
      { id             : BackingAllocationId
      , backing        : BackingId
      , claim          : StatefulSetClaimSlot
      , carve          : DiskCarveId
      , requiredUsable : Quantity Bytes
      , allocatedRaw   : Quantity Bytes
      , presentation   : VolumePresentation
      , readback       : HostBackingMountCapacityPresentationReadbackWitness
      , sourceEquality : HostBackingAllocationIdentityClaimCarveByteEqualityWitness
      , fingerprint    : InventoryFingerprint
      }
  | ProviderVolume :
      { id             : BackingAllocationId
      , volume         : MaterializedProvisionedEbsBacking
      , readback       : ProviderVolumeIdentityAccountZoneSizePresentationReadbackWitness
      , sourceEquality : ProviderBackingAllocationSlotVolumeDemandReadbackEqualityWitness
      , fingerprint    : InventoryFingerprint
      }
  | ProviderObject :
      { id             : BackingAllocationId
      , backing        : CloudQuotaBacking
      , bytes          :
          ProviderObjectByteAmount backing.quota.accounting (Quantity Bytes)
      , objectCount    : PositiveNatural
      , countEquality  : ProviderObjectAllocationObjectCountIsExactlyOneWitness
      , readback       : ProviderObjectVersionSelectedUnitByteAndCountReadbackWitness
      , sourceEquality :
          ProviderObjectAllocationKeyBackingQuotaAccountingByteCountEqualityWitness
      , fingerprint    : InventoryFingerprint
      }
  >

VolumeBackingAllocation =
  < HostRetained   : BackingAllocation.HostRetained
  | ProviderVolume : BackingAllocation.ProviderVolume
  >

ObservedInventory =
  { allocatable       : ObservedCapacity
  , foreignCommitments: Map LiveCommitmentOwner LiveCommitment
  , execution         : ObservedExecutionSet
  , schedulerReservations : ObservedSchedulerReservationLedger
  , schedulerReady    : ObservedCapacitySchedulerReady
  , managedNodeAuthority : ObservedManagedCapacityNodeAuthority
  , hostReservations  : Map HostId ObservedHostReservationLedger
  , nodeRuntimeStorage: ObservedNodeRuntimeStorageInventory
  , residentResources : ObservedResidentResourceBaseline
  , jobCompletions    : Map JobExecutionIdentityDigest ObservedJobCompletion
  , backingAllocations: Map BackingAllocationId BackingAllocation
  , hostCommitments   : Map (HostId, HostCommitmentOwner) HostCommitment
  , tenantPolicies    : ObservedTenantPolicyWholeDeploymentSnapshot
  , reconcilerLease   : ObservedMandatoryReconcilerLease
  , fingerprint       : InventoryFingerprint
  , resourceVersions  : Map KubernetesObjectId ResourceVersion
  , capacityBaseline  : ObservedAllocatableCommitmentPartitionWitness
  , jobCompletionKeys : ObservedJobCompletionMapKeyEqualityWitness
  , foreignCommitmentKeys :
      ObservedLiveCommitmentMapKeyOwnerEqualityWitness
  , backingAllocationKeys :
      ObservedBackingAllocationMapKeyEmbeddedIdentityEqualityWitness
  , hostCommitmentKeys :
      ObservedHostCommitmentMapKeyHostOwnerEqualityWitness
  , sourceEquality    : ObservedInventoryWholeSnapshotDomainFingerprintEqualityWitness
  }
-- ObservedCapacity/ObservedHostCapacity are total allocatable baselines, never already-netted "free" values.
-- The fold subtracts the exact normalized commitment union once. currentFreeVram is a point-in-time safety
-- cap applied as min(modelled headroom, currentFreeVram); no commitment is subtracted from it again.

ObservedSchedulerReservationLedger =
  { root           : ValidatedSchedulerLedgerRoot
  , observationJoin: SchedulerReservationObservationJoinWitness
  , rootOwnership  : SchedulerExclusiveRootWriterWitness
  }

SchedulerReservationObservationJoinWitness =
  { presentPods     : SchedulerReservationPodJoinWitness
  , absentRecovery  : StateIndexedLedgerOnlyAbsentRecoveryDomainWitness
  , completeDomain  :
      EveryEntryJoinsObservedPodOrStateIndexedLedgerOnlyAbsentRecoveryWitness
  }

CloudDnsRecordId =
  { account : CloudAccountId, zone : DnsZoneId, name : DnsName, recordType : DnsRecordType }

CloudCertificateId =
  { account : CloudAccountId, region : Region, name : CertificateName }

InfrastructureProviderActionId =
  { deployment : DeploymentId, generation : ProvisionGenerationDigest, ordinal : Natural }

CloudProviderActionId = InfrastructureProviderActionId

CloudCertificateIssuer =
  { account         : CloudAccountId
  , authority       : ContentAddress
  , validation      : < Dns01 : NonEmpty DnsZoneId >
  , sourceEquality  :
      CertificateIssuerAccountAuthorityValidationZoneEqualityWitness
  }

CertificateRenewalPolicy =
  { renewBefore       : FiniteDuration
  , replacementOverlap: FiniteDuration
  , minimumValidity   : FiniteDuration
  , timing            :
      CertificateRenewBeforeOverlapAndMinimumValidityOrderingWitness
  }

ChildClusterEndpoint =
  { apiDnsName      : DnsName
  , apiPort         : PositiveNatural
  , caBundleDigest  : ContentAddress
  , clusterIdentity : ContentAddress
  , sourceEquality  :
      ChildClusterApiDnsPortCaAndAuthenticatedIdentityEqualityWitness
  }

CloudProviderResourceKind =
  < ChildClusterKind | ManagedNodeKind | DurableVolumeKind | DnsRecordKind | CertificateKind >

CloudProviderResourceId kind =
  < ChildCluster   : ClusterId              -- kind = ChildClusterKind
  | ManagedNode    : ProviderInstanceId     -- kind = ManagedNodeKind
  | DurableVolume  : ProviderVolumeSlotId   -- kind = DurableVolumeKind
  | DnsRecord      : CloudDnsRecordId       -- kind = DnsRecordKind
  | Certificate    : CloudCertificateId     -- kind = CertificateKind
  >

SomeCloudProviderResourceId =
  { kind     : CloudProviderResourceKind
  , identity : CloudProviderResourceId kind
  }

ProvisionedManagedNodeRequest =
  { instance        : ProviderInstanceId
  , candidate       : CandidateNodeClass
  , rootVolumes     : Map DiskTemplateId ProvisionedNodeRootVolumeRequest
  , rootVolumeKeys  : ManagedNodeRootVolumeMapKeyDiskTemplateEqualityWitness
  , sourceEquality  :
      ManagedNodeInstanceCandidateRootVolumeDomainEqualityWitness
  }
-- The managed-node action is the sole owner of its root-volume requests and debit. There is no independent
-- NodeRootVolume operation arm; its enclosing ProvisionedCloudProviderAction owns the one combined
-- instance/root quota debit, and materialization returns exact root-volume results nested under this node.

ProvisionedChildClusterRequest =
  { cluster         : ClusterId
  , budget          : ClusterBudget
  , topology        : Topology
  , boundIntent     : BoundDeployment
  , postMaterializationSeal : Required
  , sourceEquality  :
      ChildClusterBudgetTopologyBoundIntentInfrastructureStageEqualityWitness
  }
-- A create request carries the exact bound child intent and disjoint budget, never a ProvisionedSpec for
-- infrastructure that does not exist yet. After the action is observed, its materialization constructs the
-- child's ProvisionContext; only then may provision seal that child ProvisionedSpec.

ProvisionedDnsRecordRequest =
  { identity       : CloudDnsRecordId
  , values         : NonEmpty DnsRecordValue
  , ttl            : FiniteDuration
  , sourceEquality : DnsIdentityValueTtlEqualityWitness
  }

ProvisionedCertificateRequest =
  { identity       : CloudCertificateId
  , dnsNames       : NonEmpty DnsName
  , issuer         : CloudCertificateIssuer
  , renewal        : CertificateRenewalPolicy
  , sourceEquality : CertificateIdentityDnsIssuerRenewalEqualityWitness
  }

PriorCloudResourceRef kind =
  { account        : CloudAccountId
  , resource       : CloudProviderResourceId kind
  , version        : ProviderObjectVersion
  , deployment     : DeploymentId
  , generation     : ProvisionGenerationDigest
  , requestDigest  : ContentAddress
  , sourceEquality : PriorCloudResourceAccountIdentityVersionGenerationEqualityWitness
  }

CloudEphemeralTransition kind request =
  < Create :
      { desired         : request
      , identity        : CloudProviderResourceId kind
      , identityEquality:
          CloudRequestPayloadResourceIdentityEqualityWitness kind request identity
      }
  | Replace :
      { prior   : PriorCloudResourceRef kind
      , desired : request
      , identity: CloudProviderResourceId kind
      , identityEquality:
          CloudRequestPayloadResourceIdentityEqualityWitness kind request identity
      , priorDesiredIdentity : prior.resource == identity
      , retainPriorUntilReady : Required
      }
  | Delete :
      { prior        : PriorCloudResourceRef kind
      , ephemeral    : EphemeralCloudResourceDeletionWitness
      , dependentsGone: Required
      }
  >

ProvisionedCloudOperation =
  < ChildCluster :
      CloudEphemeralTransition ChildClusterKind ProvisionedChildClusterRequest
  | ManagedNode :
      CloudEphemeralTransition ManagedNodeKind ProvisionedManagedNodeRequest
  | DurableVolume :
      < EnsurePresent : PromisedProvisionedEbsBacking >
  | DnsRecord :
      CloudEphemeralTransition DnsRecordKind ProvisionedDnsRecordRequest
  | Certificate :
      CloudEphemeralTransition CertificateKind ProvisionedCertificateRequest
  >

CloudResourceReadinessRule =
  < ChildClusterApiAuthenticated
  | ManagedNodeJoinedAndReady
  | DurableVolumeCreatedAndReadable
  | DnsRecordConverged
  | CertificateIssuedAndUsable
  >

CloudReplacementReadinessRequirement =
  { replacements    :
      NonEmptyMap SomeCloudProviderResourceId CloudResourceReadinessRule
  , keyArmEquality  :
      CloudReplacementResourceKindMatchesReadinessRuleArmWitness
  , stableFor       : FiniteDuration
  , sourceEquality  :
      CloudReplacementResourceDomainRuleAndStabilityEqualityWitness
  }

CloudProviderCleanupRequirement =
  < None
  | RetainPriorUntilReplacementReady :
      { resources : NonEmptySet SomeCloudProviderResourceId
      , readiness : CloudReplacementReadinessRequirement
      , domainEquality :
          CleanupRetainedResourceSetEqualsReplacementReadinessMapDomainWitness
      }
  >

ProviderObjectVersion = ContentAddress
ObservedPulumiCheckpointDigest = ContentAddress
ObjectVersion = ProviderObjectVersion

PostMaterializationSealState = < AwaitingPostMaterializationProvisionSeal >

ObservedCloudChildClusterMaterialization =
  { cluster        : ClusterId
  , infrastructureGeneration : ProvisionGenerationDigest
  , endpoint       : ChildClusterEndpoint
  , providerState  : NonEmptyMap SomeCloudProviderResourceId ProviderObjectVersion
  , providerStateKeys :
      CloudChildProviderStateMapKeyResourceIdentityEqualityWitness
  , sealState      : PostMaterializationSealState
  , sourceEquality :
      CloudChildClusterInfrastructureGenerationEndpointProviderStateEqualityWitness
  }

ObservedSshHostChildClusterMaterialization =
  { host           : HostId
  , cluster        : ClusterId
  , infrastructureGeneration : ProvisionGenerationDigest
  , endpoint       : ChildClusterEndpoint
  , hostStateVersion : ProviderObjectVersion
  , sealState      : PostMaterializationSealState
  , sourceEquality :
      SshHostChildClusterInfrastructureGenerationEndpointHostStateEqualityWitness
  }

ObservedChildInfrastructureMaterialization =
  < Cloud   : ObservedCloudChildClusterMaterialization
  | SshHost : ObservedSshHostChildClusterMaterialization
  >

ObservedSshHostChildClusterAbsence =
  { host           : HostId
  , cluster        : ClusterId
  , fingerprint    : InventoryFingerprint
  , readback       : SshHostChildClusterAbsentReadbackWitness
  , sourceEquality :
      SshHostChildAbsenceIdentitySnapshotEqualityWitness
  }

ProviderNodeRootVolumeMaterializationResult =
  { request        : ProvisionedNodeRootVolumeRequest
  , volume         : ProviderVolumeId
  , readback       : ProviderVolumeIdentityAccountZoneSizePresentationReadbackWitness
  , cloudAction    : CloudProviderActionId
  , sourceEquality :
      NodeRootRequestManagedNodeActionProviderReadbackEqualityWitness
  }

ObservedManagedNodeMaterialization =
  { instance       : ProviderInstanceId
  , binding        : ObservedNodeTargetBinding
  , rootVolumes    : Map DiskTemplateId ProviderNodeRootVolumeMaterializationResult
  , rootVolumeKeys : ManagedNodeMaterializedRootVolumeMapKeyEqualityWitness
  , quotaDebit     : ProviderQuotaUsage
  , sourceEquality :
      ManagedNodeRequestBindingRootMaterializationQuotaEqualityWitness
  }

ObservedCloudDnsRecord =
  { request        : ProvisionedDnsRecordRequest
  , version        : ProviderObjectVersion
  , observedValues : NonEmpty DnsRecordValue
  , observedTtl    : FiniteDuration
  , readback       :
      CloudDnsIdentityValueTtlAndProviderVersionReadbackWitness
  , sourceEquality :
      CloudDnsRequestObservedValueTtlVersionEqualityWitness
  }

ObservedCloudCertificate =
  { request        : ProvisionedCertificateRequest
  , version        : ProviderObjectVersion
  , materialDigest : ContentAddress
  , usable         : Required
  , readback       :
      CloudCertificateIdentityDnsIssuerRenewalMaterialVersionReadbackWitness
  , sourceEquality :
      CloudCertificateRequestMaterialUsabilityVersionEqualityWitness
  }

CloudOperationResult operation =
  < ChildClusterPresent : ObservedCloudChildClusterMaterialization
  | ManagedNodePresent  : ObservedManagedNodeMaterialization
  | DurableVolumePresent: EbsBackingMaterializationResult
  | DnsRecordPresent    : ObservedCloudDnsRecord
  | CertificatePresent  : ObservedCloudCertificate
  | Deleted             : ObservedCloudResourceAbsenceWitness
  > -- private constructor selects the present arm matching operation, or Deleted only for a Delete transition

CloudProviderActionResult action =
  { action         : action.action
  , operation      : action.operation
  , result         : CloudOperationResult operation
  , sourceEquality : CloudActionOperationIndexedResultReadbackEqualityWitness
  }

SomeCloudProviderActionResult =
  { action         : ProvisionedCloudProviderAction
  , result         : CloudProviderActionResult action
  , sourceEquality :
      CloudProviderActionAndIndexedResultIdentityEqualityWitness
  }

ObservedPulumiExecutorResidualSupply =
  { compute          : PodComputeReservationPartitionAxes
  , podSlots         : Natural
  , cniSlots         : Map CniDriverId Natural
  , csiSlots         : Map CsiDriverId Natural
  , sourceEquality   :
      PulumiExecutorResidualComputePodCniCsiAxesEqualityWitness
  }

ObservedPulumiExecutorSlotCapacity =
  { deploy          : PulumiDeployId
  , target          : ProvisionedNodeTarget
  , available       : ObservedPulumiExecutorResidualSupply
  , fingerprint     : InventoryFingerprint
  , sourceEquality  :
      PulumiDeployTargetResidualComputePodCniCsiSlotSnapshotEqualityWitness
  }

ObservedPulumiVolumeBackingCapacity role =
  { provisioned       : ProvisionedPulumiExecutionVolume role
  , backing           : SharedVolumeBackingSupply
  , mountedUsableBytes: Quantity Bytes
  , residualRawBytes  : Residual Bytes
  , mountReadback     :
      PulumiVolumeRawMountedUsablePresentationAllocationReadbackWitness
  , fit               :
      PulumiRequiredUsableFitsMountedAndProvisionedRawDebitFitsResidualWitness
  , fingerprint       : InventoryFingerprint
  , sourceEquality    :
      PulumiProvisionedVolumeBackingUsableRawSnapshotEqualityWitness
  }

ObservedPulumiInClusterCacheCapacity =
  { budget               : CacheBudgetId
  , owner                : InClusterCacheOwner
  , target               : ProvisionedNodeTarget
  , physicalBacking      : ProvisionedRuntimeOrStorageBackingRef
  , logicalResidualBytes : Residual Bytes
  , physicalResidualBytes: Residual Bytes
  , backingArm           :
      InClusterCacheResolvesOnlyToTargetNodeFilesystemOrElasticNodeCarveWitness
  , fingerprint          : InventoryFingerprint
  , sourceEquality       :
      PulumiInClusterCacheBudgetOwnerVolumeTargetBackingResidualSnapshotEqualityWitness
  }

ObservedPulumiExecutorSlotVolumeCacheAndCommitmentSnapshot =
  { executorSlots   : Map PulumiDeployId ObservedPulumiExecutorSlotCapacity
  , pluginVolume    : ObservedPulumiVolumeBackingCapacity PluginVolume
  , workspaceVolume : ObservedPulumiVolumeBackingCapacity WorkspaceVolume
  , cacheBackings   : Map CacheBudgetId ObservedPulumiInClusterCacheCapacity
  , cacheKeys       : PulumiObservedCacheBackingMapKeyBudgetEqualityWitness
  , liveCommitments : Map LiveCommitmentOwner LiveCommitment
  , fingerprint     : InventoryFingerprint
  , sourceEquality  :
      PulumiExecutorResidualSlotVolumeInClusterCacheCommitmentWholeInventoryEqualityWitness
  }

ObservedCloudInfrastructureSnapshot =
  { accounts         : NonEmptyMap CloudAccountId ObservedProviderAccount
  , resources        : Map SomeCloudProviderResourceId ProviderObjectVersion
  , checkpoints      : Map PulumiStackId ObservedPulumiCheckpointDigest
  , parentInventory  : ObservedInventory
  , pulumiExecutionResources :
      ObservedPulumiExecutorSlotVolumeCacheAndCommitmentSnapshot
  , inventory        : InventoryFingerprint
  , keyEquality      : CloudInfrastructureMapKeyIdentityEqualityWitness
  , parentEquality   :
      CloudInfrastructureParentInventoryExecutorResourceSnapshotEqualityWitness
  , sourceEquality   :
      CloudInfrastructureAccountResourceCheckpointParentWholeSnapshotEqualityWitness
  }

ObservedSshHostInfrastructureSnapshot =
  { hosts            : NonEmptyMap HostId ObservedHostCapacity
  , childClusters    : Map ClusterId ObservedSshHostChildClusterMaterialization
  , checkpoints      : Map PulumiStackId ObservedPulumiCheckpointDigest
  , parentInventory  : ObservedInventory
  , pulumiExecutionResources :
      ObservedPulumiExecutorSlotVolumeCacheAndCommitmentSnapshot
  , fingerprint      : InventoryFingerprint
  , keyEquality      : SshHostInfrastructureMapKeyIdentityEqualityWitness
  , sourceEquality   :
      SshHostChildCheckpointParentExecutionWholeSnapshotEqualityWitness
  }

ObservedInfrastructureProviderSnapshot =
  { cloud            : Optional ObservedCloudInfrastructureSnapshot
  , sshHosts         : Optional ObservedSshHostInfrastructureSnapshot
  , nonEmpty         : AtLeastOneInfrastructureProviderSnapshotPresentWitness
  , sharedSnapshot   :
      PresentProviderSnapshotsShareParentInventoryExecutionCheckpointMapsAndFingerprintWitness
  , sourceEquality   :
      InfrastructureProviderSnapshotArmDomainAndWholeObservationEqualityWitness
  }
-- A generic batch may contain cloud and SSH-host actions. Its observation is therefore a non-empty product,
-- not an exclusive sum: every action arm must find its matching snapshot, and when both are present they
-- carry the same parent inventory, Pulumi execution observation, checkpoints, and fingerprint.

CloudOperationResourceId operation =
  { identity       : SomeCloudProviderResourceId
  , operationArm   : CloudResourceIdentityMatchesOperationFamilyWitness operation identity
  }

CloudProviderTargetObservation operation =
  { resources       : Map (CloudOperationResourceId operation)
      < Absent | Present : { version : ProviderObjectVersion, requestDigest : ContentAddress } >
  , operationDomain : CloudOperationObservedResourceDomainEqualityWitness operation
  }

CloudAccountMutationCapability =
  { account        : CloudAccountId
  , credential     : SecretRef
  , allowedActions : NonEmptySet CloudProviderActionId
  , allowedResources : NonEmptySet SomeCloudProviderResourceId
  , sourceEquality : CloudCredentialAccountActionResourceScopeEqualityWitness
  }

-- A backup write capability specializes CloudAccountMutationCapability: its allowedActions is a CLOSED
-- put-only record (a fixed set of Required write actions), so DeleteObject / ExpireObject / PutBucketLifecycle
-- have no place to go. amoebius can write backups but can never delete, expire, or lifecycle them; retention
-- and deletion are a distinct out-of-band credential class. Owned by backup_recovery_doctrine.md §4; the
-- create-vs-delete boundary it specializes is owned by pulumi_iac_doctrine.md §6.
BackupPutOnlyActions =
  { putObject : Required BackupPut
  }   -- no delete / expire / lifecycle field exists

BackupWriteCapability =
  { account        : CloudAccountId
  , credential     : SecretRef
  , allowedActions : BackupPutOnlyActions
  , medium         : BackupMediumRef
  , sourceEquality : BackupCredentialAccountMediumScopeEqualityWitness
  }

CloudMutationTokenState = < Fresh | Consumed >
SingleUseCloudMutationToken state =
  { action : CloudProviderActionId
  , snapshot : InventoryFingerprint
  , nonce  : ContentAddress
  , state  : state
  }

ProvisionedCloudProviderAction =
  { action          : CloudProviderActionId
  , account         : CloudAccountId
  , operation       : ProvisionedCloudOperation
  , deploy          : PulumiDeployId
  , checkpoint      : PulumiStackId
  , requestDigest   : ContentAddress
  , quotaDebit      : ProviderQuotaUsage
  , cleanup         : CloudProviderCleanupRequirement
  , sourceEquality  :
      CloudActionAccountOperationPayloadDigestQuotaDeployCheckpointCleanupEqualityWitness
  }

PriorSshHostChildClusterRef =
  { host           : HostId
  , cluster        : ClusterId
  , deployment     : DeploymentId
  , generation     : ProvisionGenerationDigest
  , requestDigest  : ContentAddress
  , observedVersion: ProviderObjectVersion
  , sourceEquality :
      PriorSshHostChildClusterIdentityGenerationDigestVersionEqualityWitness
  }

SshHostChildClusterTransition =
  < Create :
      { desired         : ProvisionedChildClusterRequest
      , cluster         : ClusterId
      , identityEquality:
          desired.cluster == cluster
      }
  | Replace :
      { prior   : PriorSshHostChildClusterRef
      , desired : ProvisionedChildClusterRequest
      , identityEquality:
          prior.cluster == desired.cluster
      , retainPriorUntilReady : Required
      }
  | Delete :
      { prior          : PriorSshHostChildClusterRef
      , dependentsGone : Required
      , ephemeral      : EphemeralChildClusterDeletionWitness
      }
  >

ProvisionedSshHostProviderAction =
  { action          : InfrastructureProviderActionId
  , host            : HostId
  , operation       : SshHostChildClusterTransition
  , deploy          : PulumiDeployId
  , checkpoint      : PulumiStackId
  , requestDigest   : ContentAddress
  , budget          : ClusterBudget
  , sourceEquality  :
      SshHostActionHostChildBudgetOperationDigestDeployCheckpointEqualityWitness
  }

SshHostMutationTokenState = < Fresh | Consumed >
SingleUseSshHostMutationToken state =
  { action   : InfrastructureProviderActionId
  , host     : HostId
  , snapshot : InventoryFingerprint
  , nonce    : ContentAddress
  , state    : state
  }

ConsumedInfrastructureProviderMutationToken =
  < Cloud :
      SingleUseCloudMutationToken Consumed
  | SshHost :
      SingleUseSshHostMutationToken Consumed
  >

SshHostProviderActionResult action =
  { action         : action.action
  , operation      : action.operation
  , result         :
      < ChildClusterPresent : ObservedSshHostChildClusterMaterialization
      | Deleted             : ObservedSshHostChildClusterAbsence
      >
  , operationArm   :
      SshChildClusterResultPresentOrDeleteMatchesTransitionWitness operation result
  , sourceEquality :
      SshHostActionOperationIndexedResultReadbackEqualityWitness
  }

SomeSshHostProviderActionResult =
  { action         : ProvisionedSshHostProviderAction
  , result         : SshHostProviderActionResult action
  , sourceEquality :
      SshHostProviderActionAndIndexedResultIdentityEqualityWitness
  }

InfrastructureProviderActionResult =
  < Cloud   : SomeCloudProviderActionResult
  | SshHost : SomeSshHostProviderActionResult
  >

infrastructureProviderResultActionId
  :: InfrastructureProviderActionResult
  -> InfrastructureProviderActionId
-- Total arm fold used by MaterializedInfrastructureState.providerResultKeys.

ProvisionedInfrastructureProviderAction =
  < Cloud   : ProvisionedCloudProviderAction
  | SshHost : ProvisionedSshHostProviderAction
  >

InfrastructureProviderActionBatchId =
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest
  , digest     : ContentAddress
  }

CloudActionBatchId = InfrastructureProviderActionBatchId

infrastructureProviderActionId
  :: ProvisionedInfrastructureProviderAction
  -> InfrastructureProviderActionId

infrastructureProviderActionDeploy
  :: ProvisionedInfrastructureProviderAction
  -> PulumiDeployId

infrastructureProviderActionCheckpoint
  :: ProvisionedInfrastructureProviderAction
  -> PulumiStackId
-- These are total arm folds over Cloud | SshHost. Generic batch construction never relies on an implicit
-- common record-field projection.

ProvisionedProviderActionBatch =
  { id               : InfrastructureProviderActionBatchId
  , actions          :
      NonEmptyMap InfrastructureProviderActionId ProvisionedInfrastructureProviderAction
  , actionKeys       : ProviderActionMapKeyEmbeddedIdentityEqualityWitness
  , execution        : ProvisionedPulumiExecutionDemand
  , checkpoints      : NonEmptyMap PulumiStackId ProvisionedPulumiCheckpointObjectDemand
  , checkpointKeys   : PulumiCheckpointMapKeyEmbeddedStackEqualityWitness
  , deployActions    :
      NonEmptyMap PulumiDeployId (NonEmptySet InfrastructureProviderActionId)
  , deployPartition  :
      EveryActionExactlyOneDeployAndEveryExecutionDeployCoveredWitness
  , deployCheckpoints: NonEmptyMap PulumiDeployId PulumiStackId
  , checkpointPartition:
      EveryDeployExactlyOneActionCheckpointAndEveryCheckpointCoveredWitness
  , dependencyCover  : ProviderActionDependencyOrderEqualsPulumiDeployGraphWitness
  , projectionEquality:
      ProviderBatchActionIdDeployCheckpointMapsEqualTotalArmProjectionsWitness
  , concurrency      : PulumiBatchConcurrencyAdmissionWitness
  , quotaPartition   :
      ProviderActionCloudQuotaRootVolumeAndSshClusterBudgetExactlyOncePartitionWitness
  , sourceEquality   :
      ProviderBatchIdentityArmActionDeployExecutionCheckpointDependencyBudgetWholeSourceEqualityWitness
  }
-- One batch owns one provisioned Pulumi graph, its checkpoint domain, dependency order, and concurrency.
-- Actions carry only an exact deploy id projection; they cannot duplicate or cross-pair an executor graph.

ProvisionedCloudActionBatch = -- opaque all-cloud refinement
  { batch          : ProvisionedProviderActionBatch
  , actions        : NonEmptyMap CloudProviderActionId ProvisionedCloudProviderAction
  , actionDomain   : CloudActionsExactlyEqualProviderBatchActionDomainWitness
  , sourceEquality : CloudActionRefinementBatchIdentityAndArmEqualityWitness
  }

ProvisionedStorageCapacityCloudAction = -- opaque refinement
  { action        : ProvisionedCloudProviderAction
  , operationArm  : action.operation == DurableVolume.EnsurePresent
  , sourceEquality:
      StorageCapacityBackingAccountQuotaBytesVolumesCloudActionEqualityWitness
  }

ProvisionedStorageCapacityCloudBatch = -- opaque refinement
  { batch          : ProvisionedCloudActionBatch
  , actions        : NonEmptyMap CloudProviderActionId ProvisionedStorageCapacityCloudAction
  , actionDomain   : StorageCapacityActionDomainEqualsBatchActionDomainWitness
  , sourceEquality :
      StorageCapacityActionsBackingQuotaBatchExecutionCheckpointEqualityWitness
  }

NoMutationCapability =
  { allowedEffect : None
  , required      : Required
  }

RetainedCarveAllocationCapability =
  { budget         : StorageBudgetId
  , backing        : BackingId
  , snapshot       : InventoryFingerprint
  , maximumRawDebit: Quantity Bytes
  , allocationDomain : NonEmptySet BackingAllocationId
  , sourceEquality :
      RetainedCarveBudgetBackingSnapshotDebitAllocationDomainEqualityWitness
  }

VerifiedStorageMigrationCapability =
  { migration      : ProvisionedStorageMigration
  , snapshot       : InventoryFingerprint
  , copyVerified   : Required
  , cutoverVerified: Required
  , retainOld      : Required
  , allowedEffect  : VerifiedMigrationCutoverWithoutAutomaticReclaim
  , sourceEquality :
      StorageMigrationSnapshotVerificationRetentionCapabilityEqualityWitness
  }

SameStorageSnapshotBeforeMutationRequirement =
  { fingerprint    : InventoryFingerprint
  , allocationIds  : Set BackingAllocationId
  , required       : Required
  }

SameCloudSnapshotBeforeMutationRequirement =
  { batch          : CloudActionBatchId
  , action         : CloudProviderActionId
  , fingerprint    : InventoryFingerprint
  , resourceVersions : Map SomeCloudProviderResourceId ProviderObjectVersion
  , required       : Required
  , sourceEquality :
      CloudBatchActionResourceVersionSnapshotRecheckEqualityWitness
  }

StorageScalingCreateProviderCapacityCapability transition =
  { validatedBatch  : ValidatedCloudActionBatch
  , batchEquality   :
      validatedBatch.batch == transition.actionBatch.batch
  , freshActionDomain:
      EveryValidatedBatchActionHasFreshCloudTokenAndEqualsStorageTransitionDomainWitness
  , sourceEquality  :
      StorageScalingTransitionValidatedCloudBatchSnapshotCapabilityEqualityWitness
  }

StorageScalingMutationCapability transition =
  < NoChange : NoMutationCapability
  | AllocateWithinRetainedCarve :
      RetainedCarveAllocationCapability
  | CreateProviderCapacity :
      StorageScalingCreateProviderCapacityCapability transition
  | ShrinkByVerifiedMigration :
      VerifiedStorageMigrationCapability
  > -- private constructor requires selected arm = transition

ObservedCloudProviderActionPrecondition action =
  { account          : ObservedProviderAccount
  , target           : CloudProviderTargetObservation action.operation
  , checkpointStack  : action.checkpoint
  , checkpointDigest : ObservedPulumiCheckpointDigest
  , checkpointSource :
      ObservedCheckpointStackDeployActionProjectionEqualityWitness
  , executionFit     : PulumiDeployFreshObservedParentCapacityFitWitness action.deploy
  , inventory        : InventoryFingerprint
  , resourceVersions : Map SomeCloudProviderResourceId ProviderObjectVersion
  , sourceEquality   :
      CloudActionAccountCatalogQuotaTargetCheckpointStackExecutionSnapshotEqualityWitness action
  }

ValidatedCloudProviderAction = -- opaque, single-use
  { batch            : CloudActionBatchId
  , action           : ProvisionedCloudProviderAction
  , batchProjection  :
      CloudActionExactBatchIdDeployExecutionCheckpointProjectionWitness
  , observed         : ObservedCloudProviderActionPrecondition action
  , capability       : CloudAccountMutationCapability
  , immediateRecheck : SameCloudSnapshotBeforeMutationRequirement
  , singleUse        : SingleUseCloudMutationToken Fresh
  , equality         :
      CloudActionBatchObservedAccountCapabilityCheckpointExecutionSnapshotEqualityWitness
  }

SshHostMutationCapability =
  { host           : HostId
  , credential     : SecretRef
  , allowedActions : NonEmptySet InfrastructureProviderActionId
  , allowedChildren: NonEmptySet ClusterId
  , sourceEquality :
      SshCredentialHostActionChildScopeEqualityWitness
  }

ObservedSshHostProviderActionPrecondition action =
  { host             : ObservedHostCapacity
  , child            :
      < Absent | Present : ObservedSshHostChildClusterMaterialization >
  , checkpointStack  : action.checkpoint
  , checkpointDigest : ObservedPulumiCheckpointDigest
  , executionFit     : PulumiDeployFreshObservedParentCapacityFitWitness action.deploy
  , inventory        : InventoryFingerprint
  , sourceEquality   :
      SshActionHostChildCheckpointExecutionSnapshotEqualityWitness action
  }

SameSshHostSnapshotBeforeMutationRequirement =
  { batch          : InfrastructureProviderActionBatchId
  , action         : InfrastructureProviderActionId
  , host           : HostId
  , child          : ClusterId
  , fingerprint    : InventoryFingerprint
  , required       : Required
  , sourceEquality :
      SshBatchActionHostChildSnapshotRecheckEqualityWitness
  }

ValidatedSshHostProviderAction =
  { batch            : InfrastructureProviderActionBatchId
  , action           : ProvisionedSshHostProviderAction
  , batchProjection  :
      SshActionExactBatchIdDeployExecutionCheckpointProjectionWitness
  , observed         : ObservedSshHostProviderActionPrecondition action
  , capability       : SshHostMutationCapability
  , immediateRecheck : SameSshHostSnapshotBeforeMutationRequirement
  , singleUse        : SingleUseSshHostMutationToken Fresh
  , sourceEquality   :
      SshActionBatchObservedCapabilityCheckpointExecutionSnapshotEqualityWitness
  }

ValidatedInfrastructureProviderAction =
  < Cloud   : ValidatedCloudProviderAction
  | SshHost : ValidatedSshHostProviderAction
  >

ValidatedInfrastructureActionBatch = -- sole owner of the provisioned execution/checkpoint graph
  { batch          : ProvisionedProviderActionBatch
  , actions        :
      NonEmptyMap InfrastructureProviderActionId ValidatedInfrastructureProviderAction
  , actionKeys     : ValidatedProviderActionMapKeyEmbeddedIdentityEqualityWitness
  , actionDomain   : ValidatedProviderActionDomainEqualsProvisionedBatchDomainWitness
  , snapshotCoverage:
      EveryCloudOrSshActionValidatedAgainstItsMatchingPresentSnapshotArmWitness
  , executionFit   : PulumiExecutionDemandFreshObservedCapacityFitWitness
  , snapshot       : InventoryFingerprint
  , sourceEquality :
      ValidatedProviderBatchProvisionedActionExecutionCheckpointSnapshotEqualityWitness
  }

ValidatedCloudActionBatch = -- opaque all-cloud validation refinement
  { validated      : ValidatedInfrastructureActionBatch
  , batch          : ProvisionedCloudActionBatch
  , batchEquality  : validated.batch == batch.batch
  , actions        : NonEmptyMap CloudProviderActionId ValidatedCloudProviderAction
  , actionKeys     : ValidatedCloudActionMapKeyEmbeddedIdentityEqualityWitness
  , actionDomain   :
      ValidatedCloudActionsExactlyEqualValidatedProviderBatchActionDomainWitness
  , sourceEquality :
      ValidatedCloudRefinementProviderBatchIdentityArmAndSnapshotEqualityWitness
  }

validateInfrastructureProviderActionBatch
  :: ObservedInfrastructureProviderSnapshot
  -> ProvisionedProviderActionBatch
  -> Either ProvisionError ValidatedInfrastructureActionBatch

validateCloudActionBatch
  :: ObservedCloudInfrastructureSnapshot
  -> ProvisionedCloudActionBatch
  -> Either ProvisionError ValidatedCloudActionBatch

ValidatedProviderAction provisioned capability = -- opaque snapshot-bound enactor input
  { action            : provisioned
  , observed          : TenantPolicyActionObservedPreconditionWitness
  , executorReady     : TenantPolicyExecutorReadyWitness
  , providerCapability: capability
  , cleanup           : ProviderCleanupRequirement
  , fingerprint       : InventoryFingerprint
  , equality          :
      ProviderActionPreconditionExecutorCapabilityCleanupSnapshotEqualityWitness
  }

ValidatedTenantPolicyAction =
  < Keycloak :
      ValidatedProviderAction
        (ProvisionedProviderAction KeycloakTenantPolicyTransition KeycloakPolicyTarget
          KeycloakPolicyOutput PatroniCapacityWitness)
        KeycloakMutationCapability
  | Vault :
      ValidatedProviderAction
        (ProvisionedProviderAction VaultTenantPolicyTransition VaultPolicyTarget
          VaultPolicyOutput VaultStorageWitness)
        VaultMutationCapability
  | Pulsar :
      ValidatedProviderAction
        (ProvisionedProviderAction PulsarTenantPolicyTransition PulsarPolicyTarget
          PulsarPolicyOutput ZooKeeperCapacityWitness)
        PulsarAdminMutationCapability
  | Minio :
      ValidatedProviderAction
        (ProvisionedProviderAction MinioTenantPolicyTransition MinioPolicyTarget
          MinioPolicyOutput MinioSystemMetadataGroupProvisionWitness)
        MinioAdminMutationCapability
  | Network :
      ValidatedProviderAction
        (ProvisionedProviderAction NetworkTenantPolicyTransition KubernetesApiPolicyTarget
          NetworkPolicyOutput EtcdLogicalCapacityWitness)
        KubernetesApiMutationCapability
  | Postgres :
      ValidatedProviderAction
        (ProvisionedProviderAction PostgresTenantPolicyTransition PostgresPolicyTarget
          PostgresPolicyOutput PatroniCapacityWitness)
        PostgresGrantMutationCapability
  >

LiveTargetMutationTokenState = < Fresh | Consumed >
SingleUseLiveTargetMutationToken state =
  { deployment : DeploymentId
  , generation : ProvisionGenerationDigest
  , inventory  : InventoryFingerprint
  , nonce      : ContentAddress
  , state      : state
  }

ValidatedLiveTarget = opaque private constructor
  { observation                 : ObservedLiveResourceSnapshot
  , inventoryFingerprint        : InventoryFingerprint
  , resourceVersions            : Map KubernetesObjectId ResourceVersion
  , tenantPolicyInventory       : TenantPolicyWholeDeploymentInventoryWitness
  , tenantPolicyContentDigests  : TenantPolicyContentDigestWitness
  , tenantPolicyActionExecution : TenantPolicyExecutionCapacityWitness
  , tenantPolicyActions         : Map TenantPolicyActionKey ValidatedTenantPolicyAction
  , tenantPolicyActionDomain    : TenantPolicyValidatedActionDomainWitness
  , tenantPolicyMinioStores     : Map ObjectStoreId MinioSystemMetadataStoreMergeWitness
  , executionInventory          : ObservedExecutionSourceEqualityWitness
  , schedulerReservations       : SchedulerReservationObservationJoinWitness
  , schedulerReady              : ObservedCapacitySchedulerReady
  , managedNodeAuthority        : ManagedNodePlacementAuthorityReadbackWitness
  , schedulerFold               : ReservationSetFold
  , executionCommitments        : ExecutionCommitmentDedupWitness
  , hostReservations            : Map HostId HostReservationSetFold
  , hostReservationDomain       : HostReservationFoldDomainWitness
  , observedRuntimeStorage      : Map ProvisionedNodeTarget ProvisionedObservedNodeRuntimeStorageAccounting
  , observedRuntimeStorageEquality : ObservedRuntimeStorageDomainWitness
  , schedulerLedgerVersion      : (ResourceVersion, SchedulerLedgerCasVersion)
  , executionTransitions        : Map ExecutionUnitId ValidatedExecutionTransitionAction
  , executionTransitionDomain   : ExecutionTransitionActionDomainWitness
  , cloudBatches                : Map CloudActionBatchId ValidatedCloudActionBatch
  , cloudBatchKeys              :
      ValidatedRuntimeCloudBatchMapKeyEmbeddedIdentityEqualityWitness
  , cloudObservation            : observation.cloud
  , cloudObservationPresence    :
      CloudSnapshotPresentExactlyWhenRuntimeCloudActionDomainIsNonEmptyWitness
  , cloudActionDomain           :
      RuntimeCloudBatchNestedActionAndScalingPlanDomainEqualityWitness
  , storageScalingActions       : Map StorageScalingPlanId ValidatedStorageScalingAction
  , storageScalingActionDomain  :
      ProvisionedScalingEnvelopeObservedSnapshotValidatedPlanDomainEqualityWitness
  , jobCompletionInventory      : JobCompletionInventoryWitness
  , reconcilerLease             : ValidatedMandatoryReconcilerLease
  , provision                   : ProvisionedSpec
  , sourceEquality              :
      ValidatedLiveTargetObservedWholeInventoryProvisionActionDomainEqualityWitness
  , singleUse                   : SingleUseLiveTargetMutationToken Fresh
  }

LiveTargetConsumptionReceipt =
  { deployment          : DeploymentId
  , generation          : ProvisionGenerationDigest
  , inventory           : InventoryFingerprint
  , targetToken         : SingleUseLiveTargetMutationToken Consumed
  , cloudTokens         : Map
      CloudProviderActionId (SingleUseCloudMutationToken Consumed)
  , cloudTokenKeys      :
      LiveConsumedCloudTokenMapKeyActionDomainEqualityWitness
  , storageScalingTokens: Map
      StorageScalingPlanId (SingleUseStorageScalingActionToken Consumed)
  , storageTokenKeys    :
      LiveConsumedStorageTokenMapKeyPlanDomainEqualityWitness
  , typedActionTokens   :
      ExecutionJobTenantHostSchedulerLeaseTypedActionConsumptionWitness
  , consumptionCas      : LiveTargetFreshToConsumedCompareAndSwapWitness
  , sourceEquality      :
      LiveTargetProvisionInventoryNestedActionConsumedTokenEqualityWitness
  }

LiveTargetEnactmentResult =
  < Applied :
      { receipt         : LiveTargetConsumptionReceipt
      , postObservation : ObservedInventory
      , equality        :
          LiveReceiptPostObservationProvisionActionEffectEqualityWitness
      }
  | OutcomeUnknown :
      { receipt         : LiveTargetConsumptionReceipt
      , reobserve       : RequireFreshWholeInventoryObservationBeforeAnyRetry
      , equality        :
          LiveAmbiguousOutcomeReceiptAttemptedActionDomainEqualityWitness
      }
  >

LivePreEnactmentError =
  < LiveInventoryChanged
  | LiveTargetAlreadyConsumed
  | LiveMutationCapabilityUnavailable
  | LiveTargetConsumptionCasConflict
  >

enactLiveTarget
  :: ValidatedLiveTarget
  -> Either LivePreEnactmentError LiveTargetEnactmentResult
-- Left is permitted only before the consumption CAS and proves zero effects. Once any effect may have been
-- attempted, the function returns Applied or OutcomeUnknown with the consumed receipt.
```

### Supply cross-check (runtime-checked)

Before any mutation, reconcile refuses if the *real* probed
**allocatable** capacity/capability is smaller or incompatible with the declaration (a host that claims
64 GiB memory but has 32, a node whose kubelet exposes less logical ephemeral storage, a runtime whose
discovered nodefs/imagefs/containerfs mount/device/quota identities or capacities disagree with the selected
layout, a CUDA node with fewer devices
or less per-device net usable VRAM after its mandatory reserve, or a missing device-plugin extended resource),
fail-closed like every other
`Unreachable → refuse` observation ([cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)).
Comparing *allocatable* against *allocatable* is what keeps the guarantee honest: declaring raw capacity would
let the fold "prove" an overcommit-free cluster that still evicts once the kubelet's reservation is subtracted.
The declaration is a *ceiling the fold trusts*, and reality must be at least that generous or the deploy
refuses. The accelerator probe records raw total and current free memory separately: raw total cross-checks
the device identity/reserve boundary, while live residual admission spends at most the lesser of declared
allocatable headroom and `currentFreeVram : Residual Bytes` after accounting for normalized surviving
claims. `Zero` is a valid observation and admits no demand. It
never treats `memory.total` or a product-model label as free capacity. Detection of the real number is owned by
[substrate_doctrine.md §2](./substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads);
this doc owns only the requirement that the cross-check exist and its layer.

### Residual/transition admission (runtime-checked)

The renderer/reconciler first computes desired objects,
reads live objects and allocations without mutation, and derives a transition envelope. The snapshot
explicitly includes the state-indexed PodUID/host-process execution map, scheduler and host reservation
ledgers, managed-node authority/readiness, observed runtime roots/components, and the resident-artifact
baseline. Map key, embedded identity, reservation owner/state/vector, controller-child discriminator, and
no-orphan checks run before capacity subtraction. The singleton scheduler root contains all mutable entries
plus retained resident debits; its resourceVersion/CAS version and every observation fingerprint participate
in the inventory token. `place` is rerun
against `observed allocatable − surviving commitments`, not against the raw allocatable total: preserved
amoebius pods contribute their reserved total, request and pad both, since a surviving row that surrendered
its headroom on reconcile would let a second workload pack into space the first still holds. Preserved
foreign/system pods have no envelope and therefore no pad; they
contribute their effective CPU/memory/ephemeral requests, finite-policy CPU limits,
memory bounds, ephemeral eviction ceilings, device claims, and bounded volumes. The physical fold separately
routes their disk volumes/logs/writable layers and independently observed kubelet/runtime metadata components
through `KubeletNodefs | CriRuntimeRoot` and the selected
`Unified | SplitRuntime | SplitImage` role-to-backing resolver. The allocation-domain-scoped digest union of resident/old/new
CRI content objects and chain-id union of committed/active snapshots debit the appropriate residual backing
once whether pinned or currently unreferenced; only missing pulls/imports add workspace;
durable/native-cache allocations and
physical-host VM/process commitments — including active builder CPU/memory/scratch/cache — debit their named
backing/host. Unchanged owned pods are counted once. Planned slots remain distinct from observed Pod UIDs and
host process ids. Controller readback is kind-indexed: Deployment uses Recreate or its nonzero-progress
surge/unavailable pair; StatefulSet uses partition-zero native serial or staged OnDelete; DaemonSet uses
exactly one positive Surge/Unavailable or staged OnDelete; Job uses bounded waves/backoff/terminal retention;
HostProcess uses its supervisor policy. Old/new ReplicaSet coexistence, terminators and replacements sharing
one planned slot, Job terminal residents, and apply-before-prune objects are counted at the exact peak. A surviving workload with an
omitted CPU/memory/ephemeral ceiling, unobservable root-filesystem writability/allowance, writable
`hostPath`, unknown resident content/snapshot bytes, an unobservable filesystem alias/quota, or other allocation
whose upper bound/owner cannot be normalized yields `Left UnknownCommitment`; it is never treated as zero.

### Snapshot-bound authorization

Success mints a single-use `ValidatedLiveTarget` containing the
inventory/object fingerprint, relevant `resourceVersion`s, active scheduler config/readiness and managed-node
writer authority, typed execution actions, and the exact all-tenant old→desired provider-payload/content-
digest/action/retention witness, target-coalesced execution capacity witness, and store-global MinIO
logical+physical witness. The plural plan is derived from `ObservedInventory.tenantPolicies`; it
cannot accept a caller-authored prior `ProvisionedTenantPolicyPersistence` or any other prior
`Provisioned*` record. Provider version participates in the snapshot fingerprint but cannot turn
digest-different content into `NoOp`. The enact driver consumes the target and is the sole
source of scoped capabilities for every mutation path. Generic SSA occurs only inside an authorized typed
action; scheduler-root fields are excluded from SSA and ApplySet prune. Serial OnDelete
apply/delete/resume/advance, host stop/start, Job completion/cleanup, PVC/PV/image/backing allocation, and
provider-indexed tenant commands consume their own fresh observation-bound arms. A fingerprint change
immediately before enactment discards the plan and restarts the read-only prefix. The mandatory singleton
Lease serializes amoebius reconcilers; managed-node taints, admission, Binding-only RBAC, exact scheduler
config, and sole-writer readback exclude every other capacity-consuming Pod writer. Unknown authority is
refusal, not unmodelled runtime debt.
`enactLiveTarget` CAS-consumes the outer token and returns a receipt containing the exact consumed runtime
cloud and storage-scaling token maps plus the other typed action-token domain. Success joins that receipt to
a fresh whole-inventory readback. A lost/ambiguous response still returns `OutcomeUnknown` with the consumed
receipt and exposes only re-observation—never the original continuation—so an immutable validated target
cannot be replayed.

### Physical-host total vs VM allocatable (host workers)

On apple/windows the node inventory's only kube node
is the Lima/WSL2 VM, whose **allocatable** `Capacity` the cluster bin-pack folds against. A host-level
accelerator worker is a native subprocess **outside** that VM; its `Demand` folds against the **physical-host**
total the inventory *also* declares
([substrate_doctrine.md §8](./substrate_doctrine.md#8-the-node-inventory-the-single-owner-of-hosts-capacity-and-taints),
the sole owner of both numbers plus the host-binary system-reserved netting). So two distinct capacities coexist
per such host — the VM's allocatable (the cluster bin-pack) and the physical-host total (the host → host-worker
arm, [§4](./resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)) — each declared in pure input, checked during
provisioning, and cross-checked at
reconcile like every other capacity number. Live admission additionally subtracts any observed co-resident
VM/process/memory/disk commitment not already included in declared system reserve; an unknown native
commitment refuses rather than being assumed free. This doc consumes the two numbers; it does not own them.

> **Honesty.** This model is Phase-0 design intent, specified before implementation. The fold is a real
> pure provision-seal spec-layer guarantee *when implemented as specified*; that claim is itself about a design not yet
> built (Phase 7). The runtime-checked cross-check and enforcement are deferred by construction. Where the
> capacity arithmetic generalizes the push-back soundness proven in prodbox
> ([cluster_lifecycle_doctrine.md §6](./cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-root-inforcespec)),
> that is sibling evidence, not amoebius proof ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## 9. What this doctrine deliberately does not own

To keep SSoT boundaries crisp:

| Concern | Owned by |
|---|---|
| Per-host/node CPU, memory, logical ephemeral, filesystem layout/content/snapshot storage, disk pools, accelerator raw/reserved/allocatable/current-free VRAM, and their detection; node inventory; taints | [substrate_doctrine.md](./substrate_doctrine.md) |
| The `ComputeEngine` / `Topology` types the `place` fold ranges over | [cluster_topology_doctrine.md](./cluster_topology_doctrine.md) |
| Per-volume presentation, usable/raw hard-cap semantics, backing allocation policy, and the `StorageBacking` union shape | [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) |
| Per-container CPU/memory/ephemeral-storage declaration, bounded pod-local scratch/cache, and per-host-worker resource envelope | [platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope) |
| Host image-build stage graph, build scratch/cache semantics, and host-vs-pod builder choice | [image_build_doctrine.md §6](./image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1) |
| Kind bootstrap and enforcement of named engine-process/control-plane storage quotas | [../../DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md](../../DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md) |
| Cloud quota provisioning; dynamic node provisioning enaction; per-PV EBS | [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) |
| The Pulsar topic-lifecycle policy (retention, size-triggered offload, backlog quota) | [pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra) |
| The content-addressed MinIO store as a storage backing | [content_addressing_doctrine.md](./content_addressing_doctrine.md) |
| Which capacity states are illegal and the [§4.6](../illegal_state/illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) technique that forecloses them | [illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md) |
| Runtime enforcement (host actually caps, scheduler places, autoscaler grows, quota holds) | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), [testing_doctrine.md](./testing_doctrine.md) |
| Capacity/scaling as a deployment-rules surface, never app logic | [app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md) |
| The monitoring obligation types, derived surfaces, and access model (this doc owns only how their cost folds — [§9.2](#92-monitoring-cost-folds-through-the-standard-machinery-and-the-forest-has-no-parent-rollup-budget)) | [monitoring_doctrine.md](./monitoring_doctrine.md) |

<a id="91-the-cross-cluster-capacity-fold-is-a-type-foreclosed-non-goal-single-cluster-by-arity"></a>

### 9.1 Pod placement is single-cluster; shared physical supply is allocated at the forest boundary

`place` is **single-cluster by construction**, and cross-cluster *pod placement* is a deliberate non-goal. Its signature
is `place :: Topology -> [Workload] -> Either PlacementError Placement`, taking exactly one `Topology`, and a `Topology` is exactly one cluster
([cluster_topology_doctrine.md §4](./cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction)),
so a placement spanning two clusters' `Topology`s has **no constructor — type-foreclosed by arity**: the same
closed-union / no-arm idiom that forecloses the worker pool as a fourth `ComputeEngine` arm
([single_logical_data_plane_doctrine.md §2](./single_logical_data_plane_doctrine.md#2-the-two-topologies)). This
lives in its own subsection and is cross-referenced from [§4](./resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)
and [illegal_state_catalog.md §3.31](../illegal_state/illegal_state_catalog.md).

That arity does **not** permit two independent clusters to spend the same physical host, cloud-account quota, or
storage backing twice. Before `spawnChild` or provider allocation, the parent/forest owner runs a separate
single-owner budget carve:

```text
allocateForestSupply
  :: ObservedSharedSupplySnapshot
  -> ClusterSupplyDemandSet
  -> Either ForestSupplyError (Map ClusterId ClusterBudget)

-- Every refusal the carve can return, closed:
ForestSupplyError =
  < SharedSupplyOvercommit        -- a HostId/CloudAccountId/BackingId reused across cluster totals
  | AcceleratorAlreadyAllocated   -- one physical accelerator assigned twice
  | BackingAlias                  -- one backing/device copied at full size into two host records
  >

SharedSupplyLedger =
  { id       : SharedSupplyLedgerId
  , hosts    : Map HostId ObservedHostCapacity
  , hostCommitments : Map (HostId, HostCommitmentOwner) HostCommitment
  , accounts : Map CloudAccountId ObservedProviderAccount
  , backings : Map BackingId SharedBackingSupply
  , backingAllocations : Map BackingAllocationId BackingAllocation
  , hostCommitmentKeys :
      SharedHostCommitmentMapKeyHostOwnerEqualityWitness
  , backingAllocationKeys :
      SharedBackingAllocationMapKeyEmbeddedIdentityEqualityWitness
  , backingParentNesting :
      SharedBackingHostDiskEbsOrCloudQuotaNestingWitness
  , sourceEquality :
      SharedSupplyIdFingerprintHostAccountBackingCommitmentDomainEqualityWitness
  }

SharedSupplySnapshotFingerprint = InventoryFingerprint

ObservedSharedSupplySnapshot =
  { ledger           : SharedSupplyLedger
  , fingerprint      : SharedSupplySnapshotFingerprint
  , resourceVersions : Map KubernetesObjectId ResourceVersion
  , keyEquality      : SharedSupplyLedgerMapKeyIdentityEqualityWitness
  , fingerprintJoin  :
      SnapshotFingerprintEqualsLedgerIdMemberAndResourceVersionFingerprintWitness
  , freshness        : LiveObservationFreshnessWitness
  , sourceEquality   :
      SharedSupplySnapshotLedgerMemberFingerprintResourceVersionEqualityWitness
  }

SharedSupplyLedgerId =
  { owner       : ClusterId
  , generation  : ProvisionGenerationDigest
  , inventory   : InventoryFingerprint
  }

ForestSupplyAllocationDigest = ContentAddress

ClusterHostSupplyCarve =
  { cpu                : Quantity Cpu
  , memory             : Quantity Bytes
  , disks              : Map PhysicalDiskBackingId (Quantity Bytes)
  , storageChildren    : Map HostStorageAllocationKey ClusterHostStorageCarve
  , accelerator        : ClusterAcceleratorSupplyCarve
  , memoryAcceleratorEquality :
      ClusterHostMemoryAcceleratorCarveEqualityWitness memory accelerator
  , storageParentEquality :
      ClusterHostStorageChildPhysicalDiskExactlyOnceWitness disks storageChildren
  }

HostStorageAllocationKey =
  < VmDisk         : DiskCarveId
  | DirectNodePool : DiskCarveId
  | RetainedBacking: BackingId
  | CacheBacking   : CacheBackingId
  | HostStorage    : HostStorageBackingId
  >

ClusterHostStorageCarve =
  { parent              : PhysicalDiskBackingId
  , requiredUsableBytes : Quantity Bytes
  , allocatedRawBytes   : Quantity Bytes
  , presentation        : VolumePresentation
  , purpose             : HostStorageAllocationKey
  , sourceEquality      :
      HostStoragePurposeParentUsableRawPresentationCarveEqualityWitness
  }

ClusterAcceleratorSupplyCarve =
  < None
  | Cuda :
      { devices : NonEmptyMap AcceleratorDeviceId
          { profile         : AcceleratorProfile
          , allocatableVram : Quantity Bytes
          }
      , links : List AcceleratorLink
      , inducedSubgraph :
          CarvedCudaDeviceAndLinkInducedSubgraphEqualityWitness
      }
  | AppleMetal :
      { owner              : HostId
      , profile            : MetalProfile
      , unifiedMemoryDebit : Quantity Bytes
      }
  >
-- The equality witness proves AppleMetal.unifiedMemoryDebit is a derived sub-carve of memory and appears
-- exactly once; None/Cuda prove no unified-memory sub-carve. CUDA and Metal cannot coexist in one host carve.

ClusterSupplyVector =
  { hosts    : Map HostId ClusterHostSupplyCarve
  , accounts : Map CloudAccountId ProviderQuotaCarve
  , backings : Map BackingId ClusterBackingCarve
  }

ClusterAcceleratorSupplyDemand =
  < None
  | Cuda :
      { profiles       : NonEmptyMap AcceleratorProfile PositiveNatural
      , epochs         : NonEmptyMap AcceleratorEpochId
          { workloads   : NonEmptyMap AcceleratorWorkloadId (NonEmpty AcceleratorResidencyDemand)
          , coexistence : AcceleratorCoexistencePolicy
          , interconnect: AcceleratorInterconnectRequirement
          }
      , sourceEquality : ForestCudaWorkloadEpochResidencyPolicyDomainEqualityWitness
      }
  | AppleMetal :
      { profile            : MetalProfile
      , unifiedMemoryDebit : Quantity Bytes
      , epochs             : NonEmptyMap AcceleratorEpochId
          (NonEmptyMap AcceleratorWorkloadId MetalWorkloadDemand)
      , sourceEquality     : ForestMetalWorkloadEpochDomainEqualityWitness
      }
  >

ClusterHostStorageDemand =
  { parent              : PhysicalDiskBackingId
  , requiredUsableBytes : Quantity Bytes
  , allocatedRawBytes   : Quantity Bytes
  , presentation        : VolumePresentation
  , purpose             : HostStorageAllocationKey
  , sourceEquality      :
      HostStorageDemandSourceParentUsableRawPresentationEqualityWitness
  }

ClusterHostSupplyDemand =
  { cpu         : Quantity Cpu
  , memory      : Quantity Bytes
  , disks       : Map PhysicalDiskBackingId (Quantity Bytes)
  , storageChildren : Map HostStorageAllocationKey ClusterHostStorageDemand
  , accelerator : ClusterAcceleratorSupplyDemand
  , memoryAcceleratorEquality :
      ClusterHostDemandMemoryAcceleratorEqualityWitness memory accelerator
  , storageParentEquality :
      ClusterHostStorageDemandParentExactlyOnceWitness disks storageChildren
  }

ClusterHostDiskBackingDemand =
  { backing             : HostDiskBacking
  , owner               : HostId
  , requiredRawBytes    : Quantity Bytes
  , volumeCount         : PositiveNatural
  , expectedPresentation: VolumePresentation
  , sourceEquality      :
      HostDiskDemandBackingOwnerCarveCapacityAllocationPresentationEqualityWitness
  }

ClusterEbsBackingDemand =
  { backing             : EbsBacking
  , requiredRawBytes    : Quantity Bytes
  , volumeCount         : PositiveNatural
  , expectedPresentation: VolumePresentation
  , sourceEquality      :
      EbsDemandBackingAccountPolicyAllocationPresentationEqualityWitness
  }

ClusterCloudQuotaBackingDemand =
  { backing        : CloudQuotaBacking
  , requiredBytes  :
      ProviderObjectByteAmount backing.quota.accounting (Quantity Bytes)
  , objectCount    : PositiveNatural
  , sourceEquality :
      CloudQuotaDemandBackingAccountQuotaAccountingByteCountEqualityWitness
  }

ClusterBackingDemand =
  < HostDisk   : ClusterHostDiskBackingDemand
  | Ebs        : ClusterEbsBackingDemand
  | CloudQuota : ClusterCloudQuotaBackingDemand
  >

ClusterSupplyDemandVector =
  { hosts    : Map HostId ClusterHostSupplyDemand
  , accounts : Map CloudAccountId ProviderQuotaUsage
  , backings : Map BackingId ClusterBackingDemand
  }

ProviderQuotaCarve =
  { account        : CloudAccountId
  , limit          : ProviderQuotaUsage
  , sourceEquality : ProviderQuotaCarveAccountObservedResidualEqualityWitness
  }

SharedHostDiskBackingSupply =
  { id             : BackingId
  , backing        : HostDiskBacking
  , owner          : HostId
  , capacity       : StorageCapacity
  , volumeCount    : Natural
  , presentation   : VolumePresentation
  , sourceEquality :
      SharedHostDiskIdentityOwnerCarveCapacityCountAllocationPresentationEqualityWitness
  , fingerprint    : InventoryFingerprint
  }

SharedEbsBackingSupply =
  { id             : BackingId
  , backing        : EbsBacking
  , capacity       : StorageCapacity
  , volumeCount    : Natural
  , presentation   : VolumePresentation
  , sourceEquality :
      SharedEbsIdentityAccountPolicyCapacityCountPresentationEqualityWitness
  , fingerprint    : InventoryFingerprint
  }

SharedCloudQuotaBackingSupply =
  { id             : BackingId
  , backing        : CloudQuotaBacking
  , quota          : ObservedProviderObjectQuota
  , sourceEquality :
      SharedCloudQuotaBackingIdentityQuotaAccountAccountingUsageSnapshotEqualityWitness
  , fingerprint    : InventoryFingerprint
  }

SharedVolumeBackingSupply =
  < HostDisk : SharedHostDiskBackingSupply
  | Ebs      : SharedEbsBackingSupply
  >

SharedBackingSupply =
  < HostDisk   : SharedHostDiskBackingSupply
  | Ebs        : SharedEbsBackingSupply
  | CloudQuota : SharedCloudQuotaBackingSupply
  >

ClusterBackingCarve =
  < HostDisk :
      { supply           : SharedHostDiskBackingSupply
      , allocatedRawBytes: Quantity Bytes
      , volumeCount      : PositiveNatural
      , sourceEquality   :
          ClusterHostDiskBackingCarveSupplyRawByteCountEqualityWitness
      }
  | Ebs :
      { supply           : SharedEbsBackingSupply
      , allocatedRawBytes: Quantity Bytes
      , volumeCount      : PositiveNatural
      , sourceEquality   :
          ClusterEbsBackingCarveSupplyRawByteCountEqualityWitness
      }
  | CloudQuota :
      { supply         : SharedCloudQuotaBackingSupply
      , allocatedBytes :
          ProviderObjectByteAmount supply.quota.quota.accounting (Quantity Bytes)
      , objectCount    : PositiveNatural
      , sourceEquality :
          ClusterCloudQuotaBackingCarveSupplyAccountingByteObjectCountEqualityWitness
      }
  >

ClusterAcceleratorSupplyResidual =
  < None
  | Cuda :
      { availableDevices : Set AcceleratorDeviceId
      , remainingVram    : Map AcceleratorDeviceId (Residual Bytes)
      , links            : List AcceleratorLink
      }
  | AppleMetal :
      { owner                  : HostId
      , remainingUnifiedMemory : Residual Bytes
      }
  >

ClusterHostSupplyResidual =
  { cpu         : Residual Cpu
  , memory      : Residual Bytes
  , disks       : Map PhysicalDiskBackingId (Residual Bytes)
  , storageChildren : Map HostStorageAllocationKey (Residual Bytes)
  , accelerator : ClusterAcceleratorSupplyResidual
  }

SharedBackingResidual =
  < HostDisk :
      { supply      : SharedHostDiskBackingSupply
      , rawBytes    : Residual Bytes
      , volumeCount : Natural
      , sourceEquality:
          SharedHostDiskResidualSupplyRawByteCountEqualityWitness
      }
  | Ebs :
      { supply      : SharedEbsBackingSupply
      , rawBytes    : Residual Bytes
      , volumeCount : Natural
      , sourceEquality:
          SharedEbsResidualSupplyRawByteCountEqualityWitness
      }
  | CloudQuota :
      { supply       : SharedCloudQuotaBackingSupply
      , bytes        :
          ProviderObjectByteAmount supply.quota.quota.accounting (Residual Bytes)
      , objectCount  : Natural
      , sourceEquality:
          SharedCloudQuotaResidualSupplyAccountingByteCountEqualityWitness
      }
  >

ClusterSupplyDemand =
  { cluster   : ClusterId
  , requested : ClusterSupplyDemandVector
  , keyEquality : ClusterSupplyDemandNestedMapKeyIdentityEqualityWitness
  }

ClusterSupplyDemandSet =
  { demands     : NonEmptyMap ClusterId ClusterSupplyDemand
  , keyEquality : ClusterSupplyDemandMapKeyEqualsEmbeddedClusterEqualityWitness
  , sourceEquality :
      ForestBoundChildDomainEqualsSupplyDemandDomainEqualityWitness
  }

ClusterBudgetDisjointnessWitness =
  { ledger                   : SharedSupplyLedgerId
  , snapshot                 : SharedSupplySnapshotFingerprint
  , allocation               : ForestSupplyAllocationDigest
  , clusterDomain            : Set ClusterId
  , members                  : Map ClusterId ClusterSupplyVector
  , memberKeys               :
      ForestMemberMapKeyEqualsDemandSetClusterDomainEqualityWitness
  , hostAxisResiduals        : Map HostId ClusterHostSupplyResidual
  , accountQuotaResiduals    : Map CloudAccountId ProviderQuotaResidual
  , backingResiduals         : Map BackingId SharedBackingResidual
  , backingParentDebitEquality:
      ClusterBackingHostDiskEbsOrCloudQuotaExactlyOnceDebitWitness
  , exactDemandProjection    : Required
  , pairwiseCarvesDisjoint   : Required
  , everyAxisWithinSupply    : Required
  , acceleratorOwnersUnique : Required
  }

ClusterBudgetMemberEqualityWitness ledger cluster requested carve forestWitness =
  { ledgerExact       : ledger == forestWitness.ledger
  , clusterInDomain   : cluster ∈ forestWitness.clusterDomain
  , memberCarveExact  : forestWitness.members[cluster] == carve
  , demandToCarveExact:
      ClusterSupplyDemandToObservedCarveEqualityWitness requested carve
  , allocationExact   : Required
  }

ClusterBudget = -- opaque; constructor private to allocateForestSupply
  { ledger         : SharedSupplyLedgerId
  , cluster        : ClusterId
  , requested      : ClusterSupplyDemandVector
  , carve          : ClusterSupplyVector
  , witness        : ClusterBudgetDisjointnessWitness
  , memberEquality :
      ClusterBudgetMemberEqualityWitness ledger cluster requested carve witness
  }
-- Checked Map construction also proves each returned map key equals ClusterBudget.cluster.
```

Each `ClusterSupplyDemand` contains only infrastructure/backing claims: engine/VM/node-container/fabric CPU
and memory, provisioned VM disk and unique direct-node filesystem carves, host workers/caches, provider
instance/vCPU/device/node-root-EBS quota, and durable backing/quota. The checked
`ClusterSupplyDemandSet` makes `ClusterId` unique and proves each map key equals the embedded child identity;
two rows for one child cannot independently spend supply. Physical/block backing arms compare only raw bytes
and volume count after presentation/allocation. A provider-object `CloudQuota` arm compares the selected
`Logical` or `Billed` byte amount and object count against a complete observation in that exact accounting arm;
cross-unit comparison requires the arm's pinned conversion model and creates a new checked amount. Those unit
domains are distinct closed arms—there
is no record that can accidentally add an S3 object quota to EBS raw bytes. Host storage likewise carries
required usable bytes and its separately derived raw parent debit; only the latter enters a physical-disk
parent sum.

A managed-provider claim must carry the
authored `account : CloudAccountId` from `Managed Eks`; allocation exact-joins only
`SharedSupplyLedger.accounts[account]`, and that same key scopes `ProviderInstanceId`, credential binding,
observed current usage, and the returned `ClusterBudget`. Missing-account, wrong-account, or
quota-from-another-account inputs return a structured error and cannot fall back to any other ledger entry. It
also carries physical accelerator
identity: CUDA device ids/profile/allocatable VRAM or an Apple
Metal offering plus the unified-memory debit. One physical device id/Metal owner can enter at most one returned
cluster/host-worker budget unless the explicit wholesale owner itself multiplexes the jobs. The fold proves,
per shared owner,
`Σ co-resident cluster carves + non-cluster commitments ≤ observed residual supply`, returns disjoint opaque
`ClusterBudget`s, and only then may each cluster run its own `provision`/`place`. This is allocation across
clusters, **not** placement across clusters: no pod can straddle the returned budgets. Reusing one `HostId`,
`CloudAccountId`, or `BackingId` in independently authored cluster totals without the parent carve is
`Left SharedSupplyOvercommit`; assigning the same physical accelerator twice is
`Left AcceleratorAlreadyAllocated`, never two successful proofs over the same bytes/devices.
Constructing the ledger itself globally indexes every embedded `PhysicalDiskBackingId` and accelerator device
id across **all** `HostId`s: a backing/device may have one physical owner only. A genuinely shared network
backing appears once in `backings` and is carved there, never copied at full size into two host records.
Cross-host aliasing therefore returns `Left BackingAlias` before cluster budgets are computed.
The shared-supply property corpus independently runs missing-account, wrong-account, duplicated-account-carve,
and one-short mutants for `maxInstances`, `maxVcpu`, each `acceleratorCaps` entry,
`nodeRootStorage.bytes`/`volumeCount`, `durable.bytes`/`volumeCount`, and provider-object selected-unit
`bytes.value`/`objectCount`; every mutant must fail before a
`ClusterBudget` or provider action is constructed.

Distributing a workload across clusters is **geo-replication** — *N* independent clusters, each running its own
`place` over its own `Topology`, related only by async transport (Phase-42 design intent,
[app_vs_deployment_doctrine.md §9](./app_vs_deployment_doctrine.md#9-composition-one-cluster--n-geo-replicated-clusters-zero-app-change)).
It is emphatically **not** the stateless attach pool, which is **single-cluster** and lives **inside** `place`'s
elastic branch: [single_logical_data_plane_doctrine.md §4](./single_logical_data_plane_doctrine.md#4-the-elastic-worker-pool-the-attach-topology)
re-runs the *same* `place` fold on the enlarged topology, and modelling that pool as cross-cluster machinery is
the category error [single_logical_data_plane_doctrine.md §5](./single_logical_data_plane_doctrine.md#5-the-category-error-this-doctrine-forecloses)
forecloses. The **reason** a cluster is the *pod-placement* boundary — the phantom cluster index `c` on `DataPlane` /
`FabricMember` — is owned by [single_logical_data_plane_doctrine.md §1](./single_logical_data_plane_doctrine.md#1-why-this-doctrine-exists-two-ways-to-say-run-this-elsewhere)
and [§3](./single_logical_data_plane_doctrine.md#3-the-binding-reachability-is-a-type-not-a-runtime-probe); this
subsection consumes that WHY, it does not restate it. The only runtime-checked residue is the deferred geo-replication
enaction (Phase 42). A **stretched cluster** does not breach this arity: it is **one** `Topology` whose nodes span
two `Site`s, folded **once** ([§4](./resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)).

### 9.2 Monitoring cost folds through the standard machinery, and the forest has no parent-rollup budget

Monitoring adds no capacity machinery of its own. The generic path is pull/scrape of the `/metrics` endpoints
every daemon already exposes ([daemon_topology_doctrine.md](./daemon_topology_doctrine.md)) — no per-workflow
sidecar, so it adds zero per-workflow `Demand` and honours the no-sidecar-fleet stance
([network_fabric_doctrine.md](./network_fabric_doctrine.md)). The monitoring pods — the **one shared**
TensorBoard per extension/app and the optional single local Thanos companion beside Prometheus — declare
refined non-zero CPU/memory/ephemeral-storage envelopes and fold through `place`/`podFits`
([§4](./resource_capacity_folds.md#4-the-total-fold-fits-carve-place-and-the-nesting)) exactly like any workload; a per-user monitoring view
is an access filter over that shared instance ([monitoring_doctrine.md](./monitoring_doctrine.md)), never a pod
per user, so it does not multiply `Demand`. Recording-rule evaluation folds into the `Observability` Prometheus
workload's `Demand` **as a function of the monitored population** — the bound execution set plus the workflow
list, because every `BoundExecutionUnit` carries a mandatory monitor
([monitoring_doctrine.md §2.4](./monitoring_doctrine.md#24-per-execution-unit-obligation--boundexecutionunitmonitor))
— not a flat add. That population is strictly larger than the workflow list, so the cardinality bounds below
bite sooner and a deployment may be refused for monitoring cost alone; that refusal is a `ProvisionError` at
the seal, never silent under-coverage. The alert receiver holding the firing set is one further pod beside
Prometheus with its own complete envelope and a finite in-memory bound, not a second durable store. Every
observability binding carries a mandatory finite
`MonitoringWorkBudget { maxWorkflows, maxRules, maxSeries, maxScrapeSamplesPerSecond,
evaluationInterval, evaluationCpu, evaluationMemory, retention,
query : QueryWorkBudget { maxConcurrentQueries, maxSeriesPerQuery, maxSamplesPerQuery, maxRange, timeout,
costModel }, volume, tsdbCostModel }`. The binder derives rule/series/sample-rate counts from the descriptor, rejects any value above its
bound, and uses a version-pinned conservative cost function to derive the Prometheus container's CPU/memory
request+limit from baseline + rule/series/evaluation work overlapping maximum concurrent query work, plus a
separate complete resource envelope for the sole-routable query-admission proxy. Its versioned TSDB/query
models also derive retained
blocks + WAL/head + compaction overlap + structural query-temp usable peak; volume presentation and backing quantum then
derive the exact private PVC/PV demand; rendered
evaluation/retention settings, Prometheus query flags, and the sole-routable query-admission proxy use the same
operands. Direct query API access, fixed requests, tiny authored PVCs, a scalar query-temp allowance, and an
optional guard are forbidden; runtime cost-model error remains residue inside the enforced structural
ceilings. The `workflow-health`
compacted topic and the jitML `tfevents` prefix fold through the two-ceiling Pulsar fold
([§7](./resource_capacity_storage.md#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)) and the closed `StorageBudget`
([§5](./resource_capacity_storage.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)) — no new budget type. And because
in-cluster parent→child telemetry is foreclosed ([monitoring_doctrine.md](./monitoring_doctrine.md), the same
cross-cluster arity as [§9.1](#91-pod-placement-is-single-cluster-shared-physical-supply-is-allocated-at-the-forest-boundary)),
there is **no** parent-rollup storage to budget — a vacuous parent-side `StorageBudget` would have no flow to
  account. The cost model is deliberately conservative and version-pinned: actual query latency remains
  runtime-checked, but descriptor cardinality cannot bypass the pure CPU/memory provision.

### 9.3 Realtime and offline UI demand is finite, server-side, and transition-aware

The UI-server envelope includes HTTPS/WebSocket connection count, per-connection input/output buffers,
heartbeat and handshake work, Redis client pools, finite connection-registration keys/TTLs, Pub/Sub fanout,
drain overlap, reconnect storms, and durable cursor/receipt repair. Redis members and Sentinels have complete
CPU/memory/ephemeral-storage/network/client/output-buffer envelopes. Redis has no durable-volume demand: adding
a PVC, AOF, RDB, or backup to make it authoritative is a topology error, not extra capacity.

Offline continuity additionally derives server receipt retention/lookups, bounded replay concurrency and
retry state, projection snapshot/delta catch-up, upload staging/chunks/content verification, provider-effect
overlap, and every old/new codec and handler retained during the finite release-compatibility horizon. Local
browser count/byte/age limits are demand bounds and runtime admission operands, but browser quota is observed
client state rather than cluster `Capacity`; it can refuse/evict only through the typed runtime policy. A
declared offline queue, Redis output buffer, WebSocket route, replay population, upload, or compatibility
horizon without a finite upper bound cannot contribute to `ProvisionedSpec`.

---

## Related Documents
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the hub of this family, which owns the model's shape and links every slice
- [Resource Capacity Schema](./resource_capacity_schema.md) — the type spellings these sections describe
- [Resource Capacity Folds](./resource_capacity_folds.md) — the folds these numbers feed
- [Engineering Doctrine Index](./README.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order and status for this work
