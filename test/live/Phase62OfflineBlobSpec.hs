{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Offline.BlobUpload
import Amoebius.Ui.Offline.Browser.Crypto
import Amoebius.Ui.Offline.Browser.Partition
import Amoebius.Ui.Offline.Receipt (Scope (..))
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
  let content = "phase62-reference-content"
      encrypted = sealRecord (Secret "unlock-62") content
      scope = Scope "tenant-a" "alice" "program-a" 7
      nonOwner = Scope "tenant-a" "bob" "program-a" 7
      foreignScope = Scope "tenant-b" "alice" "program-a" 7
      expected = blobId content
  assert (not (content `isInfixOf` rawCiphertext encrypted)) "blob plaintext visible"
  assertEqual "blob decrypt" (Just content) (openRecord (Secret "unlock-62") encrypted)
  assertEqual "local handles hidden" [] publicLocalHandles
  assert (partitionKey "tenant-a" "alice" "device" "program" 7 /= partitionKey "tenant-b" "alice" "device" "program" 7) "blob partition collision"
  let started = beginUpload scope expected 2
  assert (not (releaseDependent started)) "dependent released before upload"
  assertLeft "nonowner chunk" (appendChunk nonOwner 0 "phase62-" started)
  assertLeft "foreign chunk" (appendChunk foreignScope 0 "phase62-" started)
  first <- either (die . show) pure (appendChunk scope 0 "phase62-" started)
  assertEqual "resume offset" 1 (resumeOffset first)
  second <- either (die . show) pure (appendChunk scope 1 "reference-content" first)
  assert (not (releaseDependent second)) "dependent released before verification"
  verified <- either (die . show) pure (verifyContent expected second)
  assert (releaseDependent verified) "verified dependency not released"
  let badExpected = blobId "good-content"
      badStart = beginUpload scope badExpected 1
  bad <- either (die . show) pure (appendChunk scope 0 "bad-content" badStart)
  assertLeft "caller digest trusted" (verifyContent badExpected bad)
  assertEqual "depended quota" BlobQuotaRefused (blobQuota 100 90 20 True)
  assertEqual "within quota" BlobStored (blobQuota 100 70 20 True)
  putStrLn "offline-blobs-isolation-live: PASS-SCOPED (encrypted blob/scope/resume/verify/dependency/quota model; providers separate)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/phase0_oracle_manifest.tsv"
  let phaseRows = filter (Text.isPrefixOf "62\t" . Text.pack) rows
  assertEqual "phase-0 custody" 11 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-62 custody row"

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
      if found then pure path else let parent = takeDirectory path in if parent == path then die "phase62-root" else go parent
