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
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import StorageGeometryFixtures
  ( StorageFixture (..)
  , storageFixtures
  , storagePositiveRows
  )
import StorageGeometryProps (runStorageGeometryProps)
import StorageGeometryOracle
  ( OracleRow (..)
  , expectedCalculusProjection
  , expectedRows
  , mutantSpecs
  )

runStorageGeometryGate :: IO ()
runStorageGeometryGate = do
  let rows = expectedRows
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
    assert (result == Right ()) (Text.unpack name <> " storage rows rejected: " <> show result)
  propertyCount <- runStorageGeometryProps
  let mutantCount = length mutantSpecs
  assert (mutantCount == 31) "Phase-28 Haskell mutant oracle must contain 31 rows"
  checkStorageCalculusProjection (length rows) (length storagePositiveRows) propertyCount mutantCount
  putStrLn
    ( "storage-geometry-spec: PASS (5 named negatives, "
        <> show (length rows)
        <> " variants, "
        <> show (length rows)
        <> " twins, "
        <> show (length storagePositiveRows)
        <> " positives, "
        <> show propertyCount
        <> " properties, 31 changed-production mutants)"
    )

checkStorageCalculusProjection :: Int -> Int -> Int -> Int -> IO ()
checkStorageCalculusProjection variants positives properties mutants = do
  let expected = expectedCalculusProjection
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

drift :: OracleRow -> String -> String
drift row field = Text.unpack (oracleVariant row) <> " " <> field <> " drifted"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
