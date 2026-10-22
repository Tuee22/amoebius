{-# LANGUAGE OverloadedStrings #-}

-- Records the shipped codec over product-owned inputs. All expectations live
-- in the separate oracle; no private test corpus is introduced here.
module SpineExtensionCodec (extensionCodecSection) where

import Amoebius.Dsl.Decode (decodeRefusalTag, decodeRoot, dumpRoot)
import Amoebius.Dsl.Encode (encodeRaw, rawOf)
import Amoebius.Dsl.Examples.Extensions.CodecInputs (codecInputs)
import Amoebius.Dsl.Import (freezeText)
import Control.Monad (forM_)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing, makeAbsolute)
import System.FilePath ((</>))

extensionCodecSection :: FilePath -> IO ()
extensionCodecSection output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  inputs <- either (fail . Text.unpack) pure codecInputs
  forM_ inputs $ \(name, raw) -> do
    let target = directory </> Text.unpack name
        source = encodeRaw raw
    createDirectoryIfMissing True target
    Text.writeFile (target </> "input.dhall") source
    frozen <- freezeText target source
    case frozen of
      Left problem -> Text.writeFile (target </> "refusal.tsv") (Text.pack (show problem) <> "\n")
      Right value -> case decodeRoot value of
        Left problem -> Text.writeFile (target </> "refusal.tsv") (decodeRefusalTag problem <> "\n")
        Right decoded -> do
          Text.writeFile (target </> "decoded.dump") (dumpRoot decoded)
          Text.writeFile (target </> "roundtrip.tsv") (Text.pack (show (rawOf decoded == raw)) <> "\n")
  Text.writeFile (directory </> "inventory.tsv") (Text.unlines (map fst inputs))
