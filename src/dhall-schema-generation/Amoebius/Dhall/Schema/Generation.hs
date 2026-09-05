{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dhall.Schema.Generation
  ( SchemaModule (..)
  , CaseExpectation (..)
  , SchemaCase (..)
  , schemaModules
  , schemaCases
  , renderInventory
  , renderForeclosureLedger
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

data SchemaModule = SchemaModule
  { schemaModuleName :: Text
  , schemaModuleSource :: Text
  }
  deriving stock (Eq, Ord, Show)

data CaseExpectation = MustTypecheck | MustReject Text
  deriving stock (Eq, Ord, Show)

data SchemaCase = SchemaCase
  { schemaCaseName :: Text
  , schemaCasePairedPositive :: Maybe Text
  , schemaCaseExpectation :: CaseExpectation
  , schemaCaseSource :: Text
  }
  deriving stock (Eq, Ord, Show)

schemaModules :: [SchemaModule]
schemaModules =
  [ SchemaModule "App" "{ name : Text, capabilities : List Text, secret : Optional Text }"
  , SchemaModule "Backup" "< Disabled | Snapshot : { cadence : Text, retention : Natural } >"
  , SchemaModule "BakeCatalog" "List { name : Text, process : Text }"
  , SchemaModule "Capability" capabilitySource
  , SchemaModule "Capacity" "{ cpu : Natural, memory : Natural, storage : Natural }"
  , SchemaModule "Cluster" "{ name : Text, substrate : < Linux | Managed >, servers : < Single | Ha3 | Ha5 > }"
  , SchemaModule "Consistency" "< Strong | Eventual : { bound : Natural } >"
  , SchemaModule "Deployment" "{ cluster : Text, app : Text, transition : Text, monitoring : List Text }"
  , SchemaModule "Extension" "{ name : Text, monitoring : List Text }"
  , SchemaModule "Image" "{ identity : < KindNode | Base : Text | Runtime : { linked : List Text } >, process : Text, steps : List < Copy : Text | Package : Text > }"
  , SchemaModule "Resources" resourcesSource
  , SchemaModule "Retention" "< Time : { seconds : Natural } | Size : { bytes : Natural } >"
  , SchemaModule "SanctionedApi" "< ObjectStore | SecretStore | MessageBus | Sql | Identity | Observability | Registry | Edge | InferenceEngine >"
  , SchemaModule "SecretRef" secretRefSource
  , SchemaModule "Storage" "< Fixed : { bytes : Natural } | Growable : { floorBytes : Natural, policy : Text } >"
  , SchemaModule "Topology" "{ servers : < Single | Ha3 | Ha5 >, agents : < Fixed : Natural | Autoscaled : { floor : Natural, policy : Text } > }"
  , SchemaModule "UiOffline" "{ enabled : Bool, cacheBudget : Natural }"
  , SchemaModule "prelude/package" "{ nonEmptyText = \\(value : Text) -> value, positive = \\(value : Natural) -> value }"
  ]

capabilitySource :: Text
#ifdef DHALL_SCHEMA_CUSTOM_CAPABILITY_MUTANT
capabilitySource = "< ObjectStore | SecretStore | MessageBus | Sql | Identity | Observability | Registry | Edge | InferenceEngine | Custom : Text >"
#else
capabilitySource = "< ObjectStore | SecretStore | MessageBus | Sql | Identity | Observability | Registry | Edge | InferenceEngine >"
#endif

resourcesSource :: Text
#if defined(DHALL_SCHEMA_OPTIONAL_RESOURCE_MUTANT)
resourcesSource = "{ requests : Optional { cpu : Natural, memory : Natural, ephemeralStorage : Natural }, limits : { cpu : Natural, memory : Natural, ephemeralStorage : Natural } }"
#elif defined(DHALL_SCHEMA_RESOURCE_TYPE_MUTANT)
resourcesSource = "{ requests : { cpu : Natural, memory : Text, ephemeralStorage : Natural }, limits : { cpu : Natural, memory : Natural, ephemeralStorage : Natural } }"
#else
resourcesSource = "{ requests : { cpu : Natural, memory : Natural, ephemeralStorage : Natural }, limits : { cpu : Natural, memory : Natural, ephemeralStorage : Natural } }"
#endif

secretRefSource :: Text
#ifdef DHALL_SCHEMA_PLAINTEXT_SECRET_MUTANT
secretRefSource = "< Vault : { mount : Text, path : Text, field : Text } | TransitKey : { name : Text } | Prompt : { name : Text, purpose : Text } | PlainText : Text >"
#else
secretRefSource = "< Vault : { mount : Text, path : Text, field : Text } | TransitKey : { name : Text } | Prompt : { name : Text, purpose : Text } >"
#endif

schemaCases :: [SchemaCase]
schemaCases = positives <> negatives
 where
  positives =
    [ positive "legal_multisubstrate_cluster" "{ name = \"cluster\", substrate = < Linux | Managed >.Linux, servers = < Single | Ha3 | Ha5 >.Ha3 }"
    , positive "legal_managed_eks" "{ name = \"managed\", substrate = < Linux | Managed >.Managed, servers = < Single | Ha3 | Ha5 >.Ha5 }"
    , positive "trivial_app" "{ name = \"app\", capabilities = [ \"ObjectStore\" ], secret = Some \"vault/app\" }"
    , positive "legal_deployment_rules" "{ cluster = \"cluster\", app = \"app\", transition = \"rolling\", monitoring = [ \"metrics\" ] }"
    ]
  negatives =
    [ negative "product_named_capability" "trivial_app" "Pulsar" "let Capability = < ObjectStore | SecretStore | MessageBus > in Capability.Pulsar"
    , negative "insecure_ingress" "legal_multisubstrate_cluster" "Insecure" "let Ingress = < Disabled | Tls : Text > in Ingress.Insecure"
    , negative "missing_resource_envelope" "legal_deployment_rules" "resources" "({ id = \"worker\" } : { id : Text, resources : { cpu : Natural } })"
    , negative "unbounded_storage" "trivial_app" "Unbounded" "let Storage = < Fixed : { bytes : Natural } | Growable : { floorBytes : Natural, policy : Text } > in Storage.Unbounded"
    , negative "topic_without_retention" "trivial_app" "retention" "({ name = \"events\" } : { name : Text, retention : < Time : Natural | Size : Natural > })"
    , negative "growth_without_scaling_policy" "trivial_app" "policy" "({ floorBytes = 1 } : { floorBytes : Natural, policy : Text })"
    , negative "even_rke2_servers" "legal_multisubstrate_cluster" "Ha2" "let Servers = < Single | Ha3 | Ha5 > in Servers.Ha2"
    , negative "unsupported_substrate" "legal_multisubstrate_cluster" "Windows" "let Substrate = < Linux | Managed > in Substrate.Windows"
    , negative "foreign_image" "trivial_app" "Foreign" "let Image = < KindNode | Base : Text | Runtime : Text > in Image.Foreign"
    , negative "run_shell_bake_step" "trivial_app" "RunShell" "let Step = < Copy : Text | Package : Text > in Step.RunShell \"curl example\""
    , negative "container_without_process" "trivial_app" "process" "({ identity = \"base\" } : { identity : Text, process : Text })"
    , negative "plaintext_secret" "trivial_app" "SecretRef" "(\"plaintext\" : < Vault : { mount : Text, path : Text, field : Text } | TransitKey : { name : Text } | Prompt : { name : Text, purpose : Text } >)"
    , negative "import_env" "trivial_app" "ForbiddenImport:env" "env:HOME as Text"
    , negative "import_remote" "trivial_app" "ForbiddenImport:https" "https://example.invalid/schema.dhall"
    ]
  positive name source = SchemaCase name Nothing MustTypecheck source
  negative name pair locus source = SchemaCase name (Just pair) (MustReject locus) source

renderInventory :: Text
renderInventory = Text.unlines ("module" : map schemaModuleName schemaModules)

renderForeclosureLedger :: Text
renderForeclosureLedger =
  Text.unlines
    ( "case\tpair\tlayer\tresult"
        : [ schemaCaseName entry <> "\t" <> maybe "-" id (schemaCasePairedPositive entry) <> "\tGate-1\ttested"
          | entry <- schemaCases
          , MustReject _ <- [schemaCaseExpectation entry]
          ]
        <> ["malformed_received_body\t-\tgadt-decode\tUNVERIFIED", "runtime_enforcement\t-\truntime\tUNVERIFIED"]
    )
