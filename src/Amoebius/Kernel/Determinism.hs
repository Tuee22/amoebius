{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Kernel.Determinism
  ( seededStage
  ) where

import Amoebius.Kernel.ContentAddress (blobShaText, contentAddress)
import Amoebius.Kernel.Rng (SplitMixSeed, splitMixSeedWord64)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as Char8
import Data.Text.Encoding qualified as Text

seededStage :: ByteString -> SplitMixSeed -> ByteString
seededStage input seed =
#ifdef DETERMINISM_JITCACHE_CONST_OUTPUT_MUTANT
  "determinism-jitcache-constant-output"
#else
  Text.encodeUtf8 (blobShaText (contentAddress (input <> Char8.pack (show (splitMixSeedWord64 seed)))))
#endif
