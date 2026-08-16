{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Sim.Env (InvariantOutcome (..))
import Control.Monad (forM_, unless)
import Control.Monad.IOSim (exploreSimTrace, traceResult, withBranching, withScheduleBound)
import Data.Text qualified as Text
import CapacitySchedulerSimCommon
import System.Environment (getArgs)
import System.Exit (exitFailure)
import Test.QuickCheck (Args (..), counterexample, isSuccess, property, quickCheckWithResult, stdArgs)
import Test.QuickCheck.Random (mkQCGen)

classes :: [SchedulerFaultClass]
classes = [minBound .. maxBound]

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runGreen
    [raw] | Just name <- stripMutant raw -> runMutant name
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: IO ()
runGreen = do
  forM_ classes checkFaultClass
  forM_ classes checkPor
  forM_ schedulerMutants checkMutantKilled
  putStrLn "scheduler-sim: PASS (7 fault classes x 256 schedules; IOSimPOR bound 24; 7 mutants red)"

checkFaultClass :: SchedulerFaultClass -> IO ()
checkFaultClass fault = forM_ [0 .. 255] $ \seed -> do
  let schedule = SchedulerSchedule seed fault
      (first, firstBytes) = replaySchedulerSchedule schedule
      (second, secondBytes) = replaySchedulerSchedule schedule
  requireRight (show fault <> "/" <> show seed) (validateSchedulerRun first)
  assert (first == second && firstBytes == secondBytes) (show fault <> "/" <> show seed <> " did not replay byte-identically")

checkPor :: SchedulerFaultClass -> IO ()
checkPor fault = do
  let schedule = SchedulerSchedule 197 fault
      callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (validateSchedulerRun result == Right ()))
      options = withBranching 4 . withScheduleBound 24
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen 197, 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (runSchedulerSchedule schedule) callback)
  assert (isSuccess result) (show fault <> " IOSimPOR exploration failed")

checkMutantKilled :: SchedulerMutant -> IO ()
checkMutantKilled mutant = case schedulerMutantOutcome mutant of
  Violated _ -> pure ()
  Upheld -> die (schedulerMutantName mutant <> " survived")

runMutant :: String -> IO ()
runMutant raw = case parseSchedulerMutant raw of
  Nothing -> die ("unknown mutant: " <> raw)
  Just mutant -> case schedulerMutantOutcome mutant of
    Upheld -> putStrLn ("phase27-scheduler-mutant: SURVIVED " <> raw)
    Violated invariant -> putStrLn ("phase27-scheduler-mutant: RED " <> raw <> " " <> Text.unpack invariant)
  >> exitFailure

stripMutant :: String -> Maybe String
stripMutant raw = case splitAt 9 raw of
  ("--mutant=", name) -> Just name
  _ -> Nothing

requireRight :: String -> Either Text.Text () -> IO ()
requireRight _ (Right ()) = pure ()
requireRight label (Left problem) = die (label <> ": " <> Text.unpack problem)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
