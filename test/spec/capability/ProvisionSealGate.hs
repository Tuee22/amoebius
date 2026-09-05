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
import Amoebius.Capability.Binding (boundDeploymentIsUnprovisioned)
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
import Control.Monad (forM, forM_, unless)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import ProvisionSealOracle
  ( MutantOracle (..)
  , NegativeOracle (..)
  , expectedActivations
  , expectedCalculusProjection
  , expectedLocusEntries
  , expectedMutants
  , expectedNegatives
  )
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
import ProvisionProps (runProvisionProps)
import RuntimeStorageBindingProps
  ( expectedDesiredInstances
  , runRuntimeStorageBindingProps
  )

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
  checkStructuralBoundary objectStore
  propertyCount <- runProvisionProps objectStore
  runtimePropertyCount <- runRuntimeStorageBindingProps cuda
  locusCount <- checkValidationLocus observability cuda
  let inheritedPositiveCount = length capabilityFixtures * 2
      mutantCount = length expectedMutants
      totalPropertyCount = propertyCount + runtimePropertyCount
  assert (inheritedPositiveCount == 18) "Phase-31 inherited positive count drifted"
  assert (mutantCount == 4) "Phase-31 changed-production mutant count drifted"
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
  Nothing -> fail ("missing Phase-31 fixture: " <> Text.unpack slug)
  Just fixture -> pure fixture

checkFixture :: CapabilityFixture -> IO ()
checkFixture fixture = forM_ [SingleNode, Distributed 3] $ \shape -> do
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
  let cases = provisionNegatives observability cuda
      caseDomain = Set.fromList (fmap negativeName cases)
      oracleDomain = Set.fromList (fmap oracleNegativeName expectedNegatives)
  assert (length cases == 10 && length expectedNegatives == 10 && caseDomain == oracleDomain) "Phase-31 independent negative oracle must cover exactly ten cases"
  forM_ cases $ \negative -> do
    let matchingRows = [row | row <- expectedNegatives, oracleNegativeName row == negativeName negative]
    case matchingRows of
      [row] -> do
        assert (oracleNegativeTag row == negativeExpected negative) "Phase-31 negative expected-tag oracle drifted"
        assert (oraclePositiveTwin row == negativeTwin negative) "Phase-31 legal-twin oracle drifted"
      _ -> fail "Phase-31 negative oracle row is missing or duplicated"
    assertTag (negativeExpected negative) (negativeOutcome negative)
    assertRight (negativeTwinOutcome negative) ("legal twin rejected: " <> Text.unpack (negativeTwin negative))
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
  assert
    (zipWith activationMatches expectedActivations rows == replicate (length rows) True)
    "independent four-stage activation oracle drifted"
  pure (length rows)
 where
  activationMatches (witnessName, activationName) row =
    Text.pack (show (candidateWitnessField row)) == witnessName
      && Text.pack (show (candidateActivationField row)) == activationName
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

checkStructuralBoundary :: CapabilityFixture -> IO ()
checkStructuralBoundary fixture = do
  deployment <- either (fail . show) pure (fixtureDeployment fixture SingleNode)
  assert (boundDeploymentIsUnprovisioned deployment) "BoundDeployment crossed the unprovisioned boundary"

checkValidationLocus :: CapabilityFixture -> CapabilityFixture -> IO Int
checkValidationLocus observability cuda = do
  let observed = Set.fromList expectedLocusEntries
      positives =
        Set.fromList
          [ "legal_" <> fixtureSlug fixture <> "_" <> shape
          | fixture <- capabilityFixtures
          , shape <- ["singlenode", "distributed"]
          ]
      planner = Set.fromList ["planner_preexisting", "planner_creation"]
      negatives = Set.fromList (fmap negativeName (provisionNegatives observability cuda))
      expected = positives <> planner <> negatives <> Set.fromList (fmap oracleMutantName expectedMutants)
  assert (observed == expected) "Phase-31 validation-locus ledger does not cover every positive, planner path, negative, and mutant"
  assert (length expectedLocusEntries == 34) "Phase-31 validation-locus inventory must contain exactly 34 rows"
  pure (length expectedLocusEntries)

checkProvisionCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkProvisionCalculusProjection positives planners negatives properties mutants = do
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
    assert (actual == expectedCalculusProjection) ("provision seal calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "provision-seal-calculus: PASS (5 kinds, "
        <> show (positives + planners + negatives + properties + mutants)
        <> " projected units)"
    )

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
