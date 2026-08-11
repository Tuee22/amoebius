{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Dedup
import Control.Monad (unless)
import Data.List (permutations)
import Data.Set qualified as Set

main :: IO ()
main = do
  let original = [WorkId "a", WorkId "b", WorkId "c"]
      schedules = permutations (original <> original)
  mapM_ (checkSchedule (Set.fromList original)) schedules
  let (_, stable1) = applyOnce (WorkId "stable") emptyDedupState
      (duplicateApplied, stable2) = applyOnce (WorkId "stable") stable1
  unless (not duplicateApplied && stable1 == stable2) (fail "stable-key-mutant-not-red")
  case sequenceFromMessage 7 11 of
    Right value | value == 30064771083 -> pure ()
    result -> fail ("message-id-sequence-pack:" <> show result)
  case sequenceFromMessage 0x100000000 0 of
    Left LedgerOrEntryExceeds32Bits -> pure ()
    result -> fail ("message-id-overflow-not-foreclosed:" <> show result)
  putStrLn "pulsar-dedup-sim: PASS (720 reorder/duplicate schedules, stable-key mutant red)"

checkSchedule :: Set.Set WorkId -> [WorkId] -> IO ()
checkSchedule expected schedule = do
  let final = foldl apply emptyDedupState schedule
  unless (appliedWorkIds final == expected) (fail "exactly-once-effect-violation")
  where
    apply state work = snd (applyOnce work state)
