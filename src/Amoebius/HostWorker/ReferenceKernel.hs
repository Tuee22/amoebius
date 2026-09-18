{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostWorker.ReferenceKernel
  ( referenceKernel
  , encodeFloat32Le
  , renderFixedMsl
  ) where

import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder (floatLE, toLazyByteString)
import Data.ByteString.Lazy qualified as LazyByteString

-- | The independently pinned Phase-53 numerical contract: y = 2*x + 1,
-- rounded at Float precision and emitted as little-endian IEEE-754 bytes.
referenceKernel :: [Float] -> ByteString
referenceKernel values = encodeFloat32Le (fmap (\value -> 2 * value + 1) values)

encodeFloat32Le :: [Float] -> ByteString
encodeFloat32Le = LazyByteString.toStrict . toLazyByteString . foldMap floatLE

renderFixedMsl :: ByteString
renderFixedMsl = ByteString.intercalate "\n"
  [ "#include <metal_stdlib>"
  , "using namespace metal;"
  , "kernel void phase53(device const float* input [[buffer(0)]],"
  , "                    device float* output [[buffer(1)]],"
  , "                    uint i [[thread_position_in_grid]]) {"
  , "  output[i] = (2.0f * input[i]) + 1.0f;"
  , "}"
  ]
