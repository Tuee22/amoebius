{-# LANGUAGE OverloadedStrings #-}

module RuntimeStorageBindingProps
  ( expectedDesiredInstances
  , runRuntimeStorageBindingProps
  ) where

import Amoebius.Capacity.Execution (BoundExecutionUnit (..), ControllerBody (..))
import Amoebius.Capacity.Provision
  ( ProvisionError
  , ProvisionPolicy (..)
  , provisionErrorTag
  )
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (BoundExecutionSet)
  , ServiceShape (SingleNode)
  )
import BindFixtures (CapabilityFixture)
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Numeric.Natural (Natural)
import ProvisionFixtures
  ( baselinePolicy
  , fixtureDeployment
  , provisionFixtureWithPolicy
  )
import Test.QuickCheck
  ( Args (chatty, maxSuccess)
  , Property
  , checkCoverage
  , cover
  , counterexample
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )

expectedDesiredInstances :: BoundDeployment -> Int
expectedDesiredInstances deployment =
  sum (fmap (instancesForBody . executionBody) (Map.elems units))
 where
  BoundExecutionSet units = boundDeploymentExecutions deployment

instancesForBody :: ControllerBody -> Int
instancesForBody body = case body of
  DeploymentBody replicas _ -> fromIntegral replicas
  StatefulSetBody replicas _ -> fromIntegral replicas
  DaemonSetBody slots _ -> length slots
  JobBody completions parallelism _ _ -> fromIntegral (min completions parallelism)
  HostProcessBody slots _ -> length slots

runRuntimeStorageBindingProps :: CapabilityFixture -> IO Int
runRuntimeStorageBindingProps fixture = do
  deployment <- either (fail . show) pure (fixtureDeployment fixture SingleNode)
  let requiredBytes = fromIntegral (expectedDesiredInstances deployment * 7)
  result <-
    quickCheckWithResult
      stdArgs {chatty = False, maxSuccess = 400}
      (runtimeBoundary fixture requiredBytes)
  unless (isSuccess result) (fail ("Phase-32 runtime-storage property failed: " <> show result))
  putStrLn "provision-runtime-storage-properties: TESTED exact backing vs one-byte-short (accept/reject >=40%)"
  pure 1

runtimeBoundary :: CapabilityFixture -> Natural -> Bool -> Property
runtimeBoundary fixture requiredBytes exact =
  checkCoverage
    $ cover 40 exact "exact"
    $ cover 40 (not exact) "one-byte-short"
    $ counterexample (show outcome)
    $ property (if exact then isRight outcome else hasTag "RuntimeStorageProvisionFailure" outcome)
 where
  backing = if exact then requiredBytes else requiredBytes - min 1 requiredBytes
  policy = baselinePolicy {policyRuntimeBackingBytes = backing}
  outcome = provisionFixtureWithPolicy policy fixture SingleNode

isRight :: Either problem value -> Bool
isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True

hasTag :: Text -> Either ProvisionError value -> Bool
hasTag expected outcome = case outcome of
  Left problem -> provisionErrorTag problem == expected
  Right _ -> False
