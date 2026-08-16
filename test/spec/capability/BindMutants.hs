{-# LANGUAGE OverloadedStrings #-}

module BindMutants
  ( capabilityMutants
  , runCapabilityMutant
  ) where

import Amoebius.Capability.Binding (bind)
import Amoebius.Capability.Types
  ( BoundServiceSpec (..)
  , CapabilityNeed (SecretStoreNeed)
  , ProviderObject (ProviderObject)
  , ServiceShape (Distributed)
  )
import BindFixtures (capabilityFixtures, fixtureNeed, fixturePath, singleBinding)
import Data.Text (Text)
import Data.Text qualified as Text
import ShapeOracle (structurallyDifferentByNodeMultiset)

capabilityMutants :: [Text]
capabilityMutants =
  [ "mutant_copy_shape_tag"
  , "mutant_catchall_arm"
  , "mutant_shared_app_import"
  , "mutant_provisioned_value_in_bound_deployment"
  ]

runCapabilityMutant :: Text -> IO Bool
runCapabilityMutant mutant = case mutant of
  "mutant_copy_shape_tag" -> pure copyShapeTagCaught
  "mutant_catchall_arm" -> pure catchallArmCaught
  "mutant_shared_app_import" -> pure sharedImportCaught
  "mutant_provisioned_value_in_bound_deployment" -> pure provisionedFieldCaught
  _ -> pure False

copyShapeTagCaught :: Bool
copyShapeTagCaught = case capabilityFixtures of
  [] -> False
  first : _ ->
    let single = bind (fixtureNeed first) singleBinding
        copiedTag = ProviderObject "shape/Distributed(3)" "ScalarTag" "shape-tag" Nothing
        mutatedDistributed =
          single
            { boundShape = Distributed 3
            , boundProviderGraph = boundProviderGraph single <> [copiedTag]
            }
     in not (structurallyDifferentByNodeMultiset single mutatedDistributed)

catchallArmCaught :: Bool
catchallArmCaught = case capabilityFixtures of
  [] -> False
  first : _ ->
    let mutated = bind (fixtureNeed first) singleBinding
     in boundCapabilityNeed mutated /= SecretStoreNeed "secrets"

sharedImportCaught :: Bool
sharedImportCaught = case capabilityFixtures of
  [] -> False
  first : _ ->
    let path = fixturePath first (boundShape (bind (fixtureNeed first) singleBinding))
     in not (distinctComposedFiles path path)

provisionedFieldCaught :: Bool
provisionedFieldCaught = not (all (not . Text.isInfixOf "Provisioned") mutatedFields)
 where
  mutatedFields = normalFields <> ["boundProvisionedSpec"]

normalFields :: [Text]
normalFields =
  [ "boundDeploymentTransition"
  , "boundDeploymentServices"
  , "boundDeploymentExecutions"
  , "boundDeploymentControllerExplanations"
  , "boundPriorVolumeRef"
  , "boundPriorRegistryRef"
  ]

distinctComposedFiles :: FilePath -> FilePath -> Bool
distinctComposedFiles left right = left /= right
