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
import BindFixtures (capabilityFixtures, distributedBinding, fixtureNeed, fixturePath, singleBinding)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
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
  "mutant_provisioned_value_in_bound_deployment" -> provisionedFieldCaught
  _ -> pure False

copyShapeTagCaught :: Bool
copyShapeTagCaught = case capabilityFixtures of
  [] -> False
  first : _ ->
    let single = bind (fixtureNeed first) singleBinding
        distributed = bind (fixtureNeed first) distributedBinding
        copiedTag = ProviderObject "shape/Distributed(3)" "ScalarTag" "shape-tag" Nothing
        mutatedDistributed =
          single
            { boundShape = Distributed 3
            , boundProviderGraph = boundProviderGraph single <> [copiedTag]
            }
     in structurallyDifferentByNodeMultiset single distributed
          && not (structurallyDifferentByNodeMultiset single mutatedDistributed)

catchallArmCaught :: Bool
catchallArmCaught =
  let originals = [bind (fixtureNeed fixture) singleBinding | fixture <- capabilityFixtures]
      mutated = [bind (SecretStoreNeed "catchall") singleBinding | _fixture <- capabilityFixtures]
      originalsPreserveNeed = and (zipWith (==) (fmap boundCapabilityNeed originals) (fmap fixtureNeed capabilityFixtures))
      mutantChangesNeed = or (zipWith (/=) (fmap boundCapabilityNeed mutated) (fmap fixtureNeed capabilityFixtures))
   in length originals == 9 && originalsPreserveNeed && mutantChangesNeed

sharedImportCaught :: Bool
sharedImportCaught = case capabilityFixtures of
  [] -> False
  first : _ ->
    let singlePath = fixturePath first (boundShape (bind (fixtureNeed first) singleBinding))
        distributedPath = fixturePath first (boundShape (bind (fixtureNeed first) distributedBinding))
     in distinctComposedFiles singlePath distributedPath
          && not (distinctComposedFiles singlePath singlePath)

provisionedFieldCaught :: IO Bool
provisionedFieldCaught = do
  source <- TextIO.readFile "src/Amoebius/Capability/Types.hs"
  let declaration = deploymentDeclaration source
      mutatedDeclaration = declaration <> "\n  , boundProvisionedSpec :: ProvisionedSpec"
  pure (not (Text.null declaration) && noProvisionedValue declaration && not (noProvisionedValue mutatedDeclaration))

deploymentDeclaration :: Text -> Text
deploymentDeclaration source =
  let afterStart = snd (Text.breakOn "data BoundDeployment" source)
   in fst (Text.breakOn "data ExtensionName" afterStart)

noProvisionedValue :: Text -> Bool
noProvisionedValue = not . Text.isInfixOf "Provisioned"

distinctComposedFiles :: FilePath -> FilePath -> Bool
distinctComposedFiles left right = left /= right
