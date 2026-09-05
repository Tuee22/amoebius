{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorGate
  ( runEngineAcceleratorGate
  ) where

import Amoebius.Capacity.Accelerator
  ( ProvisionedAccelerator (..)
  , ProvisionedAcceleratorEpoch (..)
  )
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
import Amoebius.Capacity.Provision
  ( provisionedEngineAccelerators
  )
import Amoebius.Capability.Engine
  ( EngineFamily (..)
  , EngineLane (..)
  , EngineOwnerDemand (CudaEngineOwner)
  , engineProvisionErrorTag
  , familyAvailable
  , offeringLane
  , provisionEngineOwner
  , provisionedEngineCapacity
  , provisionedEngineFamily
  , provisionedEngineLane
  )
import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import BindFixtures
  ( CapabilityFixture (..)
  , capabilityFixtures
  )
import Control.Monad (forM_, unless)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import EngineAcceleratorFixtures
  ( EngineNegative (..)
  , appleOffering
  , classCompleteCudaOwner
  , cpuOffering
  , cudaOffering
  , engineNegatives
  , windowsCudaOffering
  )
import EngineAcceleratorOracle
  ( expectedCalculusProjection
  , expectedCoexistence
  , expectedFamilies
  , expectedLocusEntries
  , expectedMutants
  , expectedNegatives
  , expectedOfferings
  )
import EngineAcceleratorProps (runEngineAcceleratorProps)
import ProvisionFixtures (provisionFixture)

runEngineAcceleratorGate :: IO ()
runEngineAcceleratorGate = do
  inference <- fixtureNamed "inferenceengine"
  positiveCount <- checkPositiveCorpus inference
  offeringCount <- checkOfferingQuotient
  familyCount <- checkFamilyRelation
  opaqueCount <- checkClassCompleteOwner
  negativeCount <- checkNegativeCorpus
  checkStructuralBoundary
  locusCount <- checkValidationLocus
  propertyCount <- runEngineAcceleratorProps
  let mutantCount = length expectedMutants
      availabilityCount = offeringCount + familyCount
  checkEngineAcceleratorCalculusProjection positiveCount availabilityCount negativeCount propertyCount mutantCount
  putStrLn
    ( "engine-accelerator-invariants: PASS ("
        <> show opaqueCount
        <> " opaque accelerator, "
        <> show locusCount
        <> " locus rows)"
    )
  putStrLn "capability-spec: PASS (3 inference positives, 4 offering quotients, 12 family/lane cells, 1 Gate-1, 8 provision negatives, 5 mutants, 1 covered property)"

fixtureNamed :: Text -> IO CapabilityFixture
fixtureNamed slug = case find ((== slug) . fixtureSlug) capabilityFixtures of
  Nothing -> fail ("missing capability fixture: " <> Text.unpack slug)
  Just fixture -> pure fixture

checkPositiveCorpus :: CapabilityFixture -> IO Int
checkPositiveCorpus inference = do
  forM_ [SingleNode, Distributed 3] $ \shape -> do
    sealed <- either (fail . show) pure (provisionFixture inference shape)
    assert (Map.keysSet (provisionedEngineAccelerators sealed) == Set.singleton "inference") "full provision seal omitted the inference accelerator witness"
  pure 3

checkOfferingQuotient :: IO Int
checkOfferingQuotient = do
  let observed =
        [ ("apple", offeringLane appleOffering)
        , ("linux-cpu", offeringLane cpuOffering)
        , ("linux-cuda", offeringLane cudaOffering)
        , ("windows", offeringLane windowsCudaOffering)
        ]
      rendered = Set.fromList [(name, Text.pack (show lane)) | (name, lane) <- observed]
      expected = Set.fromList expectedOfferings
  assert (length expectedOfferings == 4 && rendered == expected) "target-offering to engine-lane quotient drifted"
  assert (offeringLane cudaOffering == offeringLane windowsCudaOffering) "CUDA lane was split by operating system"
  pure (length expectedOfferings)

checkFamilyRelation :: IO Int
checkFamilyRelation = do
  let observed =
        Set.fromList
          [ (Text.pack (show family), Text.pack (show lane), if familyAvailable family lane then "available" else "unavailable")
          | family <- [minBound .. maxBound]
          , lane <- [minBound .. maxBound]
          ]
      expected = Set.fromList expectedFamilies
  assert (length expectedFamilies == 12 && observed == expected) "family/lane availability relation drifted"
  pure (length expectedFamilies)

checkClassCompleteOwner :: IO Int
checkClassCompleteOwner = do
  checked <- either (fail . show) pure (provisionEngineOwner cudaOffering LlamaFamily (CudaEngineOwner classCompleteCudaOwner))
  assert (provisionedEngineLane checked == CudaLane) "provisioned engine lane differs from selected offering"
  assert (provisionedEngineFamily checked == LlamaFamily) "provisioned engine family changed"
  let capacity = provisionedEngineCapacity checked
      observed =
        Set.fromList
          [ (provisionedAcceleratorEpochId epoch, device, Text.pack (show bytes))
          | epoch <- provisionedAcceleratorEpochs capacity
          , (device, bytes) <- Map.toList (provisionedVramByDevice epoch)
          ]
      expected = Set.fromList expectedCoexistence
  assert (observed == expected) "per-device coexistence aggregation differs from the hand-authored oracle"
  pure 1

checkNegativeCorpus :: IO Int
checkNegativeCorpus = do
  let expectedDomain = Set.fromList [name | (name, _tag, _twin, _layer) <- expectedNegatives]
      observedDomain = Set.insert "illegal_engine_by_url" (Set.fromList (fmap engineNegativeName engineNegatives))
  assert (length expectedNegatives == 9 && observedDomain == expectedDomain) "Phase-32 negative oracle must cover exactly nine cases"
  checkGate1Url
  forM_ engineNegatives $ \negative -> do
    case [row | row@(name, _tag, _twin, _layer) <- expectedNegatives, name == engineNegativeName negative] of
      [(_name, expected, twin, "provision-seal")] -> do
        assert (expected == engineNegativeExpected negative) "Phase-32 expected tag drifted"
        assert (twin == engineNegativeTwin negative) "Phase-32 legal twin drifted"
      _ -> fail "missing or duplicate Phase-32 provision oracle row"
    case engineNegativeOutcome negative of
      Left problem -> assert (engineProvisionErrorTag problem == engineNegativeExpected negative) ("wrong engine provision tag: " <> show problem)
      Right _ -> fail ("illegal engine case accepted: " <> Text.unpack (engineNegativeName negative))
    assertRight (engineNegativeTwinOutcome negative) ("legal engine twin rejected: " <> Text.unpack (engineNegativeTwin negative))
  pure (length expectedNegatives)

checkGate1Url :: IO ()
checkGate1Url =
  assert (lookup "illegal_engine_by_url" [(name, tag) | (name, tag, _twin, _layer) <- expectedNegatives] == Just "Url") "engine-by-URL oracle lost its Gate-1 foreclosure"

checkStructuralBoundary :: IO ()
checkStructuralBoundary = do
  assert (all (`notElem` ["Url", "Download"]) [Text.pack (show lane) | lane <- [minBound .. maxBound :: EngineLane]]) "EngineLane gained a URL/download escape arm"
  assert (length [minBound .. maxBound :: EngineLane] == 3) "EngineLane ceased to be the closed three-arm union"

checkValidationLocus :: IO Int
checkValidationLocus = do
  let observed = Set.fromList expectedLocusEntries
  assert (length expectedLocusEntries == Set.size observed) "Phase-32 validation-locus coverage contains duplicates"
  assert (Set.fromList (take 12 expectedLocusEntries) == Set.fromList (["legal_inference_singlenode", "legal_inference_distributed", "legal_inference_cuda", "illegal_engine_by_url"] <> fmap engineNegativeName engineNegatives)) "Phase-32 validation-locus subject corpus drifted"
  assert (length expectedLocusEntries == 17) "Phase-32 validation-locus ledger must contain exactly 17 rows"
  pure (length expectedLocusEntries)

checkEngineAcceleratorCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkEngineAcceleratorCalculusProjection positives availability negatives properties mutants = do
  tenant <- either (fail . show) pure (trustedTenant "inference-accelerator-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "inference-accelerator-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "inference-positives" (resources positives) (RecipeId "inference-accelerator-corpus" 1)
        budget = budgetComponent scope "availability-cells" (resources availability) (allowance (Bytes (fromIntegral availability)) (Slots 1) (Bytes (fromIntegral availability)))
        lift = liftComponent scope "boundary-negatives" (resources negatives) OnHost
        workflow = workflowComponent scope "accelerator-property" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [positives, availability, negatives, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "inference accelerator projection omitted or reordered a calculus"
    assert (actual == expectedCalculusProjection) ("inference accelerator calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "engine-accelerator-calculus: PASS (5 kinds, "
        <> show (positives + availability + negatives + properties + mutants)
        <> " projected units)"
    )

assertRight outcome message = case outcome of
  Left _ -> fail message
  Right _ -> pure ()

assert condition message = unless condition (fail message)
