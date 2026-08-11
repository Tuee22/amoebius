let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let Entry = \(k : Type) -> \(v : Type) -> { key : k, value : v }

let ByteQuantity = { bytes : Natural }

let FiniteDuration = { seconds : Natural }

let BackingAllocationPolicy =
      { minimumBytes : ByteQuantity, quantumBytes : ByteQuantity }

let FilesystemPresentation =
      { fsType : Text
      , overheadModel : Text
      , allocation : BackingAllocationPolicy
      }

let VolumePresentation =
      < Block : { allocation : BackingAllocationPolicy }
      | Filesystem : FilesystemPresentation
      >

let StorageBacking =
      < Fixed :
          { backing : Text
          , bytes : ByteQuantity
          , presentation : VolumePresentation
          }
      | Growable :
          { backing : Text
          , floorBytes : ByteQuantity
          , ceilingBytes : ByteQuantity
          , scalingPolicy :
              { triggerFreeBytes : ByteQuantity
              , growthBytes : ByteQuantity
              , cooldown : FiniteDuration
              }
          , presentation : VolumePresentation
          }
      >

let StatefulSetClaimSlot =
      { statefulSet : Text, template : Text, ordinal : Natural }

let DirectVolumeGeometry = { replicaCount : Natural }

let BookieSlot =
      { id : Text
      , claim : StatefulSetClaimSlot
      , backing : Text
      , journalAndIndexReserve : ByteQuantity
      }

let BookKeeperGeometry =
      { bookies : NonEmpty BookieSlot
      , ensembleSize : Natural
      , writeQuorum : Natural
      , ackQuorum : Natural
      , ledgerSegmentBytes : ByteQuantity
      , faultPolicy : { maxSimultaneousUnavailableBookies : Natural }
      }

let BookKeeperLogicalDemand =
      { retainedHotBytes : ByteQuantity
      , openLedgerHeadroom : ByteQuantity
      , inFlightOffloadBytes : ByteQuantity
      , deletionLagBytes : ByteQuantity
      }

let MinioDrive = { id : Text, claim : StatefulSetClaimSlot, backing : Text }

let MinioErasureSet =
      { id : Text
      , drives : NonEmpty MinioDrive
      , dataShards : Natural
      , parityShards : Natural
      }

let MinioErasureGeometry =
      { sets : NonEmpty MinioErasureSet
      , shardBlockBytes : ByteQuantity
      , metadataReservePerDrive : ByteQuantity
      , healingWorkspacePerDrive : ByteQuantity
      , faultPolicy :
          { maxUnavailablePerErasureSet : Natural
          , replacementDrives : NonEmpty MinioDrive
          }
      }

let VolumeGeometry =
      < Direct : DirectVolumeGeometry
      | BookKeeper : BookKeeperGeometry
      | Minio : MinioErasureGeometry
      >

let DeclaredVolumeDemand =
      { id : Text
      , claim : StatefulSetClaimSlot
      , backing : Text
      , logicalBytes : ByteQuantity
      , geometry : VolumeGeometry
      , presentation : VolumePresentation
      }

let LogicalObjectExtent = { count : Natural, maxBytesEach : ByteQuantity }

let ObjectStoreObjectId =
      { store : Text, tenant : Text, bucket : Text, key : Text }

let ObjectStoreRetentionBudget =
      { maxAdditionalResidentExtents : NonEmpty LogicalObjectExtent
      , maxRetention : FiniteDuration
      }

let ObjectStoreFailureBudget =
      { maxFailedWriteSetsPerWindow : Natural
      , failureWindow : FiniteDuration
      , orphanGcHorizon : FiniteDuration
      }

let ObjectStoreWriteBudget =
      { maxConcurrentWriteSets : Natural
      , maxWriteSet : NonEmpty LogicalObjectExtent
      , failure : ObjectStoreFailureBudget
      }

let ObjectStoreMutationAdmission =
      { model : Text, writer : Text, costModel : Text }

let ObjectStoreDemand =
      { budget : Text
      , committedResident : List (Entry ObjectStoreObjectId ByteQuantity)
      , retention : ObjectStoreRetentionBudget
      , writes : ObjectStoreWriteBudget
      , mutationAdmission : ObjectStoreMutationAdmission
      }

let ContentStoreLogicalDemand = ObjectStoreDemand

let PulsarOffloadObjectDemand =
      { topic : Text
      , budget : Text
      , retainedBytes : ByteQuantity
      , ledgerSegmentBytes : ByteQuantity
      , maxConcurrentOffloads : Natural
      , maxSegmentsPerWindow : Natural
      , offloadWindow : FiniteDuration
      , deletionLag : FiniteDuration
      , failure : ObjectStoreFailureBudget
      , model : Text
      , mutationAdmission : ObjectStoreMutationAdmission
      }

let PulumiStateFieldDemand =
      { path : Text
      , maxCanonicalBytes : ByteQuantity
      , secrecy : < Plain | Secret >
      }

let PulumiStateEntryDemand =
      { identity : Text, fields : NonEmpty PulumiStateFieldDemand }

let PulumiCheckpointObjectDemand =
      { stack : Text
      , budget : Text
      , entries : NonEmpty PulumiStateEntryDemand
      , maxRetainedRevisions : Natural
      , updateConcurrency : < Serial >
      , failure : ObjectStoreFailureBudget
      , model : Text
      , mutationAdmission : ObjectStoreMutationAdmission
      }

let ControlPlaneStateEntryKind =
      < InForceSpecSnapshot
      | ManagedResourceRegistry
      | ReconcileJournal
      | ValidationLedger
      | JobCompletion
      >

let ControlPlaneStateEntryDemand =
      { identity : Text
      , kind : ControlPlaneStateEntryKind
      , maxCanonicalBytes : ByteQuantity
      }

let ControlPlaneStateObjectDemand =
      { budget : Text
      , entries : NonEmpty ControlPlaneStateEntryDemand
      , maxRetainedVersions : Natural
      , updateConcurrency : < Serial >
      , failure : ObjectStoreFailureBudget
      , model : Text
      , mutationAdmission : ObjectStoreMutationAdmission
      }

let RegistryMutationAdmission =
      { model : Text, publisher : Text, costModel : Text }

let RegistryUploadPolicy =
      { concurrency : < Serial | BoundedParallel : Natural >
      , failureWindow : FiniteDuration
      , maxFailedUploadsPerWindow : Natural
      , failedUploadGcHorizon : FiniteDuration
      , model : Text
      }

let RegistryBackend =
      < InterimEphemeral : { volume : Text } | Minio : { store : Text } >

let RegistryStorageIntent =
      { budget : Text
      , artifacts : NonEmpty Text
      , upload : RegistryUploadPolicy
      , mutationAdmission : RegistryMutationAdmission
      , backend : RegistryBackend
      }

let ObjectStoreProducerIntent =
      < AppBucket : ObjectStoreDemand
      | Content : ContentStoreLogicalDemand
      | Registry : RegistryStorageIntent
      | PulsarOffload : PulsarOffloadObjectDemand
      | PulumiCheckpoint : PulumiCheckpointObjectDemand
      | ControlPlaneState : ControlPlaneStateObjectDemand
      >

let ObjectStoreGatewayIntent = { gateway : Text, model : Text }

let CachePopulationAsset =
      { identity : Text
      , digest : Text
      , residentBytes : ByteQuantity
      , temporaryBytes : ByteQuantity
      }

let CachePopulationDemand =
      { assets : NonEmpty CachePopulationAsset
      , firstMissConcurrency : Natural
      , model : Text
      }

let CacheBudget =
      { id : Text, maximumBytes : ByteQuantity, retention : FiniteDuration }

let InClusterCacheDemand =
      { id : Text
      , volume : Text
      , budget : CacheBudget
      , population : CachePopulationDemand
      }

let HostCacheDemand =
      { id : Text
      , backing : Text
      , budget : CacheBudget
      , population : CachePopulationDemand
      , source : < ImageBuild : Text | AssetMaterialization : Text >
      }

let TrainBudget =
      < Bounded : < Steps : Natural | Epochs : Natural >
      | Continuous : { checkpointCadence : { steps : Natural } }
      >

let TrainData =
      < Snapshot : { digest : Text }
      | Feed : { topic : Text, retentionBudget : Text }
      >

let AssetMaterializationDemand =
      { asset : Text
      , digest : Text
      , residentBytes : ByteQuantity
      , temporaryBytes : ByteQuantity
      , cache : HostCacheDemand
      }

let PulumiPluginDemand =
      { identity : Text
      , digest : Text
      , installedBytes : ByteQuantity
      , peakInstallBytes : ByteQuantity
      }

let PulumiDeployUnit =
      { id : Text
      , executionUnit : Text
      , dependsOn : List Text
      , state : NonEmpty PulumiStateEntryDemand
      , plugins : NonEmpty Text
      , cache : InClusterCacheDemand
      }

let PulumiExecutionDemand =
      { deploys : NonEmpty PulumiDeployUnit
      , concurrency : < Serial | BoundedParallel : Natural >
      , plugins : NonEmpty PulumiPluginDemand
      , pluginVolume : Text
      , workspaceVolume : Text
      , model : Text
      }

let VaultPersistedObjectDemand =
      { identity : Text
      , kind : < Kv | TransitKey | Pki | Auth | Lease >
      , versions : Natural
      , maxPayloadBytes : ByteQuantity
      }

let VaultAuditDemand =
      { maxBytesPerFile : ByteQuantity
      , maxBackups : Natural
      , retention : FiniteDuration
      , backing :
          < PodEphemeral : { volume : Text }
          | Retained :
              { claim : StatefulSetClaimSlot
              , backing : Text
              , presentation : VolumePresentation
              }
          >
      }

let VaultStorageDemand =
      { persisted : NonEmpty VaultPersistedObjectDemand
      , maxActiveLeases : Natural
      , raftModel : Text
      , raftVolumes :
          NonEmpty
            { claim : StatefulSetClaimSlot
            , backing : Text
            , presentation : VolumePresentation
            }
      , audit : VaultAuditDemand
      }

let StorageBudget =
      < PodEphemeral : { id : Text, owner : Text, ceiling : ByteQuantity }
      | Durable : { id : Text, owner : Text, ceiling : ByteQuantity }
      | ObjectStore : { id : Text, owner : Text, ceiling : ByteQuantity }
      | Registry : { id : Text, owner : Text, ceiling : ByteQuantity }
      | Cache : { id : Text, owner : Text, ceiling : ByteQuantity }
      | Vault : { id : Text, owner : Text, ceiling : ByteQuantity }
      | Migration : { id : Text, owner : Text, ceiling : ByteQuantity }
      >

let PriorProvisionResource =
      < Execution | Volume : StatefulSetClaimSlot | Registry : Text >

let PriorProvisionRefSource =
      { deployment : Text
      , generation : Natural
      , resource : PriorProvisionResource
      }

let StorageMigrationPolicy =
      { model : Text
      , workspaceBacking : Text
      , copyConcurrency : Natural
      , copyChunkBytes : ByteQuantity
      }

let StorageMigrationIntent =
      { identity : Text
      , old : PriorProvisionRefSource
      , replacement : DeclaredVolumeDemand
      , policy : StorageMigrationPolicy
      }

let SchemaObjectDemand =
      { identity : Text
      , kind : < Table | Index | Constraint | MaterializedView >
      , maxBytes : ByteQuantity
      }

let SchemaMigrationPolicy =
      { model : Text
      , maxConcurrentOperations : Natural
      , workspaceBacking : Text
      }

let SchemaMigrationIntent =
      { identity : Text
      , database : Text
      , dataBacking : Text
      , old : List (Entry Text SchemaObjectDemand)
      , replacement : List (Entry Text SchemaObjectDemand)
      , policy : SchemaMigrationPolicy
      }

let PatroniLogicalStorageIntent =
      { objects : NonEmpty SchemaObjectDemand
      , maxWalBytes : ByteQuantity
      , checkpointBytes : ByteQuantity
      , failoverReplayBytes : ByteQuantity
      , recoveryWorkspaceBytes : ByteQuantity
      , model : Text
      }

let SqlMutationIntent =
      { writer : Text
      , maxConnections : Natural
      , maxConcurrentTransactions : Natural
      , maxTransactionsPerWindow : Natural
      , transactionWindow : FiniteDuration
      , maxWalBytesPerTransaction : ByteQuantity
      , costModel : Text
      }

let PatroniSqlIntent =
      { database : Text
      , budget : Text
      , storage : PatroniLogicalStorageIntent
      , volume : DeclaredVolumeDemand
      , mutation : SqlMutationIntent
      }

let RegistryBackendMigrationPolicy =
      { model : Text, workspaceVolume : Text, copyConcurrency : Natural }

let RegistryBackendMigrationIntent =
      { identity : Text
      , source : PriorProvisionRefSource
      , replacement : RegistryStorageIntent
      , policy : RegistryBackendMigrationPolicy
      }

let fixed =
      \(backing : Text) ->
      \(bytes : ByteQuantity) ->
      \(presentation : VolumePresentation) ->
        StorageBacking.Fixed { backing, bytes, presentation }

let growable =
      \(backing : Text) ->
      \(floorBytes : ByteQuantity) ->
      \(ceilingBytes : ByteQuantity) ->
      \ ( scalingPolicy
        : { triggerFreeBytes : ByteQuantity
          , growthBytes : ByteQuantity
          , cooldown : FiniteDuration
          }
        ) ->
      \(presentation : VolumePresentation) ->
        StorageBacking.Growable
          { backing, floorBytes, ceilingBytes, scalingPolicy, presentation }

in  { Type = StorageBacking
    , ByteQuantity
    , FiniteDuration
    , BackingAllocationPolicy
    , FilesystemPresentation
    , VolumePresentation
    , StatefulSetClaimSlot
    , DeclaredVolumeDemand
    , BookieSlot
    , BookKeeperGeometry
    , BookKeeperLogicalDemand
    , MinioErasureGeometry
    , MinioDrive
    , MinioErasureSet
    , ObjectStoreObjectId
    , ObjectStoreRetentionBudget
    , ObjectStoreWriteBudget
    , ObjectStoreMutationAdmission
    , ObjectStoreDemand
    , ContentStoreLogicalDemand
    , PulsarOffloadObjectDemand
    , PulumiCheckpointObjectDemand
    , PulumiStateFieldDemand
    , PulumiStateEntryDemand
    , ControlPlaneStateObjectDemand
    , ObjectStoreProducerIntent
    , ObjectStoreGatewayIntent
    , RegistryStorageIntent
    , RegistryUploadPolicy
    , RegistryBackend
    , CachePopulationDemand
    , CacheBudget
    , InClusterCacheDemand
    , HostCacheDemand
    , TrainBudget
    , TrainData
    , AssetMaterializationDemand
    , PulumiPluginDemand
    , PulumiDeployUnit
    , PulumiExecutionDemand
    , VaultPersistedObjectDemand
    , VaultAuditDemand
    , VaultStorageDemand
    , StorageBudget
    , PriorProvisionRefSource
    , PriorProvisionResource
    , StorageMigrationPolicy
    , StorageMigrationIntent
    , SchemaMigrationPolicy
    , SchemaMigrationIntent
    , SchemaObjectDemand
    , PatroniLogicalStorageIntent
    , SqlMutationIntent
    , PatroniSqlIntent
    , RegistryBackendMigrationPolicy
    , RegistryBackendMigrationIntent
    , fixed
    , growable
    }
