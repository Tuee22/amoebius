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
  , ExecutionTransitionSource (FirstDeployment, UpdateFrom)
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
import Amoebius.Capability.Binding
  ( assembleBoundDeployment
  , bind
  , decodeCapabilityProvider
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
  , CapabilityProvider (CanonicalProvider)
  , EngineRuntime (AppleMetal)
  , ExtensionDescriptor (ExtensionDescriptor)
  , ExtensionName (..)
  , InferenceEngineNeed (InferenceEngineNeed)
  , ObjectStoreProducerKind (RegistryProducer)
  , ProviderIntent (RegistryStorageProducerIntent)
  , PriorRegistryProvisionRef (PriorRegistryProvisionRef)
  , PriorVolumeProvisionRef (PriorVolumeProvisionRef)
  , RegistryStorageIntent (RegistryStorageIntent)
  , ServiceShape (..)
  , capabilityArm
  , capabilityResourceName
  )
import Amoebius.Dsl.Error (DecodeError (..), decodeErrorTag)
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import BindFixtures
  ( CapabilityFixture (..)
  , capabilityFixtures
  , distributedBinding
  , fixturePath
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
  ( objectNodeMultiset
  , normalizedAppSlice
  , structurallyDifferentByNodeMultiset
  , validateBoundExecutionInventory
  )
import System.Exit (ExitCode (ExitSuccess))
import System.Environment (lookupEnv)
import System.IO.Unsafe (unsafePerformIO)
import System.Process (proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

data ArmOracleRow = ArmOracleRow
  { oracleSlug :: Text
  , oracleArm :: Text
  , oracleResource :: Text
  }

data ShapeSemanticRow = ShapeSemanticRow
  { semanticSlug :: Text
  , semanticProduct :: Text
  , semanticMemberKind :: Text
  , semanticControllerKind :: Text
  , semanticHasBootstrap :: Bool
  , semanticSingleObjects :: Int
  , semanticDistributedObjects :: Int
  , semanticSingleExecutions :: Int
  , semanticDistributedExecutions :: Int
  , semanticIntentCount :: Int
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
  semantics <- loadShapeSemanticOracle
  assert (length oracle == 9) "Phase-30 arm oracle must contain exactly nine rows"
  assert (length semantics == 9) "Phase-30 semantic shape oracle must contain exactly nine rows"
  assert (fmap fixtureArm capabilityFixtures == oracleArms) "fixture list no longer covers the independently pinned arm order"
  assert (Set.fromList (fmap fixtureSlug capabilityFixtures) == Set.fromList (fmap oracleSlug oracle)) "fixture/oracle slug coverage drifted"
  assert (fmap semanticSlug semantics == fmap oracleSlug oracle) "semantic shape oracle no longer follows the pinned arm order"
  assert (Set.fromList (fmap (Text.pack . show) oracleArms) == Set.fromList (fmap oracleArm oracle)) "fixture/oracle arm coverage drifted"
  assert (Set.fromList (fmap (capabilityResourceName . fixtureNeed) capabilityFixtures) == Set.fromList (fmap oracleResource oracle)) "fixture/oracle resource coverage drifted"
  services <- fmap concat (sequence (zipWith checkFixture capabilityFixtures semantics))
  gate1Count <- checkGate1
  gate2Count <- checkGate2
  unresolvedReferenceCount <- checkDeployment services
  registryShapeCount <- checkRegistryIntent services
  extensionTotalityCount <- checkExtensionTotality
  checkControllerKinds services
  checkStructuralBoundary
  ledgerCount <- checkLedgerCoverage
  propertyCount <- runBindProps
  let mutantCount = length capabilityMutants
      executionInventoryCount = length services
  assert (mutantCount == 4) "Phase-30 mutant set must contain four entries"
  checkCapabilityBindCalculusProjection (length oracle) (length services) (gate1Count + gate2Count) propertyCount mutantCount
  putStrLn
    ( "capability-bind-invariants: PASS ("
        <> show executionInventoryCount
        <> " execution inventories, "
        <> show unresolvedReferenceCount
        <> " unresolved references, "
        <> show registryShapeCount
        <> " registry shapes, "
        <> show extensionTotalityCount
        <> " extension-totality cases, "
        <> show ledgerCount
        <> " locus rows)"
    )
  putStrLn
    ( "capability-bind-spec: PASS (9 arms, 18 semantic shapes, "
        <> show gate1Count
        <> " Gate-1, "
        <> show gate2Count
        <> " Gate-2, 4 mutants, "
        <> show propertyCount
        <> " covered property)"
    )

checkFixture :: CapabilityFixture -> ShapeSemanticRow -> IO [BoundServiceSpec]
checkFixture fixture semantics = do
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
  checkSemanticShape semantics SingleNode single
  checkSemanticShape semantics (Distributed 3) distributed
  pure [single, distributed]

checkSemanticShape :: ShapeSemanticRow -> ServiceShape -> BoundServiceSpec -> IO ()
checkSemanticShape semantics shape service = do
  let isDistributed = case shape of
        SingleNode -> False
        Distributed _ -> True
      memberCount = if isDistributed then 3 else 1
      objectCount = if isDistributed then semanticDistributedObjects semantics else semanticSingleObjects semantics
      executionCount = if isDistributed then semanticDistributedExecutions semantics else semanticSingleExecutions semantics
      bootstrapObjects = if semanticHasBootstrap semantics then [("Job", "bootstrap", 1)] else []
      distributedObjects =
        if isDistributed
          then [("Service", "member-discovery", 1), ("PodDisruptionBudget", "quorum-policy", 1)]
          else []
      expectedObjects =
        Map.fromList
          ( [ ( ("Service", "stable-endpoint"), 1)
            , ( ("ConfigMap", "provider-config"), 1)
            , ( (semanticMemberKind semantics, "member"), memberCount)
            ]
              <> [((kind, role), count) | (kind, role, count) <- bootstrapObjects <> distributedObjects]
          )
      expectedControllers =
        Map.fromList
          ( [(semanticControllerKind semantics, memberCount)]
              <> if semanticHasBootstrap semantics then [("Job", 1)] else []
          )
      actualControllers =
        Map.fromListWith (+)
          [ (controllerTag (executionBody unit), 1 :: Int)
          | unit <- Map.elems (boundExecutionUnits (boundServiceExecutions service))
          ]
      label = Text.unpack (semanticSlug semantics) <> " " <> show shape
  assert (boundProvider service == CanonicalProvider) (label <> " provider drifted")
  assert (boundShape service == shape) (label <> " shape drifted")
  assert (boundProviderProduct service == semanticProduct semantics) (label <> " product drifted")
  assert (length (boundProviderGraph service) == objectCount) (label <> " object count drifted")
  assert (Map.size (boundExecutionUnits (boundServiceExecutions service)) == executionCount) (label <> " execution count drifted")
  assert (length (boundProviderIntents service) == semanticIntentCount semantics) (label <> " intent count drifted")
  assert (objectNodeMultiset service == expectedObjects) (label <> " object kind/role multiset drifted")
  assert (actualControllers == expectedControllers) (label <> " controller-kind multiset drifted")

checkGate1 :: IO Int
checkGate1 = do
  rows <- rowsOf "test/oracle/capability_bind/dhall_typecheck_cases.tsv"
  assert (length rows == 3) "Phase-30 Gate-1 oracle must contain three negatives"
  forM_ rows $ \row -> case row of
    [_caseName, negative, legal, required] -> do
      checkDhallGreen (Text.unpack legal)
      (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
      let observed = Text.pack (stdoutText <> stderrText)
      assert (exitCode /= ExitSuccess && required `Text.isInfixOf` observed) (Text.unpack negative <> " missed exact Gate-1 locus " <> Text.unpack required)
    _ -> fail "malformed Phase-30 Gate-1 oracle row"
  pure (length rows)

checkGate2 :: IO Int
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

  oracle <- rowsOf "test/oracle/capability_bind/gadt_decode_cases.tsv"
  assert (length oracle == 4) "Phase-30 Gate-2 oracle must contain four negatives"
  assert
    ( Set.fromList [expected | [_name, expected, _negative, _legal] <- oracle]
        == Set.fromList ["UnbuiltProviderArm", "UnboundCapability", "CyclicExtension", "ShadowingExtension"]
    )
    "Phase-30 Gate-2 specific-tag oracle drifted"
  pure (length oracle)

checkDeployment :: [BoundServiceSpec] -> IO Int
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
  let executionRef = "execution-provision:v7"
      volumeRef = PriorVolumeProvisionRef "volume-provision:v7"
      registryRef = PriorRegistryProvisionRef "registry-provision:v7"
  transitioned <- case assembleBoundDeployment (UpdateFrom executionRef) (Just volumeRef) (Just registryRef) oneShape of
    Left problem -> fail ("update BoundDeployment assembly failed: " <> show problem)
    Right value -> pure value
  assert (boundDeploymentTransition transitioned == UpdateFrom executionRef) "execution transition reference was resolved or changed during bind"
  assert (boundPriorVolumeRef transitioned == Just volumeRef) "prior volume reference was resolved or changed during bind"
  assert (boundPriorRegistryRef transitioned == Just registryRef) "prior registry reference was resolved or changed during bind"
  pure 3

checkRegistryIntent :: [BoundServiceSpec] -> IO Int
checkRegistryIntent services = do
  let registryServices = [service | service <- services, capabilityArmOf service == Registry]
      expected = [RegistryStorageProducerIntent RegistryProducer (RegistryStorageIntent "images")]
  assert (length registryServices == 2) "registry service is absent from one of the two shapes"
  assert (all ((== expected) . boundProviderIntents) registryServices) "Registry did not cross ObjectStoreProducerIntent.Registry into RegistryStorageIntent on the bound side"
  pure (length registryServices)

checkExtensionTotality :: IO Int
checkExtensionTotality = do
  let missingRequirement =
        [ ExtensionDescriptor
            InfernixExtension
            (Set.singleton InferenceEngine)
            (Set.singleton ObjectStore)
        ]
      closedGraph =
        [ ExtensionDescriptor
            InfernixExtension
            (Set.singleton InferenceEngine)
            Set.empty
        ]
  assertTag "UnboundCapability" (validateExtensionGraph missingRequirement)
  assertRight (validateExtensionGraph closedGraph) "closed extension requirement graph rejected"
  pure 2

checkControllerKinds :: [BoundServiceSpec] -> IO ()
checkControllerKinds services = do
  let apple = bind (InferenceEngineCapabilityNeed (InferenceEngineNeed "metal-engine" "metal-profile" (AppleMetal "metal-catalog"))) singleBinding
      tags :: Set.Set Text
      tags = Set.fromList (concatMap controllerTags (apple : services))
  assert (tags == Set.fromList ["Deployment", "StatefulSet", "DaemonSet", "Job", "HostProcess"]) "bound execution vocabulary does not exercise all five controller kinds"
 where
  controllerTags service = fmap (controllerTag . executionBody) (Map.elems (boundExecutionUnits (boundServiceExecutions service)))

controllerTag :: ControllerBody -> Text
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

checkLedgerCoverage :: IO Int
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
  assert (observed == expected) "Phase-30 validation-locus ledger does not cover every positive, negative, and mutant"
  assert (length rows == 29) "Phase-30 validation-locus ledger must contain exactly 29 rows"
  pure (length rows)

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
    _ -> fail "malformed Phase-30 arm oracle row"

loadShapeSemanticOracle :: IO [ShapeSemanticRow]
loadShapeSemanticOracle = do
  rows <- rowsOf "test/oracle/capability_bind/bound_shape_semantics.tsv"
  traverse parse rows
 where
  parse row = case row of
    [slug, productName, memberKind, controllerKind, bootstrapText, singleObjectsText, distributedObjectsText, singleExecutionsText, distributedExecutionsText, intentCountText] -> do
      bootstrap <- parseBool "bootstrap" bootstrapText
      singleObjects <- parseInt "single objects" singleObjectsText
      distributedObjects <- parseInt "distributed objects" distributedObjectsText
      singleExecutions <- parseInt "single executions" singleExecutionsText
      distributedExecutions <- parseInt "distributed executions" distributedExecutionsText
      intentCount <- parseInt "intent count" intentCountText
      pure
        ShapeSemanticRow
          { semanticSlug = slug
          , semanticProduct = productName
          , semanticMemberKind = memberKind
          , semanticControllerKind = controllerKind
          , semanticHasBootstrap = bootstrap
          , semanticSingleObjects = singleObjects
          , semanticDistributedObjects = distributedObjects
          , semanticSingleExecutions = singleExecutions
          , semanticDistributedExecutions = distributedExecutions
          , semanticIntentCount = intentCount
          }
    _ -> fail "malformed Phase-30 semantic shape oracle row"

  parseBool field value = case value of
    "true" -> pure True
    "false" -> pure False
    _ -> fail (field <> " is not a boolean: " <> Text.unpack value)

  parseInt field value = case readMaybe (Text.unpack value) of
    Just number | number >= 0 -> pure number
    _ -> fail (field <> " is not a non-negative integer: " <> Text.unpack value)

checkCapabilityBindCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkCapabilityBindCalculusProjection arms shapes negatives properties mutants = do
  expected <- loadMetricOracle "test/oracle/capability_bind/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "capability-bind-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "capability-bind-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "capability-arms" (resources arms) (RecipeId "capability-bind-corpus" 1)
        budget = budgetComponent scope "bound-service-shapes" (resources shapes) (allowance (Bytes (fromIntegral shapes)) (Slots 1) (Bytes (fromIntegral shapes)))
        lift = liftComponent scope "boundary-negatives" (resources negatives) OnHost
        workflow = workflowComponent scope "bind-property" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [arms, shapes, negatives, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "capability bind projection omitted or reordered a calculus"
    assert (actual == expected) ("capability bind calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "capability-bind-calculus: PASS (5 kinds, "
        <> show (arms + shapes + negatives + properties + mutants)
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
