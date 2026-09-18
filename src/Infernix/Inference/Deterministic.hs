{-# LANGUAGE OverloadedStrings #-}

module Infernix.Inference.Deterministic
  ( deterministicCpuDecode
  ) where

import Amoebius.Kernel.ContentAddress (blobShaText, contentAddress)
import Amoebius.Kernel.Rng (SplitMixSeed, splitMixSeedWord64)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as Char8
import Data.Text qualified as Text
import Numeric (showHex)

deterministicCpuDecode :: ByteString -> ByteString -> SplitMixSeed -> ByteString
deterministicCpuDecode model normalizedInput requestedSeed =
  Char8.pack (Text.unpack digest <> "\n")
 where
  seedWord = splitMixSeedWord64 requestedSeed
  seedHex = leftPad16 (showHex seedWord "")
  preimage = model <> "|" <> normalizedInput <> "|" <> Char8.pack seedHex
  digest = Text.drop 7 (blobShaText (contentAddress preimage))
  leftPad16 value = replicate (16 - length value) '0' <> value
