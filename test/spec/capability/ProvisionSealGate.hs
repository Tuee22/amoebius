{-# LANGUAGE OverloadedStrings #-}

module ProvisionSealGate
  ( runProvisionSealGate
  ) where

import Amoebius.Capacity.Execution
  ( ProvisionedExecutionEpochs (..)
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
import Amoebius.Capacity.Provision
  ( ClusterBudget (ClusterBudget)
  , InfrastructureActionLedger (InfrastructureActionLedger)
  , InfrastructureDemand (..)
  , InfrastructurePlan (..)
  , InfrastructurePlanningResult (..)
  , InfrastructureState (..)
  , ObservedReadback (ObservedReadback)
  , PriorProvisionCatalog
  , ProvisionError (..)
  , ProvisionTargetSupply (..)
  , ProvisionedProviderActionBatch (..)
  , ProvisionedServicePart (..)
  , TargetSupply (TargetSupply)
  , deriveInfrastructureDemand
  , emptyInfrastructureActionLedger
  , emptyPriorProvisionCatalog
  , enactInfrastructurePlan
  , infrastructurePlanDemand
  , materializationIsReceiptBound
  , mkProvisionContext
  , observationFromPlanningResult
  , planInfrastructure
  , provision
  , provisionErrorTag
  , provisionedExecution
  , provisionedRenderSources
  , provisionedRuntimeStorage
  , provisionedServiceParts
  , validateInfrastructurePlan
  )
import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedDeploymentParts (ProvisionedDeploymentParts)
  , ProvisionedPartWitness (..)
  , ReconcileMode (ServerSideApply)
  , RenderActivation (..)
  , RenderSourceCandidate (RenderSourceCandidate)
  , RenderSourceError (..)
  , RenderSourceOwner (..)
  , provisionRenderSources
  , provisionedRenderSourceMap
  , renderSourceActivation
  , renderSourceIdentity
  , renderSourceOwner
  , renderSourceWitness
  )
import Amoebius.Capacity.RuntimeStorage
  ( ProvisionedNodeRuntimeStorageAccounting (..)
  )
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundServiceSpec (..)
  , ProviderObject (..)
  , ServiceShape (..)
  )
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
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ProvisionFixtures
  ( ProvisionNegative (..)
  , baselineCapacity
  , baselinePolicy
  , contextFor
  , fixedTopology
  , fixtureDeployment
  , provisionFixture
  , provisionNegatives
  )
import ProvisionMutants (provisionMutants)
import ProvisionProps (runProvisionProps)
import RuntimeStorageBindingProps
  ( expectedDesiredInstances
  , runRuntimeStorageBindingProps
  )
import System.IO.Unsafe (unsafePerformIO)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (ExitSuccess))
import System.Process (proc, readCreateProcessWithExitCode)

data PlannerCounts = PlannerCounts
  { plannerCreationBatches :: Int
  , plannerPlanReplays :: Int
  , plannerActionReplays :: Int
  , plannerReceiptClassifications :: Int
  , plannerPromisedIdentityRejections :: Int
  }

runProvisionSealGate :: IO ()
runProvisionSealGate = do
  observability <- fixtureNamed "observability"
  cuda <- fixtureNamed "inferenceengine"
  objectStore <- fixtureNamed "objectstore"
  forM_ capabilityFixtures checkFixture
  plannerCounts <- checkInfrastructurePlanner objectStore
  negativeCount <- checkNegativeCorpus observability cuda
  activationCount <- checkRenderSourceSeal
  checkStructuralBoundary
  propertyCount <- runProvisionProps objectStore
  runtimePropertyCount <- runRuntimeStorageBindingProps cuda
  locusCount <- checkValidationLocus observability cuda
  let inheritedPositiveCount = length capabilityFixtures * 2
      mutantCount = length provisionMutants
      totalPropertyCount = propertyCount + runtimePropertyCount
  assert (inheritedPositiveCount == 18) "Phase-32 inherited positive count drifted"
  assert (mutantCount == 10) "Phase-32 mutant count drifted"
  checkProvisionCalculusProjection inheritedPositiveCount 2 negativeCount totalPropertyCount mutantCount
  putStrLn
    ( "provision-seal-invariants: PASS ("
        <> show (plannerCreationBatches plannerCounts)
        <> " creation batch, "
        <> show (plannerPlanReplays plannerCounts)
        <> " plan replay, "
        <> show (plannerActionReplays plannerCounts)
        <> " action replay, "
        <> show (plannerReceiptClassifications plannerCounts)
        <> " receipt classifications, "
        <> show (plannerPromisedIdentityRejections plannerCounts)
        <> " promised-identity rejections, "
        <> show locusCount
        <> " locus rows)"
    )
  putStrLn
    ( "provision-seal-spec: PASS ("
        <> show inheritedPositiveCount
        <> " inherited positives, 2 planner paths, "
        <> show negativeCount
        <> " specific negatives, "
        <> show activationCount
        <> " activation stages, "
        <> show mutantCount
        <> " mutants, "
        <> show totalPropertyCount
        <> " covered properties)"
    )

fixtureNamed :: Text -> IO CapabilityFixture
fixtureNamed slug = case find ((== slug) . fixtureSlug) capabilityFixtures of
  Nothing -> fail ("missing Phase-32 fixture: " <> Text.unpack slug)
  Just fixture -> pure fixture

checkFixture :: CapabilityFixture -> IO ()
checkFixture fixture = forM_ [SingleNode, Distributed 3] $ \shape -> do
  checkDhallGreen (fixturePath fixture shape)
  deployment <- either (fail . show) pure (fixtureDeployment fixture shape)
  sealed <- either (fail . show) pure (provisionFixture fixture shape)
  let desired = provisionedDesiredSteady (provisionedExecution sealed)
      runtimeRows = sum (fmap (Map.size . provisionedRuntimeRows) (provisionedRuntimeStorage sealed))
      services = boundDeploymentServices deployment
      serviceParts = provisionedServiceParts sealed
      providerObjects = sum (fmap (length . boundProviderGraph) (Map.elems services))
      sources = provisionedRenderSourceMap (provisionedRenderSources sealed)
      stages = Set.fromList (fmap renderSourceActivation (Map.elems sources))
  assert (Map.size desired == expectedDesiredInstances deployment) "desired execution expansion differs from the controller oracle"
  assert (runtimeRows == Map.size desired) "runtime metadata is not bound one-to-one to desired execution instances"
  assert (Map.keysSet serviceParts == Map.keysSet services) "provisioned service-part domain differs from the bound service domain"
  assert (Map.size sources == providerObjects + 4) "render-source domain is not exactly provider objects plus four deployment-global objects"
  assert (all (uncurry sourceKeyMatches) (Map.toList sources)) "render-source map key differs from embedded Kubernetes identity"
  assert (all sourceOwnerMatches (Map.elems sources)) "render-source owner differs from the independent witness oracle"
  assert (stages == Set.fromList [minBound .. maxBound]) "render-source activation stages are incomplete"
  forM_ (Map.toList services) $ \(name, service) -> case Map.lookup name serviceParts of
    Nothing -> fail "missing provisioned service part"
    Just part -> do
      assert (provisionedServiceName part == name) "provisioned service name changed"
      assert (provisionedServiceObjects part == boundProviderGraph service) "provider object graph changed at the provision seal"
      assert (provisionedServiceIntents part == boundProviderIntents service) "provider intent graph changed at the provision seal"

sourceKeyMatches key source = key == renderSourceIdentity source

sourceOwnerMatches source = renderSourceOwner source == expectedOwner (renderSourceWitness source)

expectedOwner :: ProvisionedPartWitness -> RenderSourceOwner
expectedOwner witness = case witness of
  NamespacePart -> DeploymentGlobalOwner
  CapacitySchedulerPart -> DeploymentGlobalOwner
  BootstrapAddonCutoverPart -> DeploymentGlobalOwner
  ManagedCapacityAdmissionPart -> DeploymentGlobalOwner
  ServiceConfigurationPart service -> CapabilityServiceOwner service
  ServiceEndpointPart service -> CapabilityServiceOwner service
  ServiceWorkloadPart service -> CapabilityServiceOwner service
  ServicePolicyPart service -> CapabilityServiceOwner service

checkInfrastructurePlanner :: CapabilityFixture -> IO PlannerCounts
checkInfrastructurePlanner fixture = do
  deployment <- either (fail . show) pure (fixtureDeployment fixture SingleNode)
  topology <- either (fail . show) pure (fixedTopology baselineCapacity)
  let demand = deriveInfrastructureDemand deployment
      identities = infrastructureRequiredIdentities demand
      present = TargetSupply InfrastructureAlreadyPresent baselineCapacity identities 11
      forest = ClusterBudget InfrastructureAlreadyPresent baselineCapacity identities 11
      create = TargetSupply InfrastructureCreationRequired baselineCapacity Set.empty 11
  preexistingObservations <- forM [StandaloneRoot present, ForestMember forest] $ \supply -> do
    planned <- either (fail . show) pure (planInfrastructure supply deployment)
    case planned of
      NoInfrastructureRequired observed -> do
        context <- either (fail . show) pure (mkProvisionContext "phase31" 2 baselinePolicy emptyPriorProvisionCatalog observed)
        assertRight (provision context topology deployment) "pre-existing infrastructure did not provision"
        pure observed
      InfrastructureRequired _ -> fail "pre-existing infrastructure unexpectedly produced provider actions"
  planned <- either (fail . show) pure (planInfrastructure (StandaloneRoot create) deployment)
  plan <- case planned of
    NoInfrastructureRequired _ -> fail "creation-required supply skipped infrastructure planning"
    InfrastructureRequired value -> pure value
  assert (infrastructurePlanDemand plan == demand) "infrastructure plan changed derived demand"
  assert (Map.keysSet (providerActions (infrastructurePlanBatch plan)) == identities) "provider action domain differs from demanded identities"
  validated <- either (fail . show) pure (validateInfrastructurePlan emptyInfrastructureActionLedger 11 plan)
  let readback = ObservedReadback identities baselineCapacity 11
  (ledger, observed) <- either (fail . show) pure (enactInfrastructurePlan emptyInfrastructureActionLedger validated readback)
  context <- either (fail . show) pure (mkProvisionContext "phase31" 2 baselinePolicy emptyPriorProvisionCatalog observed)
  assertRight (provision context topology deployment) "observed creation readback did not provision"
  assertTag "InfrastructurePlanReplay" (validateInfrastructurePlan ledger 11 plan)
  let actionOnlyLedger = InfrastructureActionLedger Set.empty (Set.singleton (providerActionToken (infrastructurePlanBatch plan)))
  assertTag "InfrastructureActionReplay" (validateInfrastructurePlan actionOnlyLedger 11 plan)
  assertTag "InfrastructureSnapshotMismatch" (enactInfrastructurePlan emptyInfrastructureActionLedger validated (ObservedReadback identities baselineCapacity 12))
  case Set.lookupMin identities of
    Nothing -> fail "planner fixture has an empty execution identity domain"
    Just one -> assertTag "PromisedIdentityNotObserved" (enactInfrastructurePlan emptyInfrastructureActionLedger validated (ObservedReadback (Set.delete one identities) baselineCapacity 11))
  assertTag "PromisedIdentityNotObserved" (observationFromPlanningResult planned)
  assert (all (not . materializationIsReceiptBound) preexistingObservations) "pre-existing observations unexpectedly carry provider receipts"
  assert (materializationIsReceiptBound observed) "enacted creation readback is not receipt-bound"
  pure
    PlannerCounts
      { plannerCreationBatches = 1
      , plannerPlanReplays = 1
      , plannerActionReplays = 1
      , plannerReceiptClassifications = length preexistingObservations + 1
      , plannerPromisedIdentityRejections = 2
      }

checkNegativeCorpus :: CapabilityFixture -> CapabilityFixture -> IO Int
checkNegativeCorpus observability cuda = do
  oracle <- rowsOf "test/oracle/provision_seal/provision_cases.tsv"
  let cases = provisionNegatives observability cuda
      caseDomain = Set.fromList (fmap negativeName cases)
      oracleDomain = Set.fromList [name | [name, _expected, _twin] <- oracle]
  assert (length cases == 10 && length oracle == 10 && caseDomain == oracleDomain) "Phase-32 negative oracle must cover exactly ten cases"
  forM_ cases $ \negative -> do
    let matchingRows = [row | row@[name, _expected, _twin] <- oracle, name == negativeName negative]
    case matchingRows of
      [[_name, expected, twin]] -> do
        assert (expected == negativeExpected negative) "Phase-32 negative expected-tag oracle drifted"
        assert (twin == negativeTwin negative) "Phase-32 legal-twin oracle drifted"
      _ -> fail "Phase-32 negative oracle row is missing or duplicated"
    assertTag (negativeExpected negative) (negativeOutcome negative)
    assertRight (negativeTwinOutcome negative) ("legal twin rejected: " <> Text.unpack (negativeTwin negative))
    checkDhallGreen ("dhall/examples/" <> Text.unpack (negativeName negative) <> ".dhall")
    checkDhallGreen ("dhall/examples/" <> Text.unpack (negativeTwin negative) <> ".dhall")
  pure (length cases)

checkRenderSourceSeal :: IO Int
checkRenderSourceSeal = do
  let rows = globalCandidates
      candidates = fmap toCandidate rows
      domain = Set.fromList (fmap candidateKey candidates)
      base = ProvisionedDeploymentParts domain candidates
      first = headCandidate rows
      remaining = drop 1 candidates
      badKey = toCandidate first {candidateKeyField = K8sObjectIdentity "different-key"}
      badOwner = toCandidate first {candidateOwnerField = CapabilityServiceOwner "wrong"}
      badStage = toCandidate first {candidateActivationField = AfterManagedCapacityReady}
      withoutManaged = fmap toCandidate (take 3 rows)
  assertRight (provisionRenderSources base) "valid render-source set rejected"
  assertRenderError isDuplicate (provisionRenderSources (ProvisionedDeploymentParts domain (toCandidate first : candidates)))
  assertRenderError isMissingDomain (provisionRenderSources (ProvisionedDeploymentParts domain remaining))
  assertRenderError isKeyMismatch (provisionRenderSources (ProvisionedDeploymentParts domain (badKey : remaining)))
  assertRenderError isOwnerMismatch (provisionRenderSources (ProvisionedDeploymentParts domain (badOwner : remaining)))
  assertRenderError isActivationMismatch (provisionRenderSources (ProvisionedDeploymentParts domain (badStage : remaining)))
  assertRenderError isMissingStage (provisionRenderSources (ProvisionedDeploymentParts (Set.fromList (fmap candidateKey withoutManaged)) withoutManaged))
  pure (length rows)
 where
  isDuplicate problem = case problem of DuplicateRenderSource {} -> True; _ -> False
  isMissingDomain problem = case problem of MissingRenderSourceDomain {} -> True; _ -> False
  isKeyMismatch problem = case problem of RenderSourceKeyMismatch {} -> True; _ -> False
  isOwnerMismatch problem = case problem of RenderSourceOwnerMismatch {} -> True; _ -> False
  isActivationMismatch problem = case problem of RenderSourceActivationMismatch {} -> True; _ -> False
  isMissingStage problem = case problem of MissingActivationStage {} -> True; _ -> False

-- Separate test record keeps the key, owner, and activation mutations explicit.
data CandidateFields = CandidateFields
  { candidateKeyField :: K8sObjectIdentity
  , candidateIdentityField :: K8sObjectIdentity
  , candidateOwnerField :: RenderSourceOwner
  , candidateActivationField :: RenderActivation
  , candidateWitnessField :: ProvisionedPartWitness
  }

globalCandidates :: [CandidateFields]
globalCandidates =
  [ fields "global/namespace" DeploymentGlobalOwner Immediate NamespacePart
  , fields "global/capacity-scheduler" DeploymentGlobalOwner BootstrapSchedulerStage CapacitySchedulerPart
  , fields "global/bootstrap-addon-cutover" DeploymentGlobalOwner AfterBootstrapAddonCutover BootstrapAddonCutoverPart
  , fields "global/managed-capacity-admission" DeploymentGlobalOwner AfterManagedCapacityReady ManagedCapacityAdmissionPart
  ]

fields identity owner activation witness =
  CandidateFields (K8sObjectIdentity identity) (K8sObjectIdentity identity) owner activation witness

candidateKey :: RenderSourceCandidate -> K8sObjectIdentity
candidateKey (RenderSourceCandidate key _ _ _ _ _ _) = key

toCandidate :: CandidateFields -> RenderSourceCandidate
toCandidate row =
  RenderSourceCandidate
    (candidateKeyField row)
    (candidateIdentityField row)
    (candidateOwnerField row)
    Map.empty
    ServerSideApply
    (candidateActivationField row)
    (candidateWitnessField row)

headCandidate :: [CandidateFields] -> CandidateFields
headCandidate candidates = case candidates of
  [] -> fields "unreachable" DeploymentGlobalOwner Immediate NamespacePart
  first : _ -> first

checkStructuralBoundary :: IO ()
checkStructuralBoundary = do
  types <- Text.readFile "src/Amoebius/Capability/Types.hs"
  provisionSource <- Text.readFile "src/Amoebius/Capacity/Provision.hs"
  renderSource <- Text.readFile "src/Amoebius/Capacity/RenderSource.hs"
  let boundDeclaration = fst (Text.breakOn "data ExtensionName" (snd (Text.breakOn "data BoundDeployment" types)))
      exportHeader = fst (Text.breakOn ") where" provisionSource)
  assert (not ("Provisioned" `Text.isInfixOf` boundDeclaration)) "BoundDeployment contains a provisioned value"
  assert ("  , ProvisionedSpec\n" `Text.isInfixOf` exportHeader) "ProvisionedSpec opaque export is absent"
  assert (not ("ProvisionedSpec (.." `Text.isInfixOf` exportHeader)) "ProvisionedSpec constructor is exported"
  assert (Text.count "newtype ProvisionedRenderSourceSet" renderSource == 1) "render-source ownership is not centralized in one map type"

checkValidationLocus :: CapabilityFixture -> CapabilityFixture -> IO Int
checkValidationLocus observability cuda = do
  rows <- rowsOf "test/oracle/provision_seal/validation_locus.tsv"
  let observed = Set.fromList [entry | [entry, _className, _locus, _status] <- rows]
      positives =
        Set.fromList
          [ "legal_" <> fixtureSlug fixture <> "_" <> shape
          | fixture <- capabilityFixtures
          , shape <- ["singlenode", "distributed"]
          ]
      planner = Set.fromList ["planner_preexisting", "planner_creation"]
      negatives = Set.fromList (fmap negativeName (provisionNegatives observability cuda))
      expected = positives <> planner <> negatives <> Set.fromList provisionMutants
  assert (observed == expected) "Phase-32 validation-locus ledger does not cover every positive, planner path, negative, and mutant"
  assert (length rows == 40) "Phase-32 validation-locus ledger must contain exactly 40 rows"
  pure (length rows)

checkProvisionCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkProvisionCalculusProjection positives planners negatives properties mutants = do
  expected <- loadMetricOracle "test/oracle/provision_seal/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "provision-seal-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "provision-seal-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "inherited-positives" (resources positives) (RecipeId "provision-seal-corpus" 1)
        budget = budgetComponent scope "planner-paths" (resources planners) (allowance (Bytes (fromIntegral planners)) (Slots 1) (Bytes (fromIntegral planners)))
        lift = liftComponent scope "specific-negatives" (resources negatives) OnHost
        workflow = workflowComponent scope "provision-properties" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [positives, planners, negatives, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "provision seal projection omitted or reordered a calculus"
    assert (actual == expected) ("provision seal calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "provision-seal-calculus: PASS (5 kinds, "
        <> show (positives + planners + negatives + properties + mutants)
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

assertRenderError predicate outcome = case outcome of
  Left problem -> assert (predicate problem) ("unexpected render-source error: " <> show problem)
  Right _ -> fail "illegal render-source inventory was accepted"

assertTag :: Text -> Either ProvisionError value -> IO ()
assertTag expected outcome = case outcome of
  Left problem -> assert (provisionErrorTag problem == expected) ("expected " <> Text.unpack expected <> ", observed " <> Text.unpack (provisionErrorTag problem))
  Right _ -> fail ("expected provision failure: " <> Text.unpack expected)

assertRight :: Either problem value -> String -> IO ()
assertRight outcome message = case outcome of
  Left _ -> fail message
  Right _ -> pure ()

assert :: Bool -> String -> IO ()
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
