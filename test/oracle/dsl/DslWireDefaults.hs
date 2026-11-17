{-# LANGUAGE OverloadedStrings #-}

-- | Independent protobuf encoding of the required default fields from the
-- separately authored wire specification. It does not import generated bindings.
module DslWireDefaults (wireRoundTripRows, wireLinkedRoundTripRows) where

import Data.Bits ((.&.), (.|.), shiftR)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word8)
import DslParse (Row, check, readText)
import DslWireSchema (wireEnums, wireMessages)
import Numeric (showHex)

type Field = (Text, Text, Text, Int, Maybe Text)
type WireEnum = (Text, [(Text, Int)])

varint :: Int -> [Word8]
varint value
  | value < 128 = [fromIntegral value]
  | otherwise = fromIntegral ((value .&. 127) .|. 128) : varint (value `shiftR` 7)

defaultMessage :: Text -> Maybe [Word8]
defaultMessage name = do
  (_, enums, fields) <- lookupMessage name
  concat <$> traverse (encodeField enums) [field | field@(label, _, _, _, _) <- fields, label == "required"]
 where
  lookupMessage wanted = case [entry | entry@(key, _, _) <- wireMessages, key == wanted] of
    [entry] -> Just entry
    _ -> Nothing

encodeField :: [WireEnum] -> Field -> Maybe [Word8]
encodeField local (_, kind, _, number, _) = do
  (wireType, payload) <- value
  pure (varint (number * 8 + wireType) <> payload)
 where
  value
    | kind `elem` ["string", "bytes"] = Just (2, [0])
    | kind `elem` ["uint64", "uint32", "int32", "int64", "bool"] = Just (0, [0])
    | otherwise = case lookup kind (local <> wireEnums) of
        Just ((_, number') : _) -> Just (0, varint number')
        Just [] -> Nothing
        Nothing -> do
          bytes <- defaultMessage kind
          pure (2, varint (length bytes) <> bytes)

hexBytes :: [Word8] -> Text
hexBytes = Text.pack . concatMap hex
 where
  hex byte = case showHex byte "" of [digit] -> ['0', digit]; digits -> digits

wireRoundTripRows :: FilePath -> IO [Row]
wireRoundTripRows = judge False

wireLinkedRoundTripRows :: FilePath -> IO [Row]
wireLinkedRoundTripRows = judge True

judge :: Bool -> FilePath -> IO [Row]
judge includeMalformed path = do
  input <- readText path
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) input
      expected = [(name, hexBytes <$> defaultMessage name, "True") | (name, _, _) <- wireMessages]
        <> [("MessageIdData-populated", Just "0807100b", "True")]
        <> [("MessageIdData-malformed", Just "80", "False") | includeMalformed]
      names = [name | [name, _, _] <- rows]
      one (name, wanted, expectedRecovery) =
        check ("wire-roundtrip." <> name)
          (case (wanted, [value | [key, value, recovery] <- rows, key == name, recovery == expectedRecovery]) of
             (Just bytes, [actual]) -> bytes == actual
             _ -> False)
          "generated encoding or round-trip differs from the independent wire expectation"
  pure (check "wire-roundtrip.discovery" (sort names == sort [name | (name, _, _) <- expected] && length rows == length expected)
    "generated message inventory" : map one expected)
