{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Ha.MultiZone
import Amoebius.Ui.Projection.Cursor
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  topology <- either (die . show) pure (admitTopology canonicalTopology)
  forM_ components $ \component -> do
    assertEqual (show component <> " replicas") 3 (length (replicasFor component topology))
    assert (hardSpread component topology) (show component <> " is not spread over three zones")
  assertEqual "whole-zone fault" (WholeZone ZoneB) plannedFault
  assertEqual "operation continuity" FullMatrixAvailable (continuityDuring topology plannedFault)
  let operations = [minBound .. maxBound] :: [Operation]
  assertEqual "complete operation matrix" [Read, IdempotentMutation, WorkflowStart, Subscription] operations
  assert
    (authorizeAfterFault (Authority True True True))
    "fresh cookie-empty authority was not accepted"
  assert
    (not (authorizeAfterFault (Authority False True True)))
    "cached pre-fault authority was accepted"
  let durable = DurableState 42 "receipt-command-1"
  assertEqual "durable repair" (Just durable) (repairAfterCoordinationLoss durable)
  let own = cursorKey "tenant-a" "alice" "projection"
      foreignTenant = cursorKey "tenant-b" "alice" "projection"
  assertLeft "foreign cursor" (resumeCursor own foreignTenant (Just (Cursor 42)))
  assertEqual "same-scope cursor" (Right (Cursor 42)) (resumeCursor own own (Just (Cursor 42)))
  putStrLn
    "ui-ha-multizone-ui-ha-multizone: PASS-SCOPED (three-zone topology/fault/authority/repair kernel; real provider HA UNVERIFIED)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "58\t" . Text.pack) rows
  assertEqual "phase-0 custody" 14 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-58 custody row"

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
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found
        then pure path
        else
          let parent = takeDirectory path
           in if parent == path then die "phase58 project root not found" else go parent
