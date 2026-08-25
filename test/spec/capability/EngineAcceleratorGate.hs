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
  , fixturePath
  )
import Control.Monad (forM, forM_, unless)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import EngineAcceleratorFixtures
  ( EngineNegative (..)
  , appleOffering
  , classCompleteCudaOwner
  , cpuOffering
  , cudaOffering
  , engineNegatives
  , windowsCudaOffering
  )
import EngineAcceleratorMutants (engineAcceleratorMutants)
import EngineAcceleratorProps (runEngineAcceleratorProps)
import ProvisionFixtures (provisionFixture)
import System.IO.Unsafe (unsafePerformIO)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (ExitSuccess))
import System.Process (proc, readCreateProcessWithExitCode)

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
  let mutantCount = length engineAcceleratorMutants
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
    checkDhallGreen (fixturePath inference shape)
    sealed <- either (fail . show) pure (provisionFixture inference shape)
    assert (Map.keysSet (provisionedEngineAccelerators sealed) == Set.singleton "inference") "full provision seal omitted the inference accelerator witness"
  checkDhallGreen "dhall/examples/legal_inference_cuda.dhall"
  checkDhallGreen "dhall/examples/legal_inference_singlenode.dhall"
  checkDhallGreen "dhall/examples/legal_inference_distributed.dhall"
  pure 3

checkOfferingQuotient :: IO Int
checkOfferingQuotient = do
  rows <- rowsOf "test/oracle/inference_accelerator/offering_lane.tsv"
  let observed =
        [ ("apple", offeringLane appleOffering)
        , ("linux-cpu", offeringLane cpuOffering)
        , ("linux-cuda", offeringLane cudaOffering)
        , ("windows", offeringLane windowsCudaOffering)
        ]
      rendered = Set.fromList [(name, Text.pack (show lane)) | (name, lane) <- observed]
      expected = Set.fromList [(name, lane) | [name, lane] <- rows]
  assert (length rows == 4 && rendered == expected) "target-offering to engine-lane quotient drifted"
  assert (offeringLane cudaOffering == offeringLane windowsCudaOffering) "CUDA lane was split by operating system"
  pure (length rows)

checkFamilyRelation :: IO Int
checkFamilyRelation = do
  rows <- rowsOf "test/oracle/inference_accelerator/family_lane.tsv"
  let observed =
        Set.fromList
          [ (Text.pack (show family), Text.pack (show lane), if familyAvailable family lane then "available" else "unavailable")
          | family <- [minBound .. maxBound]
          , lane <- [minBound .. maxBound]
          ]
      expected = Set.fromList [(family, lane, status) | [family, lane, status] <- rows]
  assert (length rows == 12 && observed == expected) "family/lane availability relation drifted"
  pure (length rows)

checkClassCompleteOwner :: IO Int
checkClassCompleteOwner = do
  checked <- either (fail . show) pure (provisionEngineOwner cudaOffering LlamaFamily (CudaEngineOwner classCompleteCudaOwner))
  assert (provisionedEngineLane checked == CudaLane) "provisioned engine lane differs from selected offering"
  assert (provisionedEngineFamily checked == LlamaFamily) "provisioned engine family changed"
  oracle <- rowsOf "test/oracle/inference_accelerator/coexistence.tsv"
  let capacity = provisionedEngineCapacity checked
      observed =
        Set.fromList
          [ (provisionedAcceleratorEpochId epoch, device, Text.pack (show bytes))
          | epoch <- provisionedAcceleratorEpochs capacity
          , (device, bytes) <- Map.toList (provisionedVramByDevice epoch)
          ]
      expected = Set.fromList [(epoch, device, bytes) | [epoch, device, bytes] <- oracle]
  assert (observed == expected) "per-device coexistence aggregation differs from the hand-authored oracle"
  pure 1

checkNegativeCorpus :: IO Int
checkNegativeCorpus = do
  oracle <- rowsOf "test/oracle/inference_accelerator/provision_cases.tsv"
  let expectedDomain = Set.fromList [name | [name, _tag, _twin, _layer] <- oracle]
      observedDomain = Set.insert "illegal_engine_by_url" (Set.fromList (fmap engineNegativeName engineNegatives))
  assert (length oracle == 9 && observedDomain == expectedDomain) "Phase-33 negative oracle must cover exactly nine cases"
  checkGate1Url
  forM_ engineNegatives $ \negative -> do
    case [row | row@[name, _tag, _twin, _layer] <- oracle, name == engineNegativeName negative] of
      [[_name, expected, twin, "provision-seal"]] -> do
        assert (expected == engineNegativeExpected negative) "Phase-33 expected tag drifted"
        assert (twin == engineNegativeTwin negative) "Phase-33 legal twin drifted"
      _ -> fail "missing or duplicate Phase-33 provision oracle row"
    case engineNegativeOutcome negative of
      Left problem -> assert (engineProvisionErrorTag problem == engineNegativeExpected negative) ("wrong engine provision tag: " <> show problem)
      Right _ -> fail ("illegal engine case accepted: " <> Text.unpack (engineNegativeName negative))
    assertRight (engineNegativeTwinOutcome negative) ("legal engine twin rejected: " <> Text.unpack (engineNegativeTwin negative))
    checkDhallGreen ("dhall/examples/" <> Text.unpack (engineNegativeName negative) <> ".dhall")
    checkDhallGreen ("dhall/examples/" <> Text.unpack (engineNegativeTwin negative) <> ".dhall")
  pure (length oracle)

checkGate1Url :: IO ()
checkGate1Url = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc unsafeResolvedDhall ["type", "--file", "dhall/examples/illegal_engine_by_url.dhall", "--quiet"]) ""
  let output = Text.pack (stdoutText <> stderrText)
  assert (exitCode /= ExitSuccess && "Url" `Text.isInfixOf` output) "engine-by-URL did not fail Gate 1 at the Url alternative"

checkStructuralBoundary :: IO ()
checkStructuralBoundary = do
  types <- Text.readFile "src/Amoebius/Capability/Types.hs"
  engine <- Text.readFile "src/Amoebius/Capability/Engine.hs"
  let runtimeDeclaration = fst (Text.breakOn "data InferenceEngineNeed" (snd (Text.breakOn "data EngineRuntime" types)))
      exportHeader = fst (Text.breakOn ") where" engine)
  assert (not ("Url" `Text.isInfixOf` runtimeDeclaration || "Download" `Text.isInfixOf` runtimeDeclaration)) "EngineRuntime gained a URL/download escape arm"
  assert (not ("ProvisionedEngineAccelerator (.." `Text.isInfixOf` exportHeader)) "provisioned engine accelerator constructor is exported"

checkValidationLocus :: IO Int
checkValidationLocus = do
  rows <- rowsOf "test/oracle/inference_accelerator/validation_locus.tsv"
  let observed = Set.fromList [entry | [entry, _className, _locus, _status] <- rows]
      expected =
        Set.fromList
          ( [ "legal_inference_singlenode"
            , "legal_inference_distributed"
            , "legal_inference_cuda"
            , "illegal_engine_by_url"
            ]
              <> fmap engineNegativeName engineNegatives
              <> engineAcceleratorMutants
          )
  assert (length rows == Set.size expected && observed == expected) "Phase-33 validation-locus coverage drifted"
  assert (length rows == 17) "Phase-33 validation-locus ledger must contain exactly 17 rows"
  pure (length rows)

checkEngineAcceleratorCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkEngineAcceleratorCalculusProjection positives availability negatives properties mutants = do
  expected <- loadMetricOracle "test/oracle/inference_accelerator/calculus_projection.tsv"
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
    assert (actual == expected) ("inference accelerator calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "engine-accelerator-calculus: PASS (5 kinds, "
        <> show (positives + availability + negatives + properties + mutants)
        <> " projected units)"
    )

loadMetricOracle :: FilePath -> IO [(Text, Text)]
loadMetricOracle path = do
  contents <- Text.readFile path
  forM (drop 1 (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [metric, value] -> pure (metric, value)
    _ -> fail ("malformed calculus metric row: " <> Text.unpack row)

checkDhallGreen :: FilePath -> IO ()
checkDhallGreen path = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc unsafeResolvedDhall ["type", "--file", path, "--quiet"]) ""
  assert (exitCode == ExitSuccess) (path <> " is not well typed:\n" <> stdoutText <> stderrText)

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = do
  contents <- Text.readFile path
  pure [Text.splitOn "\t" line | line <- drop 1 (Text.lines contents), not (Text.null line)]

assertRight outcome message = case outcome of
  Left _ -> fail message
  Right _ -> pure ()

assert condition message = unless condition (fail message)

-- Resolved per run rather than reached by name: a bare `dhall` is an ambient PATH lookup,
-- which the boundary argv observer of `tools/argv_observer.py` refuses. Unset means fail,
-- never guess.
{-# NOINLINE unsafeResolvedDhall #-}
unsafeResolvedDhall :: FilePath
unsafeResolvedDhall = unsafePerformIO $ do
  value <- lookupEnv "AMOEBIUS_DHALL"
  case value of
    Just path | not (null path) -> pure path
    _ -> fail "AMOEBIUS_DHALL is unset: run this suite through its phase gate"
