{-# LANGUAGE OverloadedStrings #-}

module BindProps
  ( runBindProps
  ) where

import Amoebius.Capability.Binding (bind)
import Amoebius.Capability.Types
  ( CapabilityArm (..)
  , CapabilityNeed (..)
  , EngineRuntime (..)
  , InferenceEngineNeed (InferenceEngineNeed)
  )
import BindFixtures (distributedBinding, singleBinding)
import Control.Monad (unless)
import ShapeOracle (structurallyDifferentByNodeMultiset, validateBoundExecutionInventory)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Args (chatty, maxSuccess)
  , Gen
  , Property
  , Result
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )

newtype GeneratedNeed = GeneratedNeed CapabilityNeed
  deriving stock (Show)

instance Arbitrary GeneratedNeed where
  arbitrary = GeneratedNeed <$> capabilityNeedGen

runBindProps :: IO Int
runBindProps = do
  result <- quickCheckWithResult stdArgs {chatty = False, maxSuccess = 1200} propBindTotalAndStructural
  unless (isSuccess result) (fail ("Phase-30 bind property failed: " <> showResult result))
  putStrLn "capability-bind-properties: TESTED sampled (1) with each of nine constructors >=8%"
  pure 1

propBindTotalAndStructural :: GeneratedNeed -> Property
propBindTotalAndStructural (GeneratedNeed need) =
  checkCoverage
    $ coverArm ObjectStore
    $ coverArm SecretStore
    $ coverArm MessageBus
    $ coverArm Sql
    $ coverArm Identity
    $ coverArm Observability
    $ coverArm Registry
    $ coverArm Edge
    $ coverArm InferenceEngine
    $ counterexample (show (single, distributed))
    $ property
      ( structurallyDifferentByNodeMultiset single distributed
          && validateBoundExecutionInventory single
          && validateBoundExecutionInventory distributed
      )
 where
  single = bind need singleBinding
  distributed = bind need distributedBinding
  selected = armOf need
  coverArm arm = cover 8 (selected == arm) (show arm)

capabilityNeedGen :: Gen CapabilityNeed
capabilityNeedGen = do
  arm <- chooseInt (0, 8)
  runtime <- engineRuntimeGen
  pure $ case arm of
    0 -> ObjectStoreNeed "generated-object"
    1 -> SecretStoreNeed "generated-secret"
    2 -> MessageBusNeed "generated-bus"
    3 -> SqlNeed "generated-sql"
    4 -> IdentityNeed "generated-identity"
    5 -> ObservabilityNeed "generated-observability"
    6 -> RegistryNeed "generated-registry"
    7 -> EdgeNeed "generated-edge"
    _ -> InferenceEngineCapabilityNeed (InferenceEngineNeed "generated-engine" "catalog-profile" runtime)

engineRuntimeGen :: Gen EngineRuntime
engineRuntimeGen = do
  lane <- chooseInt (0, 2)
  pure $ case lane of
    0 -> AppleMetal "metal-catalog"
    1 -> Cuda "cuda-catalog"
    _ -> LinuxCpu "cpu-catalog"

armOf :: CapabilityNeed -> CapabilityArm
armOf need = case need of
  ObjectStoreNeed _ -> ObjectStore
  SecretStoreNeed _ -> SecretStore
  MessageBusNeed _ -> MessageBus
  SqlNeed _ -> Sql
  IdentityNeed _ -> Identity
  ObservabilityNeed _ -> Observability
  RegistryNeed _ -> Registry
  EdgeNeed _ -> Edge
  InferenceEngineCapabilityNeed _ -> InferenceEngine

showResult :: Result -> String
showResult = show
