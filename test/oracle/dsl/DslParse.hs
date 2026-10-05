{-# LANGUAGE OverloadedStrings #-}

-- | What the oracle needs to read the bytes it is given: rows, tab-separated tables, the
-- concatenated manifest arrays, and digests. Every read is guarded, so a missing or
-- garbled file yields a red row and never a crash.
module DslParse
  ( Row (..)
  , check
  , expectEqual
  , renderRow
  , rowGreen
  , rowNamed
  , readBytes
  , readText
  , readTable
  , exists
  , Payload
  , splitPayloads
  , Manifested (..)
  , parseObject
  , differingPaths
  , sha256Hex
  , truncateText
  ) where

import Control.Exception (SomeException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.Char (intToDigit)
import Data.Foldable (toList)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.Encoding.Error qualified as EncodingError
import System.Directory (doesFileExist)

-- | One line of the ledger: a name, a verdict, and a short observation.
data Row = Row Text Bool Text

rowGreen :: Row -> Bool
rowGreen (Row _ verdict _) = verdict

rowNamed :: Row -> Text
rowNamed (Row name _ _) = name

renderRow :: Row -> String
renderRow (Row name verdict observed) = Text.unpack (Text.intercalate "\t" [name, if verdict then "green" else "red", Text.replace "\t" " " (Text.replace "\n" " " observed)])

-- | A green row says only that it holds; a red row says why.
check :: Text -> Bool -> Text -> Row
check name verdict detail = Row name verdict (if verdict then "ok" else truncateText detail)

expectEqual :: (Eq value, Show value) => Text -> value -> Maybe value -> Row
expectEqual name expected actual = case actual of
  Nothing -> Row name False "the artefact is absent or unreadable"
  Just value
    | value == expected -> Row name True "ok"
    | otherwise -> Row name False (truncateText ("expected " <> Text.pack (show expected) <> " observed " <> Text.pack (show value)))

truncateText :: Text -> Text
truncateText text = if Text.length text > 400 then Text.take 400 text <> "..." else text

readBytes :: FilePath -> IO (Maybe ByteString)
readBytes path = do
  outcome <- try (ByteString.readFile path) :: IO (Either SomeException ByteString)
  pure (either (const Nothing) Just outcome)

readText :: FilePath -> IO (Maybe Text)
readText path = fmap (Encoding.decodeUtf8With EncodingError.lenientDecode) <$> readBytes path

-- | A table of tab-separated lines.
readTable :: FilePath -> IO (Maybe [[Text]])
readTable path = fmap (map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines) <$> readText path

exists :: FilePath -> IO Bool
exists = doesFileExist

sha256Hex :: ByteString -> Text
sha256Hex bytes = Text.pack (concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) (ByteString.unpack (SHA256.hash bytes)))

-- | One array of the manifest, as the bytes the executor received.
type Payload = ByteString

-- | The manifest is a concatenation of pretty-printed arrays; each ends at a line that is
-- exactly a closing bracket.
splitPayloads :: ByteString -> [Payload]
splitPayloads bytes = go (Char8.lines bytes) []
 where
  go remaining current = case remaining of
    [] -> [Char8.unlines (reverse current) | not (null current)]
    line : rest
      | line == "]" -> Char8.unlines (reverse (line : current)) : go rest []
      | otherwise -> go rest (line : current)

-- | The fields of an object that the oracle judges.
data Manifested = Manifested
  { mApiVersion :: Text
  , mKind :: Text
  , mName :: Text
  , mNamespace :: Maybe Text
  , mLabels :: Map Text Text
  , mAnnotations :: Map Text Text
  , mSpec :: Value
  , mValue :: Value
  }

-- | A payload is an array of exactly one object.
parseObject :: Payload -> Maybe Manifested
parseObject payload = case eitherDecodeStrict' payload of
  Right (Array items) | [value] <- toList items -> objectOf value
  _ -> Nothing

objectOf :: Value -> Maybe Manifested
objectOf value = do
  root <- asObject value
  apiVersion <- field "apiVersion" root >>= asText
  kind <- field "kind" root >>= asText
  metadata <- field "metadata" root >>= asObject
  name <- field "name" metadata >>= asText
  labels <- field "labels" metadata >>= asObject >>= textMap
  annotations <- field "annotations" metadata >>= asObject >>= textMap
  specification <- field "spec" root
  let namespace = field "namespace" metadata >>= asText
  pure (Manifested apiVersion kind name namespace labels annotations specification value)

field :: Text -> KeyMap.KeyMap Value -> Maybe Value
field name = KeyMap.lookup (Key.fromText name)

asObject :: Value -> Maybe (KeyMap.KeyMap Value)
asObject value = case value of
  Object fields -> Just fields
  _ -> Nothing

asText :: Value -> Maybe Text
asText value = case value of
  String text -> Just text
  _ -> Nothing

textMap :: KeyMap.KeyMap Value -> Maybe (Map Text Text)
textMap fields = Map.fromList <$> traverse (\(key, value) -> (,) (Key.toText key) <$> asText value) (KeyMap.toList fields)

-- | The paths at which two JSON values differ; an array is compared element by element.
differingPaths :: Value -> Value -> [Text]
differingPaths left right = sort (go "" left right)
 where
  go path a b = case (a, b) of
    (Object x, Object y) ->
      concat
        [ go (path <> "." <> Key.toText key) (fromMaybe Null (KeyMap.lookup key x)) (fromMaybe Null (KeyMap.lookup key y))
        | key <- Map.keys (Map.fromList [(key, ()) | key <- KeyMap.keys x <> KeyMap.keys y])
        ]
    (Array x, Array y)
      | length x == length y -> concat [go (path <> "[" <> Text.pack (show index) <> "]") p q | (index, p, q) <- zip3 [0 :: Int ..] (toList x) (toList y)]
    _ -> [path | a /= b]
