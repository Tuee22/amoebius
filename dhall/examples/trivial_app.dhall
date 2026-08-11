let App = ../amoebius/App.dhall

let Capability = ../amoebius/Capability.dhall

let Storage = ../amoebius/Storage.dhall

let Retention = ../amoebius/Retention.dhall

let Resources = ../amoebius/Resources.dhall

let V = ./legal_values.dhall

let extent = { count = 4, maxBytesEach = V.b 1048576 }

let admission
    : Storage.ObjectStoreMutationAdmission
    = { model = "object-admission-v1"
      , writer = "trivial-app"
      , costModel = "object-cost-v1"
      }

let failure =
      { maxFailedWriteSetsPerWindow = 4
      , failureWindow = V.d 60
      , orphanGcHorizon = V.d 3600
      }

let objectDemand
    : Storage.ObjectStoreDemand
    = { budget = "object-budget"
      , committedResident =
        [ { key =
            { store = "minio"
            , tenant = "trivial"
            , bucket = "content"
            , key = "seed"
            }
          , value = V.b 4096
          }
        ]
      , retention =
        { maxAdditionalResidentExtents =
          { head = extent
          , tail =
              [] : List { count : Natural, maxBytesEach : Storage.ByteQuantity }
          }
        , maxRetention = V.d 604800
        }
      , writes =
        { maxConcurrentWriteSets = 2
        , maxWriteSet =
          { head = extent
          , tail =
              [] : List { count : Natural, maxBytesEach : Storage.ByteQuantity }
          }
        , failure
        }
      , mutationAdmission = admission
      }

let vaultObject =
      { identity = "kv/trivial"
      , kind = < Kv | TransitKey | Pki | Auth | Lease >.Kv
      , versions = 10
      , maxPayloadBytes = V.b 65536
      }

let vault
    : Storage.VaultStorageDemand
    = { persisted =
        { head = vaultObject
        , tail =
            [] : List
                   { identity : Text
                   , kind : < Kv | TransitKey | Pki | Auth | Lease >
                   , versions : Natural
                   , maxPayloadBytes : Storage.ByteQuantity
                   }
        }
      , maxActiveLeases = 1000
      , raftModel = "vault-raft-v1"
      , raftVolumes =
        { head =
          { claim = V.claim
          , backing = "retained"
          , presentation = V.volumePresentation
          }
        , tail =
            [] : List
                   { claim : Storage.StatefulSetClaimSlot
                   , backing : Text
                   , presentation : Storage.VolumePresentation
                   }
        }
      , audit =
        { maxBytesPerFile = V.b 10485760
        , maxBackups = 5
        , retention = V.d 604800
        , backing =
            < PodEphemeral : { volume : Text }
            | Retained :
                { claim : Storage.StatefulSetClaimSlot
                , backing : Text
                , presentation : Storage.VolumePresentation
                }
            >.Retained
              { claim = V.claim
              , backing = "retained"
              , presentation = V.volumePresentation
              }
        }
      }

let bookKeeperLogical
    : Storage.BookKeeperLogicalDemand
    = { retainedHotBytes = V.b 1073741824
      , openLedgerHeadroom = V.b 134217728
      , inFlightOffloadBytes = V.b 268435456
      , deletionLagBytes = V.b 67108864
      }

let zooKeeperEntry =
      { path = "/amoebius/trivial"
      , maxPayloadBytes = V.b 65536
      , lifetime = < Persistent | SessionEphemeral : Text >.Persistent
      }

let zooKeeperMember =
      { id = "zk-0", resource = V.podEnvelope, volume = V.volume }

let pulsarMetadata
    : Resources.PulsarMetadataStoreDemand
    = Resources.PulsarMetadataStoreDemand.ZooKeeper
        { members =
          { head = zooKeeperMember
          , tail = [] : List Resources.ZooKeeperMemberDemand
          }
        , entries =
          { head = zooKeeperEntry
          , tail = [] : List Resources.ZooKeeperMetadataEntryDemand
          }
        , churn =
          { maxTransactionsPerWindow = 1000
          , transactionWindow = V.d 60
          , maxConcurrentSessions = 100
          , maxWatches = 1000
          , retainedSnapshots = 3
          , retainedTransactionLogs = 4
          , maxUnavailableMembers = 1
          }
        , model = "zookeeper-v1"
        }

let stateField =
      { path = "resources.app.id"
      , maxCanonicalBytes = V.b 4096
      , secrecy = < Plain | Secret >.Plain
      }

let stateEntry =
      { identity = "urn:app"
      , fields =
        { head = stateField, tail = [] : List Storage.PulumiStateFieldDemand }
      }

let plugin =
      { identity = "aws"
      , digest = "sha256:pulumi-aws"
      , installedBytes = V.b 104857600
      , peakInstallBytes = V.b 157286400
      }

let deploy =
      { id = "app-infrastructure"
      , executionUnit = "pulumi-executor"
      , dependsOn = [] : List Text
      , state =
        { head = stateEntry, tail = [] : List Storage.PulumiStateEntryDemand }
      , plugins = { head = "aws", tail = [] : List Text }
      , cache = V.inClusterCache
      }

let pulumi
    : Storage.PulumiExecutionDemand
    = { deploys = { head = deploy, tail = [] : List Storage.PulumiDeployUnit }
      , concurrency = < Serial | BoundedParallel : Natural >.Serial
      , plugins = { head = plugin, tail = [] : List Storage.PulumiPluginDemand }
      , pluginVolume = "pulumi-plugins"
      , workspaceVolume = "pulumi-workspace"
      , model = "pulumi-cost-v1"
      }

let assetMaterialization
    : Storage.AssetMaterializationDemand
    = { asset = "model-a"
      , digest = "sha256:model-a"
      , residentBytes = V.b 1048576
      , temporaryBytes = V.b 524288
      , cache = V.hostCache
      }

let registryIntent
    : Storage.RegistryStorageIntent
    = { budget = "registry-budget"
      , artifacts = { head = "sha256:index", tail = [] : List Text }
      , upload =
        { concurrency = < Serial | BoundedParallel : Natural >.BoundedParallel 2
        , failureWindow = V.d 60
        , maxFailedUploadsPerWindow = 3
        , failedUploadGcHorizon = V.d 3600
        , model = "registry-upload-v1"
        }
      , mutationAdmission =
        { model = "registry-admission-v1"
        , publisher = "trivial-build"
        , costModel = "registry-cost-v1"
        }
      , backend = Storage.RegistryBackend.Minio { store = "minio" }
      }

let priorVolume
    : Storage.PriorProvisionRefSource
    = { deployment = "trivial"
      , generation = 1
      , resource = Storage.PriorProvisionResource.Volume V.claim
      }

let storageMigration
    : Storage.StorageMigrationIntent
    = { identity = "move-app-data"
      , old = priorVolume
      , replacement = V.volume
      , policy =
        { model = "storage-copy-v1"
        , workspaceBacking = "retained"
        , copyConcurrency = 2
        , copyChunkBytes = V.b 4194304
        }
      }

let schemaObject =
      { identity = "table/widgets"
      , kind = < Table | Index | Constraint | MaterializedView >.Table
      , maxBytes = V.b 1073741824
      }

let schemaMigration
    : Storage.SchemaMigrationIntent
    = { identity = "widgets-v2"
      , database = "trivial-db"
      , dataBacking = "retained"
      , old = [ { key = "widgets", value = schemaObject } ]
      , replacement = [ { key = "widgets", value = schemaObject } ]
      , policy =
        { model = "schema-cost-v1"
        , maxConcurrentOperations = 1
        , workspaceBacking = "retained"
        }
      }

let priorRegistry
    : Storage.PriorProvisionRefSource
    = { deployment = "trivial"
      , generation = 1
      , resource = Storage.PriorProvisionResource.Registry "registry-budget"
      }

let registryMigration
    : Storage.RegistryBackendMigrationIntent
    = { identity = "registry-to-minio"
      , source = priorRegistry
      , replacement = registryIntent
      , policy =
        { model = "registry-copy-v1"
        , workspaceVolume = "registry-workspace"
        , copyConcurrency = 2
        }
      }

let sql
    : Storage.PatroniSqlIntent
    = { database = "trivial-db"
      , budget = "durable-budget"
      , storage =
        { objects =
          { head = schemaObject, tail = [] : List Storage.SchemaObjectDemand }
        , maxWalBytes = V.b 1073741824
        , checkpointBytes = V.b 536870912
        , failoverReplayBytes = V.b 268435456
        , recoveryWorkspaceBytes = V.b 1073741824
        , model = "patroni-storage-v1"
        }
      , volume = V.volume
      , mutation =
        { writer = "trivial-api"
        , maxConnections = 50
        , maxConcurrentTransactions = 20
        , maxTransactionsPerWindow = 1000
        , transactionWindow = V.d 60
        , maxWalBytesPerTransaction = V.b 1048576
        , costModel = "sql-admission-v1"
        }
      }

in    { name = "trivial-app"
      , capabilities =
        [ Capability.objectStore
        , Capability.messageBus
        , Capability.identity
        , Capability.edge
        ]
      , storage =
          Storage.fixed "trivial-data" (V.b 10737418240) V.volumePresentation
      , topic =
        { topic = "persistent://trivial/events"
        , tieredBacking = "trivial-events-tier"
        , retention = Retention.sizeBounded 1073741824 536870912 10737418240
        }
      , workloads =
        { head = V.workload, tail = [] : List Resources.ExecutionUnitIntent }
      , image = V.image
      , build = V.build
      , bookKeeperLogical
      , pulsarMetadata
      , pulumi
      , assetMaterializations =
        { head = assetMaterialization
        , tail = [] : List Storage.AssetMaterializationDemand
        }
      , storageBudgets =
        { head =
            Storage.StorageBudget.Durable
              { id = "durable-budget"
              , owner = "trivial-app"
              , ceiling = V.b 10737418240
              }
        , tail =
          [ Storage.StorageBudget.ObjectStore
              { id = "object-budget"
              , owner = "trivial-app"
              , ceiling = V.b 10737418240
              }
          , Storage.StorageBudget.Registry
              { id = "registry-budget"
              , owner = "trivial-app"
              , ceiling = V.b 21474836480
              }
          ]
        }
      , objectStoreProducers =
        [ Storage.ObjectStoreProducerIntent.AppBucket objectDemand
        , Storage.ObjectStoreProducerIntent.Registry registryIntent
        ]
      , objectStoreGateways =
        [ { gateway = "minio-admission", model = "gateway-v1" } ]
      , storageMigrations = [ storageMigration ]
      , schemaMigrations = [ schemaMigration ]
      , registryMigrations = [ registryMigration ]
      , sql = [ sql ]
      , vault = Some vault
      }
    : App.Type
