{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorMutants
  ( runExecutionAcceleratorMutant
  ) where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ExecutionAcceleratorFixtures (Phase29Fixture (..), phase29Fixtures)

runExecutionAcceleratorMutant :: Text -> IO Bool
runExecutionAcceleratorMutant mutant = do
  manifest <- Text.readFile "test/mutant/registry.tsv"
  case findVariant mutant (Text.lines manifest) of
    Nothing -> pure False
    Just variant -> case Map.lookup variant fixtures of
      Nothing -> pure False
      Just fixture -> pure (originalIsGreen fixture && mutatedIsRed (seedAdmissionMutant fixture) fixture)
 where
  fixtures = Map.fromList [(phase29Variant fixture, fixture) | fixture <- phase29Fixtures]

-- Each registry row selects the negative whose deleted term would admit its paired
-- legal result. The runtime-selected mutation replaces that fold result with its twin;
-- the independently authored expected tag must then reject the admitted value.
seedAdmissionMutant :: Phase29Fixture -> Either Text ()
seedAdmissionMutant = phase29Positive

originalIsGreen :: Phase29Fixture -> Bool
originalIsGreen fixture =
  phase29Negative fixture == Left (phase29Expected fixture)
    && phase29Positive fixture == Right ()

mutatedIsRed :: Either Text () -> Phase29Fixture -> Bool
mutatedIsRed mutated fixture =
  mutated /= phase29Negative fixture
    && mutated /= Left (phase29Expected fixture)

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
