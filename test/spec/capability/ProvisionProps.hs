{-# LANGUAGE OverloadedStrings #-}

module ProvisionProps
  ( runProvisionProps
  ) where

import Amoebius.Capacity.Provision
  ( InfrastructureDemand (..)
  , InfrastructureState (..)
  , ProvisionError
  , ProvisionTargetSupply (StandaloneRoot)
  , TargetSupply (TargetSupply)
  , deriveInfrastructureDemand
  , planInfrastructure
  , provisionErrorTag
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Capability.Types (BoundDeployment, ServiceShape (SingleNode))
import BindFixtures (CapabilityFixture)
import Control.Monad (unless)
import Data.Text (Text)
import ProvisionFixtures (fixtureDeployment)
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

runProvisionProps :: CapabilityFixture -> IO Int
runProvisionProps fixture = do
  deployment <- either (fail . show) pure (fixtureDeployment fixture SingleNode)
  result <- quickCheckWithResult stdArgs {chatty = False, maxSuccess = 400} (infrastructureBoundary deployment)
  unless (isSuccess result) (fail ("Phase-31 infrastructure property failed: " <> show result))
  putStrLn "provision-properties: TESTED exact infrastructure vs one-unit-short (accept/reject >=40%)"
  pure 1

infrastructureBoundary :: BoundDeployment -> Bool -> Property
infrastructureBoundary deployment exact =
  checkCoverage
    $ cover 40 exact "exact"
    $ cover 40 (not exact) "one-unit-short"
    $ counterexample (show outcome)
    $ property (if exact then isRight outcome else hasTag "InfrastructureDemandExceeded" outcome)
 where
  demand = deriveInfrastructureDemand deployment
  required = infrastructureRequiredResources demand
  available = if exact then required else shortCpu required
  supply = StandaloneRoot (TargetSupply InfrastructureCreationRequired available mempty 3)
  outcome = planInfrastructure supply deployment

shortCpu :: ResourceVector -> ResourceVector
shortCpu resources = resources {resourceCpu = resourceCpu resources - min 1 (resourceCpu resources)}

isRight :: Either problem value -> Bool
isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True

hasTag :: Text -> Either ProvisionError value -> Bool
hasTag expected outcome = case outcome of
  Left problem -> provisionErrorTag problem == expected
  Right _ -> False
