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
  manifest <- Text.readFile "test/mutant/registry.tsv"
  case findVariant mutant (Text.lines manifest) of
    Nothing -> pure False
    Just variant -> case Map.lookup variant fixtures of
      Nothing -> pure False
      Just fixture -> pure (phase9Negative fixture == Left (phase9Expected fixture) && phase9Positive fixture == Right ())
 where
  fixtures = Map.fromList [(phase9Variant fixture, fixture) | fixture <- phase9Fixtures]

-- The one mutant registry carries four fixed columns and each capability's own fields as
-- `key=value` pairs in the fifth, because the eighteen tables it replaced used eight
-- different schemas and flattening them would have made five of them say something else.
-- This capability's second column was `variant`, so that is the key read back.
findVariant :: Text -> [Text] -> Maybe Text
findVariant mutant rows = case rows of
  [] -> Nothing
  row : remaining -> case Text.splitOn "\t" row of
    [capability, name, _body, _flag, detail]
      | capability == "execution_accelerator" && name == mutant -> detailField "variant" detail
      | otherwise -> findVariant mutant remaining
    _ -> findVariant mutant remaining

detailField :: Text -> Text -> Maybe Text
detailField key detail =
  case [value | pair <- Text.splitOn ";" detail
              , (name, value) <- [Text.breakOn "=" pair]
              , Text.strip name == key] of
    found : _ -> Just (Text.strip (Text.drop 1 found))
    [] -> Nothing
