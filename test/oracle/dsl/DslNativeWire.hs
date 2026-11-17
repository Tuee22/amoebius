{-# LANGUAGE OverloadedStrings #-}

-- | Expected Pulsar connect command and frame bytes, independent of the client.
module DslNativeWire (nativeWireRows) where

import Data.Text qualified as Text
import Data.List (sort)
import DslParse (Row, check, readText)

nativeWireRows :: FilePath -> IO [Row]
nativeWireRows path = do
  input <- readText path
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) input
      expected =
        [ ("connect", ["0000001f0000001b080212170a13616d6f65626975732d70756c7361722f302e31200f"])
        , ("decoded", ["BaseCommand'CONNECT", "False", "0"])
        ]
      names = [name | name : _ <- rows]
  pure (check "wire-native.discovery" (sort names == sort (map fst expected) && length rows == length expected) "frame inventory"
    : [check ("wire-native." <> name) ([values | key : values <- rows, key == name] == [value]) "native frame or decoded summary differs from the wire contract" | (name, value) <- expected])
