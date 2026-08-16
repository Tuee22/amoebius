{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Sim.Env
import Amoebius.Sim.Interp.Real (noOpRealClients, realEnv)
import Amoebius.Sim.Interp.Sim
import Amoebius.Sim.Reconcile (referenceReconcile)
import Control.Monad (forM, forM_, unless)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim
  ( IOSim
  , exploreSimTrace
  , runSimOrThrow
  , traceResult
  , withBranching
  , withScheduleBound
  )
import Data.Aeson (eitherDecodeStrict', encode)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Char (isAlphaNum)
import Data.List (isInfixOf, isSuffixOf, sort)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import DroppedPartitionMutant (droppedPartitionReconcile)
import FaultContracts (checkFaultContracts)
import System.Directory (canonicalizePath, doesDirectoryExist, getCurrentDirectory, listDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck
  ( Args (..)
  , counterexample
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  case arguments of
    [] -> runGreen root
    ["--mutant=dropped-partition-handling"] -> runMutantMode root
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> IO ()
runGreen root = do
  schedules <- loadSchedules root
  expected <- loadExpected root
  checkExpectedOutcomes schedules expected
  checkFaultCoverage schedules
  checkFaultContracts
  checkRealInterpreter
  forM_ schedules checkSameSeed
  checkScheduleSensitivity schedules
  forM_ schedules checkIOSimPOR
  checkPartitionMutant schedules
  checkPolymorphismSourceGate root
  putStrLn "sim-spec: PASS (2 interpreters, 6 fake contracts, 4 schedules, same-seed bytes, sensitivity, IOSimPOR, 1 mutant)"

runMutantMode :: FilePath -> IO ()
runMutantMode root = do
  schedules <- loadSchedules root
  schedule <- findSchedule "partition-heal" schedules
  let outcome = runSimOrThrow $ do
        handle <- newIOSimEnv schedule
        droppedPartitionReconcile (simEnv handle)
  case outcome of
    Upheld -> putStrLn "deterministic-simulation-mutant: SURVIVED dropped-partition-handling"
    Violated invariant ->
      putStrLn ("deterministic-simulation-mutant: RED dropped-partition-handling " <> Text.unpack invariant)
  exitFailure

loadSchedules :: FilePath -> IO [FaultSchedule]
loadSchedules root = do
  let directory = root </> "test/fixture/deterministic_simulation/schedules"
  names <- sort . filter (".json" `isSuffixOf`) <$> listDirectory directory
  forM names $ \name -> do
    bytes <- ByteString.readFile (directory </> name)
    case eitherDecodeStrict' bytes of
      Left problem -> die (name <> ": " <> problem)
      Right schedule -> pure schedule

loadExpected :: FilePath -> IO (Map.Map Text.Text InvariantOutcome)
loadExpected root = do
  source <- readFile (root </> "test/oracle/deterministic_simulation/expected_outcomes.tsv")
  rows <- forM (filter (not . null) (lines source)) $ \line -> case splitTabs line of
    [name, "upheld", "-"] -> pure (Text.pack name, Upheld)
    [name, "violated", invariant] -> pure (Text.pack name, Violated (Text.pack invariant))
    _ -> die ("invalid expected-outcome row: " <> line)
  pure (Map.fromList rows)

checkExpectedOutcomes :: [FaultSchedule] -> Map.Map Text.Text InvariantOutcome -> IO ()
checkExpectedOutcomes schedules expected = do
  assertEqual "schedule/outcome oracle keys"
    (Map.keysSet expected)
    (Set.fromList (map scheduleName schedules))
  forM_ schedules $ \schedule -> do
    let (outcome, _) = runReplay schedule
    assertEqual (Text.unpack (scheduleName schedule) <> " outcome")
      (expected Map.! scheduleName schedule) outcome

checkFaultCoverage :: [FaultSchedule] -> IO ()
checkFaultCoverage schedules =
  assertEqual "schedule fault-axis coverage"
    (Set.fromList [Delay, Reorder, Duplicate, Partition, Crash])
    (Set.fromList (concatMap activeFaults schedules))

checkRealInterpreter :: IO ()
checkRealInterpreter = do
  let environment = realEnv noOpRealClients :: Env IO
  outcome <- referenceReconcile environment
  assertEqual "reference reconciler under real-client interpreter" Upheld outcome

checkSameSeed :: FaultSchedule -> IO ()
checkSameSeed schedule = do
  let first = runReplay schedule
      second = runReplay schedule
  assertEqual (Text.unpack (scheduleName schedule) <> " same-seed outcome") (fst first) (fst second)
  assertEqual (Text.unpack (scheduleName schedule) <> " same-seed trace bytes") (snd first) (snd second)

checkScheduleSensitivity :: [FaultSchedule] -> IO ()
checkScheduleSensitivity schedules = do
  base <- findSchedule "partition-heal" schedules
  let perturbed = base {scheduleSeed = scheduleSeed base + 1}
      (_, baseTrace) = runReplay base
      (_, perturbedTrace) = runReplay perturbed
  assert (baseTrace /= perturbedTrace) "distinct seed/fault order produced the same trace"

checkIOSimPOR :: FaultSchedule -> IO ()
checkIOSimPOR schedule = do
  let callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right outcome -> counterexample (show outcome) (property (outcome == Upheld))
      options = withBranching 4 . withScheduleBound 24
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen (scheduleSeed schedule), 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (porSimulation schedule) callback)
  assert (isSuccess result) (Text.unpack (scheduleName schedule) <> " IOSimPOR replay failed")

porSimulation :: FaultSchedule -> IOSim s InvariantOutcome
porSimulation schedule = do
  exploreRaces
  handle <- newIOSimEnv schedule
  referenceReconcile (simEnv handle)

checkPartitionMutant :: [FaultSchedule] -> IO ()
checkPartitionMutant schedules = do
  schedule <- findSchedule "partition-heal" schedules
  let correct = fst (runReplay schedule)
      mutant = runSimOrThrow $ do
        handle <- newIOSimEnv schedule
        droppedPartitionReconcile (simEnv handle)
  assertEqual "partition reference outcome" Upheld correct
  assertEqual "dropped-partition mutant outcome" (Violated "NoActOnStaleRead") mutant

runReplay :: FaultSchedule -> (InvariantOutcome, LazyByteString.ByteString)
runReplay schedule = runSimOrThrow $ do
  handle <- newIOSimEnv schedule
  outcome <- referenceReconcile (simEnv handle)
  trace <- simReadTrace handle
  pure (outcome, encode trace)

checkPolymorphismSourceGate :: FilePath -> IO ()
checkPolymorphismSourceGate root = do
  let simRoot = root </> "src/Amoebius/Sim"
  files <- listHsFiles simRoot
  assert (not (null files)) "polymorphism source-gate scope is empty"
  sources <- mapM readFile files
  let bareIo =
        [ file <> ":" <> show lineNumber
        | (file, source) <- zip files sources
        , (lineNumber, line) <- zip [(1 :: Int) ..] (lines source)
        , "::" `isInfixOf` line
        , "IO" `elem` tokens line
        ]
      rawConcurrency =
        [ file
        | (file, source) <- zip files sources
        , any (`isInfixOf` source) ["import Control.Concurrent (", "import qualified Control.Concurrent", "forkIO"]
        ]
  assertEqual "bare IO signatures in simulation scope" [] bareIo
  assertEqual "raw concurrency in simulation scope" [] rawConcurrency
  assert (any ("Control.Monad.IOSim" `isInfixOf`) sources) "IOSim interpreter is absent from source-gate scope"
  assert (any ("MonadAsync" `isInfixOf`) sources) "io-classes concurrency constraint is absent"

listHsFiles :: FilePath -> IO [FilePath]
listHsFiles directory = do
  entries <- sort <$> listDirectory directory
  fmap concat $ forM entries $ \entry -> do
    let path = directory </> entry
    nested <- doesDirectoryExist path
    if nested then listHsFiles path else pure [path | ".hs" `isSuffixOf` path]

findSchedule :: Text.Text -> [FaultSchedule] -> IO FaultSchedule
findSchedule name schedules = case filter ((== name) . scheduleName) schedules of
  [schedule] -> pure schedule
  _ -> die ("missing or duplicate schedule: " <> Text.unpack name)

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

tokens :: String -> [String]
tokens = words . map (\character -> if isAlphaNum character || character == '_' then character else ' ')

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
