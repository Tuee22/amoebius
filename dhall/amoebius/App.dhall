let Capability = ./Capability.dhall

let Storage = ./Storage.dhall

let Retention = ./Retention.dhall

let Resources = ./Resources.dhall

let Image = ./Image.dhall

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let App =
      { name : Text
      , capabilities : List Capability.Type
      , storage : Storage.Type
      , topic : Retention.TopicLifecycle
      , workloads : NonEmpty Resources.ExecutionUnitIntent
      , image : Image.ImageArtifact
      , build : Image.BuildExecutionEnvelope
      , bookKeeperLogical : Storage.BookKeeperLogicalDemand
      , pulsarMetadata : Resources.PulsarMetadataStoreDemand
      , pulumi : Storage.PulumiExecutionDemand
      , assetMaterializations : NonEmpty Storage.AssetMaterializationDemand
      , storageBudgets : NonEmpty Storage.StorageBudget
      , objectStoreProducers : List Storage.ObjectStoreProducerIntent
      , objectStoreGateways : List Storage.ObjectStoreGatewayIntent
      , storageMigrations : List Storage.StorageMigrationIntent
      , schemaMigrations : List Storage.SchemaMigrationIntent
      , registryMigrations : List Storage.RegistryBackendMigrationIntent
      , sql : List Storage.PatroniSqlIntent
      , vault : Optional Storage.VaultStorageDemand
      }

in  { Type = App }
