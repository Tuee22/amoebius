module Main (main) where

import Amoebius.Platform.BringUp
import Control.Concurrent.Class.MonadSTM
  ( TVar
  , atomically
  , newTVarIO
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.Monad (forM_, unless)
import Control.Monad.Class.MonadTimer (threadDelay)
import Control.Monad.IOSim (IOSim, exploreSimTrace, runSimOrThrow, traceResult, withBranching, withScheduleBound)
import Data.List (elemIndex)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import System.Exit (die)
import Test.QuickCheck (Args (..), counterexample, isSuccess, property, quickCheckWithResult, stdArgs)

data Fault = Healthy | PartialFailure Service | RestartAfterFailure Service | Partition Service
  deriving stock (Eq, Show)

data SimEvent = SimStarted Service | SimReady Service | SimRefused Service
  deriving stock (Eq, Show)

data SimRun = SimRun
  { simSeed :: Int
  , simFault :: Fault
  , simEvents :: [SimEvent]
  , simResult :: Either String [BringUpEvent]
  }
  deriving stock (Eq, Show)

main :: IO ()
main = do
  forM_ [0 .. 63] $ \seed -> do
    checkHealthy seed
    checkFault seed (PartialFailure Vault)
    checkFault seed (RestartAfterFailure MinIO)
    checkFault seed (Partition Pulsar)
  checkPor
  putStrLn "phase31-bringup-sim: PASS (256 deterministic fault schedules; IOSimPOR; fail-closed; independent-chain overlap)"

checkHealthy :: Int -> IO ()
checkHealthy seed = do
  let first = replaySchedule seed Healthy
      second = replaySchedule seed Healthy
  assert (show first == show second) ("non-identical replay:" <> show seed)
  requireRight (validateSafety first)
  assert (overlapWitness (simEvents first)) ("independent concurrency absent:" <> show seed)
  assert (allServicesReady first) ("success-before-ready:" <> show seed)

checkFault :: Int -> Fault -> IO ()
checkFault seed fault = do
  let failed = replaySchedule seed fault
      recovered = replaySchedule seed Healthy
  requireRight (validateSafety failed)
  assert (isLeft (simResult failed)) ("fault did not fail closed:" <> show fault <> ":" <> show seed)
  assert (allServicesReady recovered) ("restart did not converge:" <> show fault <> ":" <> show seed)

replaySchedule :: Int -> Fault -> SimRun
replaySchedule seed fault = runSimOrThrow (runSchedule seed fault)

runSchedule :: Int -> Fault -> IOSim s SimRun
runSchedule seed fault = do
  trace <- newTVarIO []
  result <- runBringUp (observe trace seed fault) declaredDependencies
  events <- readTVarIO trace
  pure (SimRun seed fault events result)

observe :: TVar (IOSim s) [SimEvent] -> Int -> Fault -> Service -> IOSim s Bool
observe trace seed fault service = do
  append trace (SimStarted service)
  threadDelay (duration service + seed `mod` 7)
  if shouldFail fault service
    then append trace (SimRefused service) >> pure False
    else append trace (SimReady service) >> pure True

duration :: Service -> Int
duration service = case service of
  PerconaOperator -> 500
  MetalLB -> 50
  MinIO -> 50
  _ -> 25

shouldFail :: Fault -> Service -> Bool
shouldFail fault service = case fault of
  Healthy -> False
  PartialFailure target -> service == target
  RestartAfterFailure target -> service == target
  Partition target -> service == target

append :: TVar (IOSim s) [SimEvent] -> SimEvent -> IOSim s ()
append trace event = atomically $ do
  prior <- readTVar trace
  writeTVar trace (prior <> [event])

validateSafety :: SimRun -> Either String ()
validateSafety run = mapM_ validateStart starts
 where
  events = simEvents run
  starts = [service | SimStarted service <- events]
  validateStart service = mapM_ (readyBefore service) (Set.toList (oracleDependencies Map.! service))
  readyBefore service dependency = case (elemIndex (SimReady dependency) events, elemIndex (SimStarted service) events) of
    (Just readyIndex, Just startIndex) | readyIndex < startIndex -> Right ()
    _ -> Left ("precondition-violation:" <> show dependency <> "->" <> show service)

overlapWitness :: [SimEvent] -> Bool
overlapWitness events = ordered [SimStarted PerconaOperator, SimStarted MinIO, SimReady MinIO, SimReady PerconaOperator]
 where
  ordered sequenceRows = case traverse (`elemIndex` events) sequenceRows of
    Just indexes -> indexes == quicksort indexes
    Nothing -> False
  quicksort [] = []
  quicksort (value : rest) = quicksort [row | row <- rest, row < value] <> [value] <> quicksort [row | row <- rest, row >= value]

allServicesReady :: SimRun -> Bool
allServicesReady run = case simResult run of
  Left _ -> False
  Right _ -> all (\service -> SimReady service `elem` simEvents run) [minBound .. maxBound]

checkPor :: IO ()
checkPor = do
  let callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (validateSafety result == Right () && overlapWitness (simEvents result)))
      options = withBranching 4 . withScheduleBound 40
  result <- quickCheckWithResult (stdArgs {maxSuccess = 1, chatty = False}) (exploreSimTrace options (runSchedule 31 Healthy) callback)
  assert (isSuccess result) "IOSimPOR exploration failed"

isLeft :: Either left right -> Bool
isLeft value = case value of
  Left _ -> True
  Right _ -> False

requireRight :: Either String () -> IO ()
requireRight = either die pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)
