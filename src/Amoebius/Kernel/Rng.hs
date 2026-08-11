{-# LANGUAGE CPP #-}

module Amoebius.Kernel.Rng
  ( SplitMixSeed
  , splitMixSeed
  , splitMixSeedWord64
  , deriveSplitMixSeed
  , deriveSplitMixSeedForWorker
  ) where

import Data.Bits (shiftR, xor)
import Data.Word (Word64)

newtype SplitMixSeed = SplitMixSeed Word64
  deriving stock (Eq, Ord, Show)

splitMixSeed :: Word64 -> SplitMixSeed
splitMixSeed = SplitMixSeed

splitMixSeedWord64 :: SplitMixSeed -> Word64
splitMixSeedWord64 (SplitMixSeed value) = value

deriveSplitMixSeed :: SplitMixSeed -> Word64 -> SplitMixSeed
deriveSplitMixSeed (SplitMixSeed master) streamIndex = SplitMixSeed (mix64 (master + gamma * (streamIndex + 1)))

deriveSplitMixSeedForWorker :: SplitMixSeed -> Word64 -> Word64 -> SplitMixSeed
deriveSplitMixSeedForWorker master streamIndex workerId =
#ifdef PHASE48_RNG_WORKERID_MUTANT
  deriveSplitMixSeed master (streamIndex + workerId)
#else
  let _ = workerId in deriveSplitMixSeed master streamIndex
#endif

gamma :: Word64
gamma = 0x9e3779b97f4a7c15

mix64 :: Word64 -> Word64
mix64 input = third `xor` (third `shiftR` 31)
 where
  first = (input `xor` (input `shiftR` 30)) * 0xbf58476d1ce4e5b9
  second = (first `xor` (first `shiftR` 27)) * 0x94d049bb133111eb
  third = second
