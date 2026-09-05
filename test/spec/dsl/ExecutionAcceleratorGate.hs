{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorGate
  ( runExecutionAcceleratorGate
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
import Data.Text (Text)
import Data.Text qualified as Text
import ExecutionAcceleratorFixtures
  ( Phase29Fixture (..)
  , phase29Fixtures
  , phase29PositiveRows
  , runPhase29DeterministicChecks
  )
import ExecutionAcceleratorProps (runExecutionAcceleratorProps)
import ExecutionAcceleratorOracle
  ( OracleRow (..)
  , expectedCalculusProjection
  , expectedRows
  , mutantSpecs
  )

runExecutionAcceleratorGate :: IO ()
runExecutionAcceleratorGate = do
  let rows = expectedRows
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
    assert (result == Right ()) (Text.unpack name <> " composed placement rejected: " <> show result)
  runPhase29DeterministicChecks
  propertyCount <- runExecutionAcceleratorProps
  let mutantCount = length mutantSpecs
  assert (mutantCount == 45) "Phase-29 Haskell mutant oracle must contain 45 rows"
  checkExecutionAcceleratorCalculusProjection (length rows) (length phase29PositiveRows) propertyCount mutantCount
  putStrLn
    ( "execution-accelerator-spec: PASS (18 named negatives, "
        <> show (length rows)
        <> " variants, "
        <> show (length rows)
        <> " twins, "
        <> show (length phase29PositiveRows)
        <> " positives, "
        <> show propertyCount
        <> " properties, 45 changed-production mutants)"
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

checkExecutionAcceleratorCalculusProjection :: Int -> Int -> Int -> Int -> IO ()
checkExecutionAcceleratorCalculusProjection variants positives properties mutants = do
  let expected = expectedCalculusProjection
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

drift :: OracleRow -> String -> String
drift row field = Text.unpack (oracleVariant row) <> " " <> field <> " drifted"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
