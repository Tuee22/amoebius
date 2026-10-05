{-# LANGUAGE OverloadedStrings #-}

-- | The constants the pipeline fixes that no authored field decides: the provision
-- policy, the generation, the snapshot of the materialised supply, and the label the
-- provision context carries. They live apart from the stage modules so that no stage
-- holds a number that none of its output shows.
module Amoebius.Dsl.Policy
  ( provisionPolicy
  , provisionGeneration
  , supplySnapshot
  , deploymentLabel
  ) where

import Amoebius.Capacity.Provision (ProvisionPolicy (..))
import Data.Text (Text)
import Numeric.Natural (Natural)

provisionPolicy :: ProvisionPolicy
provisionPolicy =
  ProvisionPolicy
    { policyRuntimeBackingBytes = 100000
    , policyStorageBackingBytes = 1099511627776
    , policyMonitoringWorkflowLimit = 1000
    , policyMonitoringRuleLimit = 2000
    , policyMonitoringSeriesLimit = 10000
    , policyMonitoringVolumeBytes = 100000
    , policyCudaAvailable = False
    , policyAllocatableVramBytes = 100000
    , policyTargetOffering = Nothing
    }

provisionGeneration :: Natural
provisionGeneration = 1

supplySnapshot :: Natural
supplySnapshot = 1

deploymentLabel :: Text
deploymentLabel = "spine"
