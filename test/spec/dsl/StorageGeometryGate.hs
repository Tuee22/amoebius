{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryGate
  ( runStorageGeometryGate
  ) where

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
import Amoebius.Dsl.Decode (decodeCluster)
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
  assert (length rows == 30) "Phase-28 storage oracle must contain 30 variant rows"
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
      Left problem -> fail (Text.unpack name <> " failed Gate 2 before Phase-28 geometry: " <> show problem)
      Right _ -> pure ()
    assert (result == Right ()) (Text.unpack name <> " storage rows rejected: " <> show result)
  gate1Count <- checkGate1
  propertyCount <- runStorageGeometryProps
  mutantCount <- countStorageMutants
  checkStorageCalculusProjection (length rows) (length storagePositiveRows) propertyCount mutantCount
  putStrLn
    ( "storage-geometry-spec: PASS (5 named negatives, "
        <> show (length rows)
        <> " variants, "
        <> show (length rows)
        <> " twins, "
        <> show (length storagePositiveRows)
        <> " positives, "
        <> show gate1Count
        <> " Gate-1, "
        <> show propertyCount
        <> " properties)"
    )

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
  contents <- Text.readFile "test/oracle/storage_geometry/dhall_typecheck_cases.tsv"
  case Text.lines contents of
    [] -> fail "Phase-28 Gate-1 oracle is empty"
    header : rows -> do
      assert (header == "entry\tnegative\tlegal\trequired") "Phase-28 Gate-1 oracle header drifted"
      assert (length rows == 2) "Phase-28 Gate-1 oracle must contain two rows"
      forM_ rows $ \row -> case Text.splitOn "\t" row of
        [_, negative, legal, required] -> do
          dhall <- resolvedDhall
          (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack legal, "--quiet"]) ""
          assert (legalExit == ExitSuccess) (Text.unpack legal <> " rejected:\n" <> legalError)
          (negativeExit, negativeOut, negativeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
          let observed = Text.pack (negativeOut <> negativeError)
          assert (negativeExit /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus")
        _ -> fail ("malformed Phase-28 Gate-1 row: " <> Text.unpack row)
      pure (length rows)

countStorageMutants :: IO Int
countStorageMutants = do
  contents <- Text.readFile "test/mutant/registry.tsv"
  let isStorage row = case Text.splitOn "\t" row of
        capability : _ -> capability == "storage_geometry"
        [] -> False
      count = length (filter isStorage (Text.lines contents))
  assert (count == 31) "Phase-28 mutant registry must contain 31 rows"
  pure count

checkStorageCalculusProjection :: Int -> Int -> Int -> Int -> IO ()
checkStorageCalculusProjection variants positives properties mutants = do
  expected <- loadMetricOracle "test/oracle/storage_geometry/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "storage-geometry-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "storage-geometry-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "storage-negatives" (resources variants) (RecipeId "storage-geometry-corpus" 1)
        budget = budgetComponent scope "storage-twins" (resources variants) (allowance (Bytes (fromIntegral variants)) (Slots 1) (Bytes (fromIntegral variants)))
        lift = liftComponent scope "positive-specs" (resources positives) OnHost
        workflow = workflowComponent scope "envelope-properties" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [variants, variants, positives, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "storage projection omitted or reordered a calculus"
    assert (actual == expected) ("storage calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "storage-geometry-calculus: PASS (5 kinds, "
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
