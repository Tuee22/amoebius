{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Release.OfflineCompatibility
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  _ <- either (die . show) pure (admitPromotion 90000 canonicalWitness)
  let incompatible = CompatibilityWitness 90000 []
  assertLeft "incompatible promotion" (admitPromotion 90000 incompatible)
  assertLeft "short horizon" (admitPromotion 90001 canonicalWitness)
  let records =
        [ PersistedRecord "command-a" OutboxRecord SchemaA "sealed-command"
        , PersistedRecord "blob-a" BlobDependencyRecord SchemaA "sealed-blob"
        , PersistedRecord "projection-a" CachedProjectionRecord SchemaA "sealed-projection"
        ]
      persisted = PersistedState records
  assertEqual "reload preserves intent" persisted (reloadRequired persisted)
  staged <- either (die . show) pure (stageMigration 7 (beginMigration SchemaA SchemaB records))
  assertEqual "crash leaves no partial commit" Nothing (committedRecords staged)
  committed <- either (die . show) pure (resumeMigration 7 staged)
  migrated <- maybe (die "migration did not commit") pure (committedRecords committed)
  assert (all ((== SchemaB) . recordSchema) migrated) "partial migration"
  assertEqual "one migration" 1 (migrationRuns committed)
  rerun <- either (die . show) pure (resumeMigration 7 committed)
  assertEqual "migration idempotent" committed rerun
  rollbackStaged <- either (die . show) pure (stageMigration 8 (beginMigration SchemaB SchemaA migrated))
  rollback <- either (die . show) pure (resumeMigration 8 rollbackStaged)
  rolledBack <- maybe (die "rollback did not commit") pure (committedRecords rollback)
  assert (all ((== SchemaA) . recordSchema) rolledBack) "rollback schema mismatch"
  assertEqual "retained current allow" ReplayAccepted (replayRetained True False)
  assertEqual "stored auth not reused" ReplayDeniedCurrentAuthority (replayRetained False True)
  assertEqual "generated artifacts" ["emit-offline-compatibility-manifest", "emit-offline-migration-table"] generatedCompatibilityArtifacts
  putStrLn "offline-release-evolution-live: PASS-SCOPED (promotion/horizon/migration/rollback/reauthorization model; external observers separate)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "63\t" . Text.pack) rows
  assertEqual "phase-0 custody" 12 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-63 custody row"

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
      if found then pure path else let parent = takeDirectory path in if parent == path then die "offline-release-evolution-root" else go parent
