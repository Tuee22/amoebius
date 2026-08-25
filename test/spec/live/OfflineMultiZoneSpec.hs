{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Release.OfflineCompatibility
import Amoebius.Ui.Offline.Ha.MultiZone
import Amoebius.Ui.Offline.Receipt
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  _ <- either (die . show) pure (admitCampaign canonicalCampaign)
  report <- either (die . show) pure (runContinuity canonicalCampaign)
  assertEqual "cursor repair" 42 (repairedCursor report)
  assertEqual "scalar effect" 1 (scalarEffects report)
  assertEqual "infernix effect" 1 (infernixEffects report)
  assertEqual "blob effect" 1 (blobDependentEffects report)
  assert (ownerAllowed report) "owner denied"
  assert (sameTenantNonownerDenied report) "same-tenant nonowner admitted"
  assert (foreignTenantDenied report) "foreign tenant admitted"
  let scope = Scope "tenant-a" "alice" "program-b" 8
      foreignScope = Scope "tenant-b" "alice" "program-b" 8
      command = CommandId "offline-64"
  assert (idempotencyKey scope command /= idempotencyKey foreignScope command) "outbox idempotency scope collapsed"
  let persisted = PersistedState [PersistedRecord "offline-64" OutboxRecord SchemaA "sealed"]
  assertEqual "release preserves state" persisted (reloadRequired persisted)
  putStrLn "offline-multizone-continuity: PASS-SCOPED (composite zone/replay/cursor/blob/release/isolation contract; provider zone fault separate)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "64\t" . Text.pack) rows
  assertEqual "phase-0 custody" 13 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-65 custody row"

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
      if found then pure path else let parent = takeDirectory path in if parent == path then die "offline-multizone-continuity-root" else go parent
