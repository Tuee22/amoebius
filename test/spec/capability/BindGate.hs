{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module BindGate
  ( runBindGate
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ControllerBody (..)
  , ExecutionTransitionSource (FirstDeployment)
  )
import Amoebius.Capability.Binding
  ( assembleBoundDeployment
  , bind
  , decodeCapabilityProvider
  , renderBoundServiceSpec
  , validateBindingCoverage
  , validateExtensionGraph
  )
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (..)
  , BoundServiceSpec (..)
  , CapabilityArm (..)
  , CapabilityBinding (..)
  , CapabilityNeed (..)
  , EngineRuntime (AppleMetal)
  , ExtensionDescriptor (ExtensionDescriptor)
  , ExtensionName (..)
  , InferenceEngineNeed (InferenceEngineNeed)
  , ObjectStoreProducerKind (RegistryProducer)
  , ProviderIntent (RegistryStorageProducerIntent)
  , RegistryStorageIntent (RegistryStorageIntent)
  , ServiceShape (..)
  , capabilityArm
  , capabilityResourceName
  )
import Amoebius.Dsl.Error (DecodeError (..), decodeErrorTag)
import BindFixtures
  ( CapabilityFixture (..)
  , capabilityFixtures
  , distributedBinding
  , fixturePath
  , goldenPath
  , oracleArms
  , singleBinding
  )
import BindMutants (capabilityMutants)
import BindProps (runBindProps)
import Control.Monad (forM, forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Dhall qualified
import GHC.Generics (Generic)
import ShapeOracle
  ( normalizedAppSlice
  , structurallyDifferentByNodeMultiset
  , validateBoundExecutionInventory
  )
import System.Exit (ExitCode (ExitSuccess))
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)
import System.Process (proc, readCreateProcessWithExitCode)

data ArmOracleRow = ArmOracleRow
  { oracleSlug :: Text
  , oracleArm :: Text
  , oracleResource :: Text
  }

data RawProvider = RawProvider
  { provider :: Text
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RawBinding = RawBinding
  { capability :: Text
  , provider :: Text
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RawCoverage = RawCoverage
  { declared :: [Text]
  , bindings :: [RawBinding]
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RawExtension = RawExtension
  { name :: Text
  , provides :: [Text]
  , requires :: [Text]
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

newtype RawExtensionGraph = RawExtensionGraph
  { extensions :: [RawExtension]
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

runBindGate :: IO ()
runBindGate = do
  oracle <- loadArmOracle
  assert (length oracle == 9) "Phase-10 arm oracle must contain exactly nine rows"
  assert (fmap fixtureArm capabilityFixtures == oracleArms) "fixture list no longer covers the independently pinned arm order"
  assert (Set.fromList (fmap fixtureSlug capabilityFixtures) == Set.fromList (fmap oracleSlug oracle)) "fixture/oracle slug coverage drifted"
  assert (Set.fromList (fmap (Text.pack . show) oracleArms) == Set.fromList (fmap oracleArm oracle)) "fixture/oracle arm coverage drifted"
  assert (Set.fromList (fmap (capabilityResourceName . fixtureNeed) capabilityFixtures) == Set.fromList (fmap oracleResource oracle)) "fixture/oracle resource coverage drifted"
  services <- fmap concat (mapM checkFixture capabilityFixtures)
  checkGate1
  checkGate2
  checkDeployment services
  checkRegistryIntent services
  checkControllerKinds services
  checkStructuralBoundary
  checkLedgerCoverage
  runBindProps
  putStrLn "capability-bind-spec: PASS (9 arms, 18 shape goldens, 3 Gate-1, 4 Gate-2, 4 mutants, 1 covered property)"

checkFixture :: CapabilityFixture -> IO [BoundServiceSpec]
checkFixture fixture = do
  let singlePath = fixturePath fixture SingleNode
      distributedPath = fixturePath fixture (Distributed 3)
      single = bind (fixtureNeed fixture) singleBinding
      distributed = bind (fixtureNeed fixture) distributedBinding
  assert (singlePath /= distributedPath) (Text.unpack (fixtureSlug fixture) <> " composed files are not distinct")
  checkDhallGreen singlePath
  checkDhallGreen distributedPath
  singleApp <- normalizedAppSlice singlePath
  distributedApp <- normalizedAppSlice distributedPath
  assert (singleApp == distributedApp) (Text.unpack (fixtureSlug fixture) <> " app-surface normalized bytes changed across shapes")
  assert (structurallyDifferentByNodeMultiset single distributed) (Text.unpack (fixtureSlug fixture) <> " changed only by scalar/tag, not object-node multiset")
  assert (validateBoundExecutionInventory single) (Text.unpack (fixtureSlug fixture) <> " single-node execution inventory diverged")
  assert (validateBoundExecutionInventory distributed) (Text.unpack (fixtureSlug fixture) <> " distributed execution inventory diverged")
  checkGolden fixture SingleNode single
  checkGolden fixture (Distributed 3) distributed
  pure [single, distributed]

checkGolden :: CapabilityFixture -> ServiceShape -> BoundServiceSpec -> IO ()
checkGolden fixture shape service = do
  expected <- Text.readFile (goldenPath fixture shape)
  let actual = renderBoundServiceSpec service
  assert (actual == expected) (goldenPath fixture shape <> " differs from bound representation\nEXPECTED:\n" <> Text.unpack expected <> "ACTUAL:\n" <> Text.unpack actual)

checkGate1 :: IO ()
checkGate1 = do
  rows <- rowsOf "test/oracle/capability_bind/gate1_cases.tsv"
  assert (length rows == 3) "Phase-10 Gate-1 oracle must contain three negatives"
  forM_ rows $ \row -> case row of
    [_caseName, negative, legal, required] -> do
      checkDhallGreen (Text.unpack legal)
      (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
      let observed = Text.pack (stdoutText <> stderrText)
      assert (exitCode /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus " <> Text.unpack required)
    _ -> fail "malformed Phase-10 Gate-1 oracle row"

checkGate2 :: IO ()
checkGate2 = do
  providerNegative <- decodeProviderFixture "dhall/examples/illegal_unbuilt_provider.dhall"
  providerPositive <- decodeProviderFixture "dhall/examples/legal_built_provider.dhall"
  assertTag "UnbuiltProviderArm" providerNegative
  assertRight providerPositive "built canonical provider rejected"

  coverageNegative <- decodeCoverageFixture "dhall/examples/illegal_unbound_capability.dhall"
  coveragePositive <- decodeCoverageFixture "dhall/examples/legal_bound_capability.dhall"
  assertTag "UnboundCapability" coverageNegative
  assertRight coveragePositive "complete capability binding rejected"

  cycleNegative <- decodeExtensionFixture "dhall/examples/illegal_cyclic_extension.dhall"
  shadowNegative <- decodeExtensionFixture "dhall/examples/illegal_shadowing_extension.dhall"
  extensionPositive <- decodeExtensionFixture "dhall/examples/legal_extension_graph.dhall"
  assertTag "CyclicExtension" cycleNegative
  assertTag "ShadowingExtension" shadowNegative
  assertRight extensionPositive "legal infernix/jitML extension graph rejected"

  oracle <- rowsOf "test/oracle/capability_bind/gate2_cases.tsv"
  assert (length oracle == 4) "Phase-10 Gate-2 oracle must contain four negatives"
  assert
    ( Set.fromList [expected | [_name, expected, _negative, _legal] <- oracle]
        == Set.fromList ["UnbuiltProviderArm", "UnboundCapability", "CyclicExtension", "ShadowingExtension"]
    )
    "Phase-10 Gate-2 specific-tag oracle drifted"

checkDeployment :: [BoundServiceSpec] -> IO ()
checkDeployment services = do
  let oneShape = everyOther services
  deployment <- case assembleBoundDeployment FirstDeployment Nothing Nothing oneShape of
    Left problem -> fail ("all-arm BoundDeployment assembly failed: " <> show problem)
    Right value -> pure value
  let expectedUnits = sum (fmap (Map.size . boundExecutionUnits . boundServiceExecutions) oneShape)
      actualUnits = Map.size (boundExecutionUnits (boundDeploymentExecutions deployment))
  assert (Map.size (boundDeploymentServices deployment) == 9) "BoundDeployment omitted a capability service"
  assert (actualUnits == expectedUnits) "BoundDeployment execution set omitted or duplicated a runnable"
  assert (length (boundDeploymentControllerExplanations deployment) == expectedUnits) "controller explanations are not exactly one per runnable"

checkRegistryIntent :: [BoundServiceSpec] -> IO ()
checkRegistryIntent services = case [service | service <- services, capabilityArmOf service == Registry] of
  [] -> fail "registry service is absent"
  service : _ ->
    assert
      (boundProviderIntents service == [RegistryStorageProducerIntent RegistryProducer (RegistryStorageIntent "images")])
      "Registry did not cross ObjectStoreProducerIntent.Registry into RegistryStorageIntent on the bound side"

checkControllerKinds :: [BoundServiceSpec] -> IO ()
checkControllerKinds services = do
  let apple = bind (InferenceEngineCapabilityNeed (InferenceEngineNeed "metal-engine" "metal-profile" (AppleMetal "metal-catalog"))) singleBinding
      tags :: Set.Set Text
      tags = Set.fromList (concatMap controllerTags (apple : services))
  assert (tags == Set.fromList ["Deployment", "StatefulSet", "DaemonSet", "Job", "HostProcess"]) "bound execution vocabulary does not exercise all five controller kinds"
 where
  controllerTags service = fmap (controllerTag . executionBody) (Map.elems (boundExecutionUnits (boundServiceExecutions service)))
  controllerTag body = case body of
    DeploymentBody {} -> "Deployment"
    StatefulSetBody {} -> "StatefulSet"
    DaemonSetBody {} -> "DaemonSet"
    JobBody {} -> "Job"
    HostProcessBody {} -> "HostProcess"

checkStructuralBoundary :: IO ()
checkStructuralBoundary = do
  source <- Text.readFile "src/Amoebius/Capability/Types.hs"
  let afterStart = snd (Text.breakOn "data BoundDeployment" source)
      declaration = fst (Text.breakOn "data ExtensionName" afterStart)
      requiredFields =
        [ "boundDeploymentTransition"
        , "boundDeploymentServices"
        , "boundDeploymentExecutions"
        , "boundDeploymentControllerExplanations"
        , "boundPriorVolumeRef"
        , "boundPriorRegistryRef"
        ]
  assert (not (Text.null declaration)) "BoundDeployment declaration is absent"
  assert (not ("Provisioned" `Text.isInfixOf` declaration)) "BoundDeployment contains a Provisioned field or value"
  assert (all (`Text.isInfixOf` declaration) requiredFields) "BoundDeployment structural inventory drifted"

checkLedgerCoverage :: IO ()
checkLedgerCoverage = do
  rows <- rowsOf "test/oracle/capability_bind/validation_locus.tsv"
  let observed = Set.fromList [entry | [entry, _className, _locus, _status] <- rows]
      positives =
        Set.fromList
          [ "legal_" <> fixtureSlug fixture <> "_" <> shape
          | fixture <- capabilityFixtures
          , shape <- ["singlenode", "distributed"]
          ]
      negatives =
        Set.fromList
          [ "illegal_product_in_app"
          , "illegal_engine_by_url"
          , "illegal_shape_in_app"
          , "illegal_unbuilt_provider"
          , "illegal_unbound_capability"
          , "illegal_cyclic_extension"
          , "illegal_shadowing_extension"
          ]
      expected = positives <> negatives <> Set.fromList capabilityMutants
  assert (observed == expected) "Phase-10 validation-locus ledger does not cover every positive, negative, and mutant"

decodeProviderFixture :: FilePath -> IO (Either DecodeError ())
decodeProviderFixture path = do
  RawProvider {provider = providerName} <- Dhall.inputFile Dhall.auto path
  pure (() <$ decodeCapabilityProvider providerName)

decodeCoverageFixture :: FilePath -> IO (Either DecodeError ())
decodeCoverageFixture path = do
  RawCoverage {declared = declaredNames, bindings = rawBindings} <- Dhall.inputFile Dhall.auto path
  pure $ do
    declaredArms <- Set.fromList <$> traverse parseArm declaredNames
    bindingRows <- forM rawBindings $ \RawBinding {capability = armText, provider = providerText} -> do
      arm <- parseArm armText
      providerArm <- decodeCapabilityProvider providerText
      pure (arm, singleBinding {bindingProvider = providerArm})
    validateBindingCoverage declaredArms (Map.fromList bindingRows)

decodeExtensionFixture :: FilePath -> IO (Either DecodeError ())
decodeExtensionFixture path = do
  RawExtensionGraph {extensions = rawExtensions} <- Dhall.inputFile Dhall.auto path
  pure $ do
    descriptors <- traverse parseExtension rawExtensions
    validateExtensionGraph descriptors

parseExtension :: RawExtension -> Either DecodeError ExtensionDescriptor
parseExtension RawExtension {name = extensionNameText, provides = providedTexts, requires = requiredTexts} = do
  extensionNameValue <- parseExtensionName extensionNameText
  provided <- Set.fromList <$> traverse parseArm providedTexts
  required <- Set.fromList <$> traverse parseArm requiredTexts
  pure (ExtensionDescriptor extensionNameValue provided required)

parseExtensionName :: Text -> Either DecodeError ExtensionName
parseExtensionName value = case value of
  "infernix" -> Right InfernixExtension
  "jitML" -> Right JitMLExtension
  unknown -> Left (OutOfDomainArm ("extension.name." <> unknown))

parseArm :: Text -> Either DecodeError CapabilityArm
parseArm value = case value of
  "ObjectStore" -> Right ObjectStore
  "SecretStore" -> Right SecretStore
  "MessageBus" -> Right MessageBus
  "Sql" -> Right Sql
  "Identity" -> Right Identity
  "Observability" -> Right Observability
  "Registry" -> Right Registry
  "Edge" -> Right Edge
  "InferenceEngine" -> Right InferenceEngine
  unknown -> Left (OutOfDomainArm ("capability." <> unknown))

loadArmOracle :: IO [ArmOracleRow]
loadArmOracle = do
  rows <- rowsOf "test/oracle/capability_bind/arm_cases.tsv"
  traverse parse rows
 where
  parse row = case row of
    [slug, arm, resource] -> pure (ArmOracleRow slug arm resource)
    _ -> fail "malformed Phase-10 arm oracle row"

checkDhallGreen :: FilePath -> IO ()
checkDhallGreen path = do
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", path, "--quiet"]) ""
  assert (exitCode == ExitSuccess) (path <> " rejected by Gate 1:\n" <> stderrText)

assertTag :: Text -> Either DecodeError value -> IO ()
assertTag expected outcome = case outcome of
  Left problem -> assert (decodeErrorTag problem == expected) ("expected " <> Text.unpack expected <> ", observed " <> Text.unpack (decodeErrorTag problem))
  Right _ -> fail (Text.unpack expected <> " negative unexpectedly decoded")

assertRight :: Either DecodeError value -> String -> IO ()
assertRight outcome message = case outcome of
  Left problem -> fail (message <> ": " <> show problem)
  Right _ -> pure ()

capabilityArmOf :: BoundServiceSpec -> CapabilityArm
capabilityArmOf = capabilityArm . boundCapabilityNeed

everyOther :: [value] -> [value]
everyOther values = case values of
  [] -> []
  value : _paired : rest -> value : everyOther rest
  [value] -> [value]

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = do
  contents <- Text.readFile path
  pure [Text.splitOn "\t" line | line <- drop 1 (Text.lines contents), not (Text.null line), not ("#" `Text.isPrefixOf` line)]

dhall :: FilePath
dhall = unsafeResolvedDhall

-- Resolved per run rather than pinned: a tracked file naming one developer's executable is
-- resolver output (repository_layout_doctrine.md section 4). Unset means fail, never guess.
{-# NOINLINE unsafeResolvedDhall #-}
unsafeResolvedDhall :: FilePath
unsafeResolvedDhall = unsafePerformIO $ do
  value <- lookupEnv "AMOEBIUS_DHALL"
  case value of
    Just path | not (null path) -> pure path
    _ -> fail "AMOEBIUS_DHALL is unset: run this gate through tools/capability_bind_gate.py"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
