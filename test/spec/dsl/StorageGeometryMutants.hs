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
  manifest <- Text.readFile "test/mutant/storage_geometry/mutants.tsv"
  case findVariant mutant (Text.lines manifest) of
    Nothing -> pure False
    Just variant -> case Map.lookup variant fixtureMap of
      Nothing -> pure False
      Just fixture ->
        pure
          ( storageFixtureNegative fixture == Left (storageFixtureExpected fixture)
              && storageFixturePositive fixture == Right ()
          )
 where
  fixtureMap = Map.fromList [(storageFixtureVariant fixture, fixture) | fixture <- storageFixtures]

findVariant :: Text -> [Text] -> Maybe Text
findVariant mutant rows = case rows of
  [] -> Nothing
  row : remaining -> case Text.splitOn "\t" row of
    [name, variant, _]
      | name == mutant -> Just variant
      | otherwise -> findVariant mutant remaining
    _ -> findVariant mutant remaining
