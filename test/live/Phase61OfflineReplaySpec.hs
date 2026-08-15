{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Offline.Outcome
import Amoebius.Ui.Offline.Receipt
import Amoebius.Ui.Offline.Replay
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  let scope = Scope "tenant-a" "alice" "program-a" 7
      foreignScope = Scope "tenant-b" "alice" "program-a" 7
      command = CommandId "command-infernix-1"
      receipt = Receipt command (Just (infernixWorkId command)) "ready-artifact"
      session = ReplaySession scope True True
      stale = ReplaySession scope False True
      incompatible = ReplaySession scope True False
  assertEqual "current session" (ReplayAdmitted scope) (admitReplay session)
  assertEqual "stale membership" (ReplayRefused DeniedMembership) (admitReplay stale)
  assertEqual "incompatible program" (ReplayRefused ReloadRequired) (admitReplay incompatible)
  owner <- either (die . show) pure (claimReplay (Tab "tab-a") noReplayOwner)
  assertLeft "second tab" (claimReplay (Tab "tab-b") owner)
  assertEqual "disconnect retains pending" (Outbox [command]) (disconnect (Outbox [command]))
  let (durable1, firstReceipt, firstEffect) = recordEffect scope receipt emptyDurableReceipts
      (durable2, secondReceipt, secondEffect) = recordEffect scope receipt durable1
  assert firstEffect "first effect absent"
  assert (not secondEffect) "exact replay duplicated effect"
  assertEqual "same receipt" firstReceipt secondReceipt
  assertEqual "durable repair" (Accepted receipt) (recoverOutcome scope command Nothing durable2)
  assertEqual "redis is not authority" Pending (recoverOutcome scope (CommandId "missing") (Just receipt) durable2)
  assertEqual "foreign receipt denied" Nothing (durableLookup foreignScope command durable2)
  assert (idempotencyKey scope command /= idempotencyKey foreignScope command) "scope missing from idempotency"
  assertEqual "infernix command/work identity" (WorkId "command-infernix-1") (infernixWorkId command)
  putStrLn "offline-replay-receipts-live: PASS-SCOPED (current authority/idempotency/durable repair model; provider observers separate)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "61\t" . Text.pack) rows
  assertEqual "phase-0 custody" 11 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-61 custody row"

assertLeft :: String -> Either error value -> IO ()
assertLeft _ (Left _) = pure ()
assertLeft label (Right _) = die (label <> " unexpectedly succeeded")

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found then pure path else let parent = takeDirectory path in if parent == path then die "phase61-root" else go parent
