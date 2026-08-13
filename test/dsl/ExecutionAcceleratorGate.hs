{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorGate
  ( runExecutionAcceleratorGate
  ) where

import Amoebius.Dsl.Decode (decodeCluster)
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ExecutionAcceleratorFixtures
  ( Phase9Fixture (..)
  , phase9Fixtures
  , phase9PositiveRows
  , runPhase9DeterministicChecks
  )
import ExecutionAcceleratorProps (runExecutionAcceleratorProps)
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

runExecutionAcceleratorGate :: IO ()
runExecutionAcceleratorGate = do
  rows <- loadOracle "tests/oracle/phase9/execution_accelerator_cases.tsv"
  assert (length rows == 32) "Phase-9 oracle must contain 32 variant rows"
  let fixtureMap = Map.fromList [(phase9Variant fixture, fixture) | fixture <- phase9Fixtures]
      families = Set.fromList (fmap oracleFamily rows)
  assert (Map.keysSet fixtureMap == Set.fromList (fmap oracleVariant rows)) "Phase-9 fixture/oracle variants diverged"
  assert (families == requiredFamilies) "Phase-9 oracle does not preserve the exact eighteen negative families"
  forM_ rows $ \row -> case Map.lookup (oracleVariant row) fixtureMap of
    Nothing -> fail ("missing Phase-9 fixture: " <> Text.unpack (oracleVariant row))
    Just fixture -> do
      assert (phase9Family fixture == oracleFamily row) (drift row "family")
      assert (phase9Operation fixture == oracleOperation row) (drift row "operation")
      assert (phase9Expected fixture == oracleExpected row) (drift row "expected tag")
      assert (phase9Twin fixture == oracleTwin row) (drift row "twin")
      assert (phase9Catalog fixture == oracleCatalog row) (drift row "catalog")
      assert (phase9Negative fixture == Left (oracleExpected row)) (drift row "negative result")
      assert (phase9Positive fixture == Right ()) (drift row "legal twin")
  forM_ phase9PositiveRows $ \(name, result) -> do
    decoded <- decodeCluster ("dhall/examples/" <> Text.unpack name <> ".dhall")
    case decoded of
      Left problem -> fail (Text.unpack name <> " failed Gate 2 before Phase-9 composition: " <> show problem)
      Right _ -> pure ()
    assert (result == Right ()) (Text.unpack name <> " composed placement rejected: " <> show result)
  checkGate1
  runPhase9DeterministicChecks
  runExecutionAcceleratorProps
  putStrLn "execution-accelerator-spec: PASS (18 named negatives, 32 variants, 32 twins, 2 positives, 1 Gate-1, 7 properties)"

requiredFamilies :: Set.Set Text
requiredFamilies =
  Set.fromList
    [ "illegal_hard_ceiling_overcommit"
    , "illegal_node_local_storage_over_backing"
    , "illegal_disk_backing_alias_double_spend"
    , "illegal_filesystem_layout_alias"
    , "illegal_filesystem_layout_swapped"
    , "illegal_image_content_join_missing"
    , "illegal_image_snapshot_join_missing"
    , "illegal_image_storage_model_missing"
    , "illegal_split_image_unsupported"
    , "illegal_provider_instance_store_root_underprovisioned"
    , "illegal_provider_node_root_ebs_over_quota"
    , "illegal_control_plane_storage_transition_overrun"
    , "illegal_cuda_on_cpu_target"
    , "illegal_accelerator_count_shortage"
    , "illegal_accelerator_vram_fragmentation"
    , "illegal_accelerator_vram_reserve_boundary"
    , "illegal_apple_metal_profile_mismatch"
    , "illegal_shared_accelerator_double_owner"
    ]

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
  contents <- Text.readFile "tests/oracle/phase9/gate1_cases.tsv"
  case Text.lines contents of
    [] -> fail "Phase-9 Gate-1 oracle is empty"
    header : rows -> do
      assert (header == "entry\tnegative\tlegal\trequired") "Phase-9 Gate-1 oracle header drifted"
      assert (length rows == 1) "Phase-9 Gate-1 oracle must contain one row"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [_, negative, legal, required] -> do
          dhall <- resolvedDhall
          (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack legal, "--quiet"]) ""
          assert (legalExit == ExitSuccess) (Text.unpack legal <> " rejected:\n" <> legalError)
          (negativeExit, negativeOut, negativeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
          let observed = Text.pack (negativeOut <> negativeError)
          assert (negativeExit /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus")
        _ -> fail ("malformed Phase-9 Gate-1 row: " <> Text.unpack row)


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
