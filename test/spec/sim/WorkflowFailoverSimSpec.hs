{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (forM_, unless)
import Control.Monad.IOSim (exploreSimTrace, traceResult, withBranching, withScheduleBound)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.FilePath ((</>), takeDirectory)
import Test.QuickCheck (Args (..), counterexample, isSuccess, property, quickCheckWithResult, stdArgs)
import Test.QuickCheck.Random (mkQCGen)
import WorkflowSimScenario

main :: IO ()
main = do
  forM_ [0 .. 255] checkSchedule
  checkPor
  root <- getCurrentDirectory >>= findRepositoryRoot
  let evidenceDirectory = root </> "DEVELOPMENT_PLAN/evidence/phase_37"
  createDirectoryIfMissing True evidenceDirectory
  LazyByteString.writeFile (evidenceDirectory </> "workflow-failover-sim.json") $ encode $ object
    [ "schemaVersion" .= ("amoebius.phase37.workflow-failover-sim.v1" :: Text.Text)
    , "register" .= (2.5 :: Double)
    , "substrate" .= ("none" :: Text.Text)
    , "deterministicSchedules" .= (256 :: Int)
    , "porScheduleBound" .= (32 :: Int)
    , "faults" .= (["kill-worker-mid-workflow", "redelivery", "broker-consumer-partition"] :: [Text.Text])
    , "properties" .= (["leak-free-standby-takeover", "no-double-application", "byte-identical-pointer-head"] :: [Text.Text])
    , "modeledSubstrateFidelity" .= ("assumed; discharged by Register-3 live gate" :: Text.Text)
    , "result" .= ("PASS" :: Text.Text)
    ]
  putStrLn "workflow-failover-sim: PASS (256 deterministic schedules; IOSimPOR bound 32; leak-free takeover; no double application)"

findRepositoryRoot :: FilePath -> IO FilePath
findRepositoryRoot candidate = do
  found <- doesFileExist (candidate </> "cabal.project")
  if found
    then pure candidate
    else do
      let parent = takeDirectory candidate
      if parent == candidate
        then fail "content-store-workflow-repository-root-not-found"
        else findRepositoryRoot parent

checkSchedule :: Int -> IO ()
checkSchedule seed = do
  let schedule = WorkflowSchedule seed
      (first, firstBytes) = replayWorkflowSchedule schedule
      (second, secondBytes) = replayWorkflowSchedule schedule
  assert (first == second && firstBytes == secondBytes) ("non-deterministic-replay:" <> show seed)
  case validateWorkflowRun first of
    Right () -> pure ()
    Left problem -> fail ("workflow-sim-invariant:" <> Text.unpack problem)

checkPor :: IO ()
checkPor = do
  let schedule = WorkflowSchedule 197
      callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (validateWorkflowRun result == Right ()))
      options = withBranching 4 . withScheduleBound 32
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen 197, 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (runWorkflowSchedule schedule) callback)
  assert (isSuccess result) "workflow IOSimPOR exploration failed"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
