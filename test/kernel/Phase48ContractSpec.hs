{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Jit.Cache
import Amoebius.Jit.CacheBudget
import Amoebius.Jit.CacheOwner
import Amoebius.Jit.Resolver
import Amoebius.Kernel.ContentAddress
import Amoebius.Kernel.Determinism
import Amoebius.Kernel.ExperimentHash
import Amoebius.Kernel.Rng
import Control.Monad (unless)
import Data.ByteString.Char8 qualified as Char8
import Data.Text qualified as Text
import Data.Word (Word64)
import System.Exit (die)

main :: IO ()
main = do
  contentContract
  experimentContract
  rngContract
  determinismContract
  capacityContract
  resolverContract
  pruningContract
  putStrLn "determinism-jitcache-contract: PASS (identity, seeds, capacity, resolve, reuse, prune)"

contentContract :: IO ()
contentContract = do
  let payload = catalogPayload LlamaCppCpu
  assert (blobShaText (contentAddress payload) == "sha256:f0f27f013c07a69471b7b4603eb273f6be42e9ba39fe7a242fd1fd090cf28387") "engine-content-address"
  assert (manifestContentAddress [("a", "1"), ("b", "2")] == manifestContentAddress [("b", "2"), ("a", "1")]) "mut-48-content-address-field-order-leak"

experimentContract :: IO ()
experimentContract = do
  real <- either (die . show) pure (mkSubstrateFingerprint "linux-cpu" (witnesses "ghc-9.12.4"))
  changed <- either (die . show) pure (mkSubstrateFingerprint "linux-cpu" (witnesses "ghc-0.0.48-fake"))
  let program = ResolvedDhall "metric=maximize"
      first = deriveExperimentHash program real
  assert (first == deriveExperimentHash program real) "experiment-hash-stability"
  assert (first /= deriveExperimentHash program changed) "mut-48-experiment-hash-const-fingerprint"
  assert (first /= deriveExperimentHash (ResolvedDhall "metric=minimize") real) "experiment-hash-program-sensitivity"
 where
  witnesses ghcVersion =
    [ FingerprintWitness "ghc" "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc" ghcVersion
    , FingerprintWitness "rts" "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc" "rts-1"
    , FingerprintWitness "isa" "/usr/bin/uname" "x86_64"
    , FingerprintWitness "libcAbi" "/usr/bin/ldd" "glibc"
    ]

rngContract :: IO ()
rngContract = do
  let master = splitMixSeed 0x0123456789abcdef
      expected = [(0, 0x157a3807a48faa9d), (1, 0xd573529b34a1d093), (37, 0x3dfafd29d7a4f68a)]
  mapM_ (checkSeed master) expected
  assert (deriveSplitMixSeedForWorker master 37 0 == deriveSplitMixSeedForWorker master 37 99) "mut-48-rng-workerid-mixed"
 where
  checkSeed master (stream, expected) = assert (splitMixSeedWord64 (deriveSplitMixSeed master stream) == expected) ("splitmix-stream-" <> show (stream :: Word64))

determinismContract :: IO ()
determinismContract = do
  let master = splitMixSeed 0x0123456789abcdef
      seed = deriveSplitMixSeed master 37
      sameA = seededStage "phase48-pinned-input-a" seed
      sameB = seededStage "phase48-pinned-input-a" seed
      altSeed = seededStage "phase48-pinned-input-a" (deriveSplitMixSeed master 1)
      altInput = seededStage "phase48-pinned-input-b" seed
  assert (sameA == sameB) "same-substrate-recompute"
  assert (sameA /= altSeed && sameA /= altInput) "mut-48-determinism-const-output"

capacityContract :: IO ()
capacityContract = do
  let assets = map asset ["asset-a", "asset-b", "asset-c"]
      base = CachePopulationDemand [] assets 2 160 192 224 32
  sealed <- either (die . show) pure (provisionCacheDemand base)
  assert (provisionedResidentBytes sealed == 96 && provisionedTemporaryBytes sealed == 56 && provisionedPeakBytes sealed == 152) "cache-peak-derived"
  assertTag (CachePeakExceedsBudget 152 151) (provisionCacheDemand base {populationCacheBudgetBytes = 151}) "cache-one-byte-over"
  let key = cacheKeyForBytes "asset-a"
      conflict = [AssetMaterializationDemand key 32 32, AssetMaterializationDemand key 33 32]
  assertTag ResidentSizeConflict (provisionCacheDemand base {populationSelected = conflict}) "cache-digest-size-conflict"
  let deleting = ObservedResident key 32 True Present
  assertTag DeletionNotObserved (provisionCacheDemand base {populationObserved = [deleting], populationSelected = []}) "cache-deletion-credit"
  assertTag (OwnerEphemeralUnderReserved 224 223) (provisionCacheDemand base {populationEphemeralRequestBytes = 223}) "cache-ephemeral-under-reserved"
 where
  asset bytes = AssetMaterializationDemand (cacheKeyForBytes bytes) 32 (if bytes == "asset-a" then 32 else 24)

resolverContract :: IO ()
resolverContract = do
  roundTrip <- either (die . ("mut-48-cache-resolver-integrity:" <>) . show) pure (serveTwoClients Build LlamaCppCpu)
  assert (not (receiptCacheHit (ownerFirstReceipt roundTrip)) && receiptArmExecuted (ownerFirstReceipt roundTrip) == Just Build) "first-miss-build"
  assert (receiptCacheHit (ownerSecondReceipt roundTrip) && receiptArmExecuted (ownerSecondReceipt roundTrip) == Nothing) "second-client-hit"
  assert (ownerResidentCount roundTrip == 1 && ownerHandleVersion roundTrip == "llama.cpp-cpu 0.1.0") "single-owner-resident"
  downloadRound <- either (die . ("mut-48-cache-resolver-integrity:" <>) . show) pure (serveTwoClients Download LlamaCppCpu)
  assert (receiptArmExecuted (ownerFirstReceipt downloadRound) == Just Download) "first-miss-download"

pruningContract :: IO ()
pruningContract = do
  let pinnedPayload = catalogPayload LlamaCppCpu
      unpinnedPayload = Char8.replicate 80 'u'
      state = storeResident True pinnedPayload (storeResident False unpinnedPayload emptyCache)
  -- The pinned catalog payload is 41 bytes, so its resident plus the 40-byte
  -- incoming object requires the exact 81-byte boundary after eviction.
  (_, pruned) <- either (die . Text.unpack) pure (pruneFor 81 40 state)
  assert (lookupResident (cacheKeyForBytes pinnedPayload) pruned /= Nothing) "pinned-resident-survives"
  assert (lookupResident (cacheKeyForBytes unpinnedPayload) pruned == Nothing && cacheBytes pruned <= 81) "mut-48-cache-prune-noop"

assertTag :: (Eq error, Show error) => error -> Either error value -> String -> IO ()
assertTag expected actual label = case actual of
  Left observed -> assert (observed == expected) label
  Right _ -> die label

assert :: Bool -> String -> IO ()
assert condition label = unless condition (die label)
