{-# LANGUAGE OverloadedStrings #-}

module ReferencePlanner
  ( referencePlan
  ) where

import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- This observer intentionally owns a flat textual vocabulary and imports no
-- production reconcile module. It is a second reading of the authored corpus.
referencePlan :: Text -> Text -> Either Text [Text]
referencePlan desiredSource observedSource = do
  desired <- parseMap desiredSource
  observed <- parseMap observedSource
  let missing = Set.toAscList (Map.keysSet desired `Set.difference` Map.keysSet observed)
      unreachable =
        [identifier | (identifier, value) <- Map.toAscList observed, "unreachable:" `Text.isPrefixOf` value]
      domain = Set.toAscList (Map.keysSet desired `Set.union` Map.keysSet observed)
  if not (null unreachable)
    then Left ("unreachable:" <> Text.intercalate "," unreachable)
    else if not (null missing)
      then Left ("missing:" <> Text.intercalate "," missing)
      else Right (sort (concatMap (decide desired observed) domain))

decide :: Map Text Text -> Map Text Text -> Text -> [Text]
decide desired observed identifier = case (Map.lookup identifier desired, Map.lookup identifier observed) of
  (Just wanted, Just "absent") -> ["create:" <> identifier <> "@" <> wanted]
  (Just wanted, Just current)
    | Just revision <- Text.stripPrefix "present:" current
    , revision /= wanted -> ["apply:" <> identifier <> ":" <> revision <> "->" <> wanted]
    | otherwise -> []
  (Nothing, Just current)
    | Just revision <- Text.stripPrefix "present:" current -> ["delete:" <> identifier <> "@" <> revision]
    | otherwise -> []
  _ -> []

parseMap :: Text -> Either Text (Map Text Text)
parseMap source
  | source == "-" = Right Map.empty
  | otherwise = Map.fromList <$> mapM parseEntry (Text.splitOn ";" source)
 where
  parseEntry entry = case Text.breakOn "=" entry of
    (key, value)
      | Text.null key || Text.null value -> Left ("invalid entry:" <> entry)
      | otherwise -> Right (key, Text.drop 1 value)
