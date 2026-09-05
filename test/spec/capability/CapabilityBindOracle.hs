{-# LANGUAGE OverloadedStrings #-}

module CapabilityBindOracle
  ( OracleRow (..)
  , NegativeRow (..)
  , MutantSpec (..)
  , expectedRows
  , expectedNegatives
  , mutantSpecs
  , expectedCalculusProjection
  ) where

import Data.Text (Text)

data OracleRow = OracleRow
  { oracleSlug :: Text
  , oracleArm :: Text
  , oracleResource :: Text
  , oracleProduct :: Text
  , oracleMemberKind :: Text
  , oracleControllerKind :: Text
  , oracleHasBootstrap :: Bool
  , oracleSingleObjects :: Int
  , oracleDistributedObjects :: Int
  , oracleSingleExecutions :: Int
  , oracleDistributedExecutions :: Int
  , oracleIntentCount :: Int
  }
  deriving stock (Eq, Show)

data NegativeRow = NegativeRow
  { negativeName :: Text
  , negativeTag :: Text
  , negativeLocus :: Text
  }
  deriving stock (Eq, Show)

data MutantSpec = MutantSpec
  { mutantName :: Text
  , mutantFlag :: Text
  , mutantProductionLocus :: Text
  , mutantExpectedFailure :: Text
  }
  deriving stock (Eq, Show)

expectedRows :: [OracleRow]
expectedRows =
  [ row "objectstore" "ObjectStore" "assets" "MinIO" "StatefulSet" "StatefulSet" False 3 7 1 3 2
  , row "secretstore" "SecretStore" "secrets" "Vault" "StatefulSet" "StatefulSet" False 3 7 1 3 1
  , row "messagebus" "MessageBus" "events" "Pulsar" "StatefulSet" "StatefulSet" False 3 7 1 3 1
  , row "sql" "Sql" "database" "Patroni" "StatefulSet" "StatefulSet" True 4 8 2 4 2
  , row "identity" "Identity" "accounts" "Keycloak" "StatefulSet" "StatefulSet" False 3 7 1 3 1
  , row "observability" "Observability" "telemetry" "Prometheus" "StatefulSet" "StatefulSet" False 3 7 1 3 1
  , row "registry" "Registry" "images" "Distribution" "StatefulSet" "StatefulSet" False 3 7 1 3 1
  , row "edge" "Edge" "public-edge" "Envoy" "Deployment" "Deployment" False 3 7 1 3 1
  , row "inferenceengine" "InferenceEngine" "inference" "Infernix" "EngineWorkload" "DaemonSet" False 3 7 1 3 1
  ]
 where
  row = OracleRow

expectedNegatives :: [NegativeRow]
expectedNegatives =
  [ NegativeRow "illegal_product_in_app" "DhallTypeError" "capability union"
  , NegativeRow "illegal_engine_by_url" "DhallTypeError" "engine runtime union"
  , NegativeRow "illegal_shape_in_app" "DhallTypeError" "app capability record"
  , NegativeRow "illegal_unbuilt_provider" "UnbuiltProviderArm" "provider decoder"
  , NegativeRow "illegal_unbound_capability" "UnboundCapability" "binding coverage"
  , NegativeRow "illegal_cyclic_extension" "CyclicExtension" "extension requirements"
  , NegativeRow "illegal_shadowing_extension" "ShadowingExtension" "extension providers"
  ]

mutantSpecs :: [MutantSpec]
mutantSpecs =
  [ MutantSpec "copy-shape-tag" "capability-bind-copy-shape-tag-mutant" "providerGraph" "shape structural projection drifted"
  , MutantSpec "catchall-arm" "capability-bind-catchall-arm-mutant" "capabilityArm" "capability arm drifted"
  , MutantSpec "shared-app-import" "capability-bind-shared-app-import-mutant" "renderCapabilityNeedSurface" "app surface projection drifted"
  , MutantSpec "provisioned-value-in-bound-deployment" "capability-bind-provisioned-value-in-bound-deployment-mutant" "boundDeploymentIsUnprovisioned" "bound deployment crossed provision boundary"
  ]

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "capability-arms,bound-service-shapes,boundary-negatives,bind-property,mutant-evidence")
  , ("projection-counts", "9,18,7,1,4")
  , ("resource-vector", "5,39,0,0")
  ]
