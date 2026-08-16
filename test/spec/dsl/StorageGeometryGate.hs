{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryGate
  ( runStorageGeometryGate
  ) where

import Amoebius.Dsl.Decode (decodeCluster)
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import StorageGeometryFixtures
  ( StorageFixture (..)
  , storageFixtures
  , storagePositiveRows
  )
import StorageGeometryProps (runStorageGeometryProps)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.Process (proc, readCreateProcessWithExitCode)

data OracleRow = OracleRow
  { oracleVariant :: Text
  , oracleFamily :: Text
  , oracleOperation :: Text
  , oracleExpected :: Text
  , oracleTwin :: Text
  , oracleCatalog :: Text
  }

runStorageGeometryGate :: IO ()
runStorageGeometryGate = do
  rows <- loadOracle "test/oracle/storage_geometry/storage_cases.tsv"
  assert (length rows == 27) "Phase-8 storage oracle must contain 27 variant rows"
  let fixturesByVariant = Map.fromList [(storageFixtureVariant fixture, fixture) | fixture <- storageFixtures]
  assert (Map.keysSet fixturesByVariant == Set.fromList (fmap oracleVariant rows)) "storage fixture/oracle variant sets diverged"
  forM_ rows $ \row -> case Map.lookup (oracleVariant row) fixturesByVariant of
    Nothing -> fail ("missing storage fixture: " <> Text.unpack (oracleVariant row))
    Just fixture -> do
      assert (storageFixtureFamily fixture == oracleFamily row) (drift row "family")
      assert (storageFixtureOperation fixture == oracleOperation row) (drift row "operation")
      assert (storageFixtureCatalog fixture == oracleCatalog row) (drift row "catalog")
      assert (storageFixtureTwin fixture == oracleTwin row) (drift row "twin")
      assert (storageFixtureExpected fixture == oracleExpected row) (drift row "expected tag")
      assert (storageFixtureNegative fixture == Left (oracleExpected row)) (drift row "negative result")
      assert (storageFixturePositive fixture == Right ()) (drift row "legal twin")
  forM_ storagePositiveRows $ \(name, result) -> do
    decoded <- decodeCluster ("dhall/examples/" <> Text.unpack name <> ".dhall")
    case decoded of
      Left problem -> fail (Text.unpack name <> " failed Gate 2 before Phase-8 geometry: " <> show problem)
      Right _ -> pure ()
    assert (result == Right ()) (Text.unpack name <> " storage rows rejected: " <> show result)
  checkGate1
  runStorageGeometryProps
  putStrLn "storage-geometry-spec: PASS (5 named negatives, 27 variants, 27 twins, 2 positives, 2 Gate-1, 6 properties)"

loadOracle :: FilePath -> IO [OracleRow]
loadOracle path = do
  contents <- Text.readFile path
  case Text.lines contents of
    [] -> fail (path <> " is empty")
    header : rows -> do
      assert (header == "variant\tfamily\toperation\texpected\ttwin\tcatalog") (path <> " header drifted")
      mapM parseRow rows
 where
  parseRow row = case Text.splitOn "\t" row of
    [variant, family, operation, expected, twin, catalog] -> pure (OracleRow variant family operation expected twin catalog)
    _ -> fail (path <> " malformed row: " <> Text.unpack row)

checkGate1 :: IO ()
checkGate1 = do
  contents <- Text.readFile "test/oracle/storage_geometry/gate1_cases.tsv"
  case Text.lines contents of
    [] -> fail "Phase-8 Gate-1 oracle is empty"
    header : rows -> do
      assert (header == "entry\tnegative\tlegal\trequired") "Phase-8 Gate-1 oracle header drifted"
      assert (length rows == 2) "Phase-8 Gate-1 oracle must contain two rows"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [_, negative, legal, required] -> do
          dhall <- resolvedDhall
          (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack legal, "--quiet"]) ""
          assert (legalExit == ExitSuccess) (Text.unpack legal <> " rejected:\n" <> legalError)
          (negativeExit, negativeOut, negativeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
          let observed = Text.pack (negativeOut <> negativeError)
          assert (negativeExit /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus")
        _ -> fail ("malformed Phase-8 Gate-1 row: " <> Text.unpack row)


drift :: OracleRow -> String -> String
drift row field = Text.unpack (oracleVariant row) <> " " <> field <> " drifted"

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
