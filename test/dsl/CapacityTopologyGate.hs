{-# LANGUAGE OverloadedStrings #-}

module CapacityTopologyGate
  ( runCapacityTopologyGate
  ) where

import Amoebius.Capacity.Types (HostEnvironment (..))
import Amoebius.Dsl.Decode (decodeCluster)
import Amoebius.Dsl.Topology (ComputeEngine (..), engineAcceptsEnvironment)
import CapacityTopologyFixtures (FixtureCase (..), fixtureCases, positiveCases)
import CapacityTopologyProps (ValidatorMutation (ValidateAll), referenceCompatibility, runCapacityTopologyProps, validatePlacement)
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.Process (proc, readCreateProcessWithExitCode)

data OracleRow = OracleRow
  { oracleCase :: Text
  , oracleExpected :: Text
  , oracleTwin :: Text
  }

runCapacityTopologyGate :: IO ()
runCapacityTopologyGate = do
  rows <- loadOracle "tests/oracle/phase7/fold_cases.tsv"
  assert (length rows == 15) "Phase-7 fold oracle must contain fifteen rows"
  let fixturesByName = Map.fromList [(fixtureName fixture, fixture) | fixture <- fixtureCases]
  assert (Map.keysSet fixturesByName == Set.fromList (fmap oracleCase rows)) "fixture/oracle case sets diverged"
  forM_ rows $ \row -> case Map.lookup (oracleCase row) fixturesByName of
    Nothing -> fail ("missing fixture: " <> Text.unpack (oracleCase row))
    Just fixture -> do
      assert (fixtureTwin fixture == oracleTwin row) (Text.unpack (oracleCase row) <> " twin drifted")
      assert (fixtureNegative fixture == Left (oracleExpected row)) (Text.unpack (oracleCase row) <> " returned " <> show (fixtureNegative fixture))
      assert (fixturePositive fixture == Right ()) (Text.unpack (oracleCase row) <> " legal twin rejected: " <> show (fixturePositive fixture))
  forM_ positiveCases $ \(name, result) -> do
    decoded <- decodeCluster ("dhall/examples/" <> Text.unpack name <> ".dhall")
    case decoded of
      Left problem -> fail (Text.unpack name <> " failed Gate 2 before Phase-7 placement: " <> show problem)
      Right _ -> pure ()
    case result of
      Left problem -> fail (Text.unpack name <> " failed placement: " <> Text.unpack problem)
      Right (topology, workloads, witness) ->
        assert (validatePlacement ValidateAll topology workloads witness == Right ()) (Text.unpack name <> " witness failed independent validation")
  checkCompatibilityOracle
  checkGate1
  runCapacityTopologyProps
  checkCompileFail
  putStrLn "capacity-topology-spec: PASS (3 Gate-1, 15 fold negatives, 15 twins, 2 positives, 7 compile pairs, 4 properties)"

loadOracle :: FilePath -> IO [OracleRow]
loadOracle path = do
  contents <- Text.readFile path
  case Text.lines contents of
    [] -> fail (path <> " is empty")
    header : rows -> do
      assert (header == "case\toperation\texpected\ttwin\tcatalog") (path <> " header drifted")
      mapM parseRow rows
 where
  parseRow row = case Text.splitOn "\t" row of
    [name, _, expected, twin, _] -> pure (OracleRow name expected twin)
    _ -> fail (path <> " malformed row: " <> Text.unpack row)

checkCompatibilityOracle :: IO ()
checkCompatibilityOracle = do
  contents <- Text.readFile "tests/oracle/phase7/compatibility.tsv"
  case Text.lines contents of
    [] -> fail "compatibility oracle is empty"
    header : rows -> do
      assert (header == "engine\tenvironment\taccepted") "compatibility oracle header drifted"
      assert (length rows == 9) "compatibility oracle must enumerate nine pairs"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [engineText, environmentText, acceptedText] -> do
          engine <- parseEngine engineText
          environment <- parseEnvironment environmentText
          let expected = acceptedText == "true"
          assert (referenceCompatibility engine environment == expected) "reference compatibility predicate diverged from oracle"
          assert (engineAcceptsEnvironment engine environment == expected) "implementation compatibility predicate diverged from oracle"
        _ -> fail ("malformed compatibility row: " <> Text.unpack row)

parseEngine :: Text -> IO ComputeEngine
parseEngine value = case value of
  "KindEngine" -> pure KindEngine
  "Rke2Engine" -> pure Rke2Engine
  "ManagedEksEngine" -> pure ManagedEksEngine
  _ -> fail ("unknown engine in compatibility oracle: " <> Text.unpack value)

parseEnvironment :: Text -> IO HostEnvironment
parseEnvironment value = case value of
  "NativeLinux" -> pure NativeLinux
  "VirtualizedLinux" -> pure VirtualizedLinux
  "ManagedAws" -> pure ManagedAws
  _ -> fail ("unknown environment in compatibility oracle: " <> Text.unpack value)

checkCompileFail :: IO ()
checkCompileFail = do
  (exitCode, stdout, stderr) <- readCreateProcessWithExitCode (proc "python3" ["tools/phase7_compile_fail.py"]) ""
  assert (exitCode == ExitSuccess) ("Phase-7 compile-fail harness failed:\n" <> stdout <> stderr)
  assert ("phase7-compile-fail: PASS (7 legal/illegal minimal pairs)" `Text.isInfixOf` Text.pack stdout) "Phase-7 compile-fail acceptance token missing"

checkGate1 :: IO ()
checkGate1 = do
  contents <- Text.readFile "tests/oracle/phase7/gate1_cases.tsv"
  case Text.lines contents of
    [] -> fail "Phase-7 Gate-1 oracle is empty"
    header : rows -> do
      assert (header == "entry\tnegative\tlegal\trequired") "Phase-7 Gate-1 oracle header drifted"
      assert (length rows == 3) "Phase-7 Gate-1 oracle must contain three rows"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [_, negative, legal, required] -> do
          dhall <- resolvedDhall
          (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack legal, "--quiet"]) ""
          assert (legalExit == ExitSuccess) (Text.unpack legal <> " rejected:\n" <> legalError)
          (negativeExit, negativeOut, negativeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
          let observed = Text.pack (negativeOut <> negativeError)
          assert (negativeExit /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed its exact Gate-1 locus")
        _ -> fail ("malformed Phase-7 Gate-1 row: " <> Text.unpack row)


-- Resolved per run rather than pinned: a tracked file naming one developer's executable
-- is resolver output (repository_layout_doctrine.md section 4), and a PATH fallback would
-- defeat the Phase-5 absolute-argv observer. Unset means fail, never guess.
resolvedDhall :: IO FilePath
resolvedDhall = do
  value <- lookupEnv "AMOEBIUS_DHALL"
  case value of
    Just path | not (null path) -> pure path
    _ -> fail "AMOEBIUS_DHALL is unset: run this gate through its tools/phaseN_gate.py"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
