{-# LANGUAGE OverloadedStrings #-}

-- | Pulsar command and length-frame expectations, stated independently of
-- both the maintained fork and its generated protobuf bindings.
module DslForkWire (forkWireRows) where

import Data.List (sort)
import Data.Text qualified as Text
import DslParse (Row, check, readText)

forkWireRows :: FilePath -> IO [Row]
forkWireRows path = do
  input <- readText path
  let rows = maybe [] (map (Text.splitOn "\t") . Text.lines) input
      expected =
        [ ("ping", "00000009000000050812920100")
        , ("flow", "0000000c00000008080b5a040807100b")
        , ("send", "0000000c00000008080632040807100b")
        ]
      names = [name | [name, _] <- rows]
  pure (check "wire-fork.discovery" (sort names == sort (map fst expected) && length rows == length expected) "command inventory"
    : [check ("wire-fork." <> name) ([actual | [key, actual] <- rows, key == name] == [value]) "frame differs from the wire contract" | (name, value) <- expected])
