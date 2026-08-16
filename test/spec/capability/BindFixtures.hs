{-# LANGUAGE OverloadedStrings #-}

module BindFixtures
  ( CapabilityFixture (..)
  , capabilityFixtures
  , oracleArms
  , singleBinding
  , distributedBinding
  , fixturePath
  , goldenPath
  ) where

import Amoebius.Capability.Types
  ( CapabilityArm (..)
  , CapabilityBinding (CapabilityBinding)
  , CapabilityNeed (..)
  , CapabilityProvider (CanonicalProvider)
  , EngineRuntime (Cuda)
  , InferenceEngineNeed (InferenceEngineNeed)
  , ServiceShape (..)
  )
import Data.Text (Text)
import Data.Text qualified as Text

data CapabilityFixture = CapabilityFixture
  { fixtureSlug :: Text
  , fixtureArm :: CapabilityArm
  , fixtureNeed :: CapabilityNeed
  }
  deriving stock (Eq, Show)

-- Independently pinned arm list: this list, rather than bind's case split,
-- defines the exhaustiveness obligation for the corpus.
oracleArms :: [CapabilityArm]
oracleArms =
  [ ObjectStore
  , SecretStore
  , MessageBus
  , Sql
  , Identity
  , Observability
  , Registry
  , Edge
  , InferenceEngine
  ]

capabilityFixtures :: [CapabilityFixture]
capabilityFixtures =
  [ CapabilityFixture "objectstore" ObjectStore (ObjectStoreNeed "assets")
  , CapabilityFixture "secretstore" SecretStore (SecretStoreNeed "secrets")
  , CapabilityFixture "messagebus" MessageBus (MessageBusNeed "events")
  , CapabilityFixture "sql" Sql (SqlNeed "database")
  , CapabilityFixture "identity" Identity (IdentityNeed "accounts")
  , CapabilityFixture "observability" Observability (ObservabilityNeed "telemetry")
  , CapabilityFixture "registry" Registry (RegistryNeed "images")
  , CapabilityFixture "edge" Edge (EdgeNeed "public-edge")
  , CapabilityFixture
      "inferenceengine"
      InferenceEngine
      (InferenceEngineCapabilityNeed (InferenceEngineNeed "inference" "llama-3" (Cuda "cuda-llama-3")))
  ]

singleBinding :: CapabilityBinding
singleBinding = CapabilityBinding CanonicalProvider SingleNode

distributedBinding :: CapabilityBinding
distributedBinding = CapabilityBinding CanonicalProvider (Distributed 3)

fixturePath :: CapabilityFixture -> ServiceShape -> FilePath
fixturePath fixture shape =
  "dhall/examples/legal_"
    <> Text.unpack (fixtureSlug fixture)
    <> "_"
    <> shapeSlug shape
    <> ".dhall"

goldenPath :: CapabilityFixture -> ServiceShape -> FilePath
goldenPath fixture shape =
  "test/golden/capability/golden_servicespec_"
    <> Text.unpack (fixtureSlug fixture)
    <> "_"
    <> shapeSlug shape
    <> ".golden"

shapeSlug :: ServiceShape -> String
shapeSlug shape = case shape of
  SingleNode -> "singlenode"
  Distributed _ -> "distributed"
