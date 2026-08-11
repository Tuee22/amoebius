{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Offline.Decode
import Amoebius.Ui.Offline.Plan
import Amoebius.Ui.Offline.Types
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  expectedKeys <- readPlanKeyOracle
  let infernix = QueuedPort InfernixStart (validContract "workflow-root")
      jitml = QueuedPort JitmlTrainingStart (validContract "dataset-blob")
      source = OfflineSource [Projection "workflow-progress"] [infernix, jitml] [BlobClass "dataset"]
  (client, replay) <- either (die . show) pure (compileOffline source)
  assertEqual "public keys" expectedKeys (clientKeys client)
  assertEqual "private keys" expectedKeys (replayKeys replay)
  assertEqual "paired keys" (clientKeys client) (replayKeys replay)
  assertEqual "deterministic" (Right (client, replay)) (compileOffline source)
  assertEqual "private fields absent" [] (leakedPrivateFields client)
  assertEqual "mechanisms absent" [] mechanismConstructors
  assertEqual "artifact commands" ["emit-client-offline-plan", "emit-server-replay-plan"] generatedArtifactCommands
  assertTag "zero count" MissingCountBound (QueuedPort InfernixStart ((validContract "x") {maxCount = 0}))
  assertTag "zero bytes" MissingByteBound (QueuedPort InfernixStart ((validContract "x") {maxBytes = 0}))
  assertTag "zero age" MissingAgeBound (QueuedPort InfernixStart ((validContract "x") {maxAgeSeconds = 0}))
  assertTag "idempotency" MissingIdempotency (QueuedPort InfernixStart ((validContract "x") {idempotencyRule = ""}))
  assertTag "conflict" MissingConflictRule (QueuedPort InfernixStart ((validContract "x") {conflictRule = ""}))
  assertTag "order" MissingOrderRule (QueuedPort InfernixStart ((validContract "x") {orderRule = ""}))
  assertTag "dependency" MissingDependencyRule (QueuedPort InfernixStart (validContract "") )
  assertTag "validation" MissingAuthorityValidation (QueuedPort InfernixStart ((validContract "x") {authoritativeValidation = ""}))
  forM_ [WorkflowProgress, MlSignal, WorkflowCancel, ModelInvocation] $ \operation ->
    assertTag (show operation) (OnlineOnlyOperation operation) (QueuedPort operation (validContract "x"))
  putStrLn "offline-plan-spec: PASS (closed offline language; deterministic paired plans; five mutant loci)"

validContract :: String -> QueueContract
validContract dependency = QueueContract 8 65536 86400 "command-id" "reject" "preserve" dependency "current-authority"

assertTag :: String -> DecodeError -> QueuedPort -> IO ()
assertTag label expected queued = case decodeQueueContract queued of
  Left actual -> assertEqual label expected actual
  Right _ -> die (label <> " unexpectedly accepted")

readPlanKeyOracle :: IO [PortId]
readPlanKeyOracle = do
  rows <- drop 1 . lines <$> readFile "test/golden/phase_59_plan_keys.tbl"
  pure [PortId publicKey | row <- rows, [_operation, publicKey, _privateKey, "queued"] <- [words row]]

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/phase0_oracle_manifest.tsv"
  let phaseRows = filter (Text.isPrefixOf "59\t" . Text.pack) rows
  assertEqual "phase-0 custody" 8 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-59 custody row"

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found then pure path else let parent = takeDirectory path in if parent == path then die "phase59-root" else go parent
