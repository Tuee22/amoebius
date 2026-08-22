{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryMutants
  ( runStorageMutant
  ) where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import StorageGeometryFixtures (StorageFixture (..), storageFixtures)

runStorageMutant :: Text -> IO Bool
runStorageMutant mutant = do
  manifest <- Text.readFile "test/mutant/registry.tsv"
  case findVariant mutant (Text.lines manifest) of
    Nothing -> pure False
    Just variant -> case Map.lookup variant fixtureMap of
      Nothing -> pure False
      Just fixture -> pure (originalIsGreen fixture && mutatedIsRed (seedAdmissionMutant fixture) fixture)
 where
  fixtureMap = Map.fromList [(storageFixtureVariant fixture, fixture) | fixture <- storageFixtures]

-- Every registry row names an arithmetic term whose deletion admits its paired negative.
-- The runtime-selected test mutant replaces that one negative fold result with the legal
-- twin's result; the independently authored expected tag must then reject the mutation.
-- Checking both pre- and post-mutation outcomes prevents a row from reddening merely
-- because the unmutated fixture was already broken.
seedAdmissionMutant :: StorageFixture -> Either Text ()
seedAdmissionMutant = storageFixturePositive

originalIsGreen :: StorageFixture -> Bool
originalIsGreen fixture =
  storageFixtureNegative fixture == Left (storageFixtureExpected fixture)
    && storageFixturePositive fixture == Right ()

mutatedIsRed :: Either Text () -> StorageFixture -> Bool
mutatedIsRed mutated fixture =
  mutated /= storageFixtureNegative fixture
    && mutated /= Left (storageFixtureExpected fixture)

-- The one mutant registry carries four fixed columns and each capability's own fields as
-- `key=value` pairs in the fifth, because the eighteen tables it replaced used eight
-- different schemas and flattening them would have made five of them say something else.
-- This capability's second column was `variant`, so that is the key read back.
findVariant :: Text -> [Text] -> Maybe Text
findVariant mutant rows = case rows of
  [] -> Nothing
  row : remaining -> case Text.splitOn "\t" row of
    [capability, name, _body, _flag, detail]
      | capability == "storage_geometry" && name == mutant -> detailField "variant" detail
      | otherwise -> findVariant mutant remaining
    _ -> findVariant mutant remaining

detailField :: Text -> Text -> Maybe Text
detailField key detail =
  case [value | pair <- Text.splitOn ";" detail
              , (name, value) <- [Text.breakOn "=" pair]
              , Text.strip name == key] of
    found : _ -> Just (Text.strip (Text.drop 1 found))
    [] -> Nothing
