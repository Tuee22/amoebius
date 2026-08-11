{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Sim.Env (InvariantOutcome (..))
import Control.Monad (forM_, unless)
import Control.Monad.IOSim (exploreSimTrace, traceResult, withBranching, withScheduleBound)
import Data.Text qualified as Text
import Phase26SimCommon
import System.Environment (getArgs)
import System.Exit (exitFailure)
import Test.QuickCheck (Args (..), counterexample, isSuccess, property, quickCheckWithResult, stdArgs)
import Test.QuickCheck.Random (mkQCGen)

classes :: [FaultClass]
classes = [SerialStageChange, HostDeviceRelease, CompletionWriteFailure]

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
  forM_ [SerialStageCollapse, CompletionCleanupBeforePersist] checkMutantKilled
  putStrLn "execution-transition-sim: PASS (3 fault classes x 256 schedules; IOSimPOR bound 24; 2 mutants red)"

checkFaultClass :: FaultClass -> IO ()
checkFaultClass fault = forM_ [0 .. 255] $ \seed -> do
  let schedule = Phase26Schedule seed fault
      (first, firstBytes) = replaySchedule schedule
      (second, secondBytes) = replaySchedule schedule
  requireRight (show fault <> "/" <> show seed) (validateRun first)
  assert (first == second && firstBytes == secondBytes) (show fault <> "/" <> show seed <> " did not replay byte-identically")

checkPor :: FaultClass -> IO ()
checkPor fault = do
  let schedule = Phase26Schedule 149 fault
      callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (validateRun result == Right ()))
      options = withBranching 4 . withScheduleBound 24
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen 149, 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (runPhase26Schedule schedule) callback)
  assert (isSuccess result) (show fault <> " IOSimPOR exploration failed")

checkMutantKilled :: Mutant -> IO ()
checkMutantKilled mutant = case mutantOutcome mutant of
  Violated _ -> pure ()
  Upheld -> die (mutantName mutant <> " survived")

runMutant :: String -> IO ()
runMutant raw = case parseMutant raw of
  Nothing -> die ("unknown mutant: " <> raw)
  Just mutant -> case mutantOutcome mutant of
    Upheld -> putStrLn ("phase26-execution-mutant: SURVIVED " <> raw)
    Violated invariant -> putStrLn ("phase26-execution-mutant: RED " <> raw <> " " <> Text.unpack invariant)
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
