{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorGate
  ( runExecutionAcceleratorGate
  ) where

import Amoebius.Dsl.Decode (decodeCluster)
import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM, forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ExecutionAcceleratorFixtures
  ( Phase29Fixture (..)
  , phase29Fixtures
  , phase29PositiveRows
  , runPhase29DeterministicChecks
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
  rows <- loadOracle "test/oracle/execution_accelerator/execution_accelerator_cases.tsv"
  assert (length rows == 37) "Phase-29 oracle must contain 37 variant rows"
  let fixtureMap = Map.fromList [(phase29Variant fixture, fixture) | fixture <- phase29Fixtures]
      families = Set.fromList (fmap oracleFamily rows)
  assert (Map.keysSet fixtureMap == Set.fromList (fmap oracleVariant rows)) "Phase-29 fixture/oracle variants diverged"
  assert (families == requiredFamilies) "Phase-29 oracle does not preserve the exact eighteen negative families"
  forM_ rows $ \row -> case Map.lookup (oracleVariant row) fixtureMap of
    Nothing -> fail ("missing Phase-29 fixture: " <> Text.unpack (oracleVariant row))
    Just fixture -> do
      assert (phase29Family fixture == oracleFamily row) (drift row "family")
      assert (phase29Operation fixture == oracleOperation row) (drift row "operation")
      assert (phase29Expected fixture == oracleExpected row) (drift row "expected tag")
      assert (phase29Twin fixture == oracleTwin row) (drift row "twin")
      assert (phase29Catalog fixture == oracleCatalog row) (drift row "catalog")
      assert (phase29Negative fixture == Left (oracleExpected row)) (drift row "negative result")
      assert (phase29Positive fixture == Right ()) (drift row "legal twin")
  forM_ phase29PositiveRows $ \(name, result) -> do
    decoded <- decodeCluster ("dhall/examples/" <> Text.unpack name <> ".dhall")
    case decoded of
      Left problem -> fail (Text.unpack name <> " failed Gate 2 before Phase-29 composition: " <> show problem)
      Right _ -> pure ()
    assert (result == Right ()) (Text.unpack name <> " composed placement rejected: " <> show result)
  gate1Count <- checkGate1
  runPhase29DeterministicChecks
  propertyCount <- runExecutionAcceleratorProps
  mutantCount <- countExecutionAcceleratorMutants
  checkExecutionAcceleratorCalculusProjection (length rows) (length phase29PositiveRows) propertyCount mutantCount
  putStrLn
    ( "execution-accelerator-spec: PASS (18 named negatives, "
        <> show (length rows)
        <> " variants, "
        <> show (length rows)
        <> " twins, "
        <> show (length phase29PositiveRows)
        <> " positives, "
        <> show gate1Count
        <> " Gate-1, "
        <> show propertyCount
        <> " properties)"
    )

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

checkGate1 :: IO Int
checkGate1 = do
  contents <- Text.readFile "test/oracle/execution_accelerator/dhall_typecheck_cases.tsv"
  case Text.lines contents of
    [] -> fail "Phase-29 Gate-1 oracle is empty"
    header : rows -> do
      assert (header == "entry\tnegative\tlegal\trequired") "Phase-29 Gate-1 oracle header drifted"
      assert (length rows == 1) "Phase-29 Gate-1 oracle must contain one row"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [_, negative, legal, required] -> do
          dhall <- resolvedDhall
          (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack legal, "--quiet"]) ""
          assert (legalExit == ExitSuccess) (Text.unpack legal <> " rejected:\n" <> legalError)
          (negativeExit, negativeOut, negativeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
          let observed = Text.pack (negativeOut <> negativeError)
          assert (negativeExit /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus")
        _ -> fail ("malformed Phase-29 Gate-1 row: " <> Text.unpack row)
      pure (length rows)

countExecutionAcceleratorMutants :: IO Int
countExecutionAcceleratorMutants = do
  contents <- Text.readFile "test/mutant/registry.tsv"
  let isExecutionAccelerator row = case Text.splitOn "\t" row of
        capability : _ -> capability == "execution_accelerator"
        [] -> False
      count = length (filter isExecutionAccelerator (Text.lines contents))
  assert (count == 45) "Phase-29 mutant registry must contain 45 rows"
  pure count

checkExecutionAcceleratorCalculusProjection :: Int -> Int -> Int -> Int -> IO ()
checkExecutionAcceleratorCalculusProjection variants positives properties mutants = do
  expected <- loadMetricOracle "test/oracle/execution_accelerator/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "execution-accelerator-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "execution-accelerator-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "execution-negatives" (resources variants) (RecipeId "execution-accelerator-corpus" 1)
        budget = budgetComponent scope "execution-twins" (resources variants) (allowance (Bytes (fromIntegral variants)) (Slots 1) (Bytes (fromIntegral variants)))
        lift = liftComponent scope "composed-positives" (resources positives) OnHost
        workflow = workflowComponent scope "placement-properties" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [variants, variants, positives, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "execution/accelerator projection omitted or reordered a calculus"
    assert (actual == expected) ("execution/accelerator calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "execution-accelerator-calculus: PASS (5 kinds, "
        <> show (variants + variants + positives + properties + mutants)
        <> " projected units)"
    )

loadMetricOracle :: FilePath -> IO [(Text, Text)]
loadMetricOracle path = do
  contents <- Text.readFile path
  forM (drop 1 (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [metric, value] -> pure (metric, value)
    _ -> fail ("malformed calculus metric row: " <> Text.unpack row)


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
