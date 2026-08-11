{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorMutants
  ( runExecutionAcceleratorMutant
  ) where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ExecutionAcceleratorFixtures (Phase9Fixture (..), phase9Fixtures)

runExecutionAcceleratorMutant :: Text -> IO Bool
runExecutionAcceleratorMutant mutant = do
  manifest <- Text.readFile "tests/mutants/phase9/mutants.tsv"
  case findVariant mutant (Text.lines manifest) of
    Nothing -> pure False
    Just variant -> case Map.lookup variant fixtures of
      Nothing -> pure False
      Just fixture -> pure (phase9Negative fixture == Left (phase9Expected fixture) && phase9Positive fixture == Right ())
 where
  fixtures = Map.fromList [(phase9Variant fixture, fixture) | fixture <- phase9Fixtures]

findVariant :: Text -> [Text] -> Maybe Text
findVariant mutant rows = case rows of
  [] -> Nothing
  row : remaining -> case Text.splitOn "\t" row of
    [name, variant, _]
      | name == mutant -> Just variant
      | otherwise -> findVariant mutant remaining
    _ -> findVariant mutant remaining
