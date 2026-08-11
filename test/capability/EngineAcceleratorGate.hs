{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorGate
  ( runEngineAcceleratorGate
  ) where

import Amoebius.Capacity.Accelerator
  ( ProvisionedAccelerator (..)
  , ProvisionedAcceleratorEpoch (..)
  )
import Amoebius.Capacity.Provision
  ( provisionedEngineAccelerators
  )
import Amoebius.Capability.Engine
  ( EngineFamily (..)
  , EngineLane (..)
  , EngineOwnerDemand (CudaEngineOwner)
  , TargetOffering
  , engineProvisionErrorTag
  , familyAvailable
  , offeringLane
  , provisionEngineOwner
  , provisionedEngineCapacity
  , provisionedEngineFamily
  , provisionedEngineLane
  )
import Amoebius.Capability.Types (ServiceShape (..))
import BindFixtures
  ( CapabilityFixture (..)
  , capabilityFixtures
  , fixturePath
  )
import Control.Monad (forM_, unless)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import EngineAcceleratorFixtures
  ( EngineNegative (..)
  , appleOffering
  , baseCudaOwner
  , classCompleteCudaOwner
  , cpuOffering
  , cudaOffering
  , engineNegatives
  , windowsCudaOffering
  )
import EngineAcceleratorMutants (engineAcceleratorMutants)
import EngineAcceleratorProps (runEngineAcceleratorProps)
import ProvisionFixtures (provisionFixture)
import System.Exit (ExitCode (ExitSuccess))
import System.Process (proc, readCreateProcessWithExitCode)

runEngineAcceleratorGate :: IO ()
runEngineAcceleratorGate = do
  inference <- fixtureNamed "inferenceengine"
  checkPositiveCorpus inference
  checkOfferingQuotient
  checkFamilyRelation
  checkClassCompleteOwner
  checkNegativeCorpus
  checkStructuralBoundary
  checkValidationLocus
  runEngineAcceleratorProps
  putStrLn "capability-spec: PASS (3 inference positives, 4 offering quotients, 12 family/lane cells, 1 Gate-1, 8 provision negatives, 5 mutants, 1 covered property)"

fixtureNamed :: Text -> IO CapabilityFixture
fixtureNamed slug = case find ((== slug) . fixtureSlug) capabilityFixtures of
  Nothing -> fail ("missing capability fixture: " <> Text.unpack slug)
  Just fixture -> pure fixture

checkPositiveCorpus :: CapabilityFixture -> IO ()
checkPositiveCorpus inference = do
  forM_ [SingleNode, Distributed 3] $ \shape -> do
    checkDhallGreen (fixturePath inference shape)
    sealed <- either (fail . show) pure (provisionFixture inference shape)
    assert (Map.keysSet (provisionedEngineAccelerators sealed) == Set.singleton "inference") "full provision seal omitted the inference accelerator witness"
  checkDhallGreen "dhall/examples/legal_inference_cuda.dhall"
  checkDhallGreen "dhall/examples/legal_inference_singlenode.dhall"
  checkDhallGreen "dhall/examples/legal_inference_distributed.dhall"

checkOfferingQuotient :: IO ()
checkOfferingQuotient = do
  rows <- rowsOf "tests/oracle/phase12/offering_lane.tsv"
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

checkFamilyRelation :: IO ()
checkFamilyRelation = do
  rows <- rowsOf "tests/oracle/phase12/family_lane.tsv"
  let observed =
        Set.fromList
          [ (Text.pack (show family), Text.pack (show lane), if familyAvailable family lane then "available" else "unavailable")
          | family <- [minBound .. maxBound]
          , lane <- [minBound .. maxBound]
          ]
      expected = Set.fromList [(family, lane, status) | [family, lane, status] <- rows]
  assert (length rows == 12 && observed == expected) "family/lane availability relation drifted"

checkClassCompleteOwner :: IO ()
checkClassCompleteOwner = do
  checked <- either (fail . show) pure (provisionEngineOwner cudaOffering LlamaFamily (CudaEngineOwner classCompleteCudaOwner))
  assert (provisionedEngineLane checked == CudaLane) "provisioned engine lane differs from selected offering"
  assert (provisionedEngineFamily checked == LlamaFamily) "provisioned engine family changed"
  oracle <- rowsOf "tests/oracle/phase12/coexistence.tsv"
  let capacity = provisionedEngineCapacity checked
      observed =
        Set.fromList
          [ (provisionedAcceleratorEpochId epoch, device, Text.pack (show bytes))
          | epoch <- provisionedAcceleratorEpochs capacity
          , (device, bytes) <- Map.toList (provisionedVramByDevice epoch)
          ]
      expected = Set.fromList [(epoch, device, bytes) | [epoch, device, bytes] <- oracle]
  assert (observed == expected) "per-device coexistence aggregation differs from the hand-authored oracle"

checkNegativeCorpus :: IO ()
checkNegativeCorpus = do
  oracle <- rowsOf "tests/oracle/phase12/provision_cases.tsv"
  let expectedDomain = Set.fromList [name | [name, _tag, _twin, _layer] <- oracle]
      observedDomain = Set.insert "illegal_engine_by_url" (Set.fromList (fmap engineNegativeName engineNegatives))
  assert (length oracle == 9 && observedDomain == expectedDomain) "Phase-12 negative oracle must cover exactly nine cases"
  checkGate1Url
  forM_ engineNegatives $ \negative -> do
    case [row | row@[name, _tag, _twin, _layer] <- oracle, name == engineNegativeName negative] of
      [[_name, expected, twin, "provision-seal"]] -> do
        assert (expected == engineNegativeExpected negative) "Phase-12 expected tag drifted"
        assert (twin == engineNegativeTwin negative) "Phase-12 legal twin drifted"
      _ -> fail "missing or duplicate Phase-12 provision oracle row"
    case engineNegativeOutcome negative of
      Left problem -> assert (engineProvisionErrorTag problem == engineNegativeExpected negative) ("wrong engine provision tag: " <> show problem)
      Right _ -> fail ("illegal engine case accepted: " <> Text.unpack (engineNegativeName negative))
    assertRight (engineNegativeTwinOutcome negative) ("legal engine twin rejected: " <> Text.unpack (engineNegativeTwin negative))
    checkDhallGreen ("dhall/examples/" <> Text.unpack (engineNegativeName negative) <> ".dhall")
    checkDhallGreen ("dhall/examples/" <> Text.unpack (engineNegativeTwin negative) <> ".dhall")

checkGate1Url :: IO ()
checkGate1Url = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc "dhall" ["type", "--file", "dhall/examples/illegal_engine_by_url.dhall", "--quiet"]) ""
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

checkValidationLocus :: IO ()
checkValidationLocus = do
  rows <- rowsOf "tests/oracle/phase12/validation_locus.tsv"
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
  assert (length rows == Set.size expected && observed == expected) "Phase-12 validation-locus coverage drifted"

checkDhallGreen :: FilePath -> IO ()
checkDhallGreen path = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc "dhall" ["type", "--file", path, "--quiet"]) ""
  assert (exitCode == ExitSuccess) (path <> " is not well typed:\n" <> stdoutText <> stderrText)

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = do
  contents <- Text.readFile path
  pure [Text.splitOn "\t" line | line <- drop 1 (Text.lines contents), not (Text.null line)]

assertRight outcome message = case outcome of
  Left _ -> fail message
  Right _ -> pure ()

assert condition message = unless condition (fail message)
