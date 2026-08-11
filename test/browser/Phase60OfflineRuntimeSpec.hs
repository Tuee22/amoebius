{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Offline.Browser.Crypto
import Amoebius.Ui.Offline.Browser.Leader
import Amoebius.Ui.Offline.Browser.Partition
import Amoebius.Ui.Offline.Browser.ServiceWorker
import Amoebius.Ui.Offline.Browser.Store
import Control.Monad (forM_, unless)
import Data.List (isInfixOf)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  let canary = "fresh-offline-canary-60"
      secret = Secret "local-unlock-secret"
      encrypted = sealRecord secret canary
  assert (not (canary `isInfixOf` rawCiphertext encrypted)) "plaintext canary visible"
  assertEqual "decrypt" (Just canary) (openRecord secret encrypted)
  assertEqual "prohibited fields" [] prohibitedPersistenceFields
  let own = partitionKey "tenant-a" "alice" "device-1" "program-1" 1
      otherSubject = partitionKey "tenant-a" "bob" "device-1" "program-1" 1
      otherTenant = partitionKey "tenant-b" "alice" "device-1" "program-1" 1
  assert (own /= otherSubject) "subject partition collision"
  assert (own /= otherTenant) "tenant partition collision"
  first <- either (die . show) pure (claimLeader own (TabId "tab-a") emptyLeaderState)
  assertLeft "concurrent tab" (claimLeader own (TabId "tab-b") first)
  second <- either (die . show) pure (claimLeader own (TabId "tab-b") (releaseLeader (TabId "tab-a") first))
  assertEqual "single leader" [TabId "tab-b"] (leaderOwners second)
  assertEqual "fencing generation" (Generation 2) (leaderGeneration second)
  assertEqual "depended quota" RejectedQuota (admitBytes 100 90 20 True)
  assertEqual "independent quota" RejectedQuota (admitBytes 100 90 20 False)
  assertEqual "within quota" Stored (admitBytes 100 70 20 True)
  let assets = [Asset "/asset/hash-app.js" "sha256:app-v1" True True, Asset "/asset/hash-runtime.js" "sha256:runtime-v1" True True]
  assertEqual "asset manifest" (Right assets) (admitAssetManifest assets)
  putStrLn "offline-browser-runtime-spec: PASS-SCOPED (crypto/partition/leader/quota/assets model; Chrome boundary separate)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/phase0_oracle_manifest.tsv"
  let phaseRows = filter (Text.isPrefixOf "60\t" . Text.pack) rows
  assertEqual "phase-0 custody" 11 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-60 custody row"

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
      if found then pure path else let parent = takeDirectory path in if parent == path then die "phase60-root" else go parent
