{-# LANGUAGE OverloadedStrings #-}

module RenderGoldenGate
  ( printRenderSemanticOracle
  , runRenderGoldenGate
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
import Amoebius.Capacity.Provision (ProvisionedSpec)
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (K8sObjectIdentity))
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Control.Monad (forM, forM_, unless)
import Data.Aeson (eitherDecode)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import ProvisionFixtures (provisionFixture)
import RenderGoldenProps (renderInvariantFailures, runRenderGoldenProps)
import RenderMutants (renderMutants)

semanticOraclePath :: FilePath
semanticOraclePath = "test/oracle/render_manifest/semantic_projection.tsv"

runRenderGoldenGate :: IO ()
runRenderGoldenGate = do
  oracle <- loadSemanticOracle
  corpus <- fmap concat (mapM (checkFixture oracle) capabilityFixtures)
  let objects = concatMap snd corpus
      variants = Set.fromList (fmap objectKind objects)
      expectedVariants =
        Set.fromList
          [ NamespaceKind
          , DeploymentKind
          , StatefulSetKind
          , DaemonSetKind
          , JobKind
          , ServiceKind
          , ConfigMapKind
          , NetworkPolicyKind
          , ValidatingWebhookConfigurationKind
          ]
      podCount = length [() | object <- objects, WorkloadSpec {} <- [objectSpec object]]
      policyCount = length [() | object <- objects, NetworkPolicySpec {} <- [objectSpec object]]
      deploymentCount = length corpus
      objectCount = length objects
      mutantCount = length renderMutants
  roundTripCount <- checkRoundTrip objects
  assert (Map.size oracle == 18 && deploymentCount == 18) "semantic oracle no longer covers exactly nine arms in two shapes"
  assert (variants == expectedVariants) "render corpus no longer covers the exact nine emitted object variants"
  assert (podCount > 0 && policyCount > 0) "render safety predicates became vacuous"
  checkPureBoundary
  runRenderGoldenProps
  checkRenderCalculusProjection deploymentCount objectCount 3 1 mutantCount
  putStrLn
    ( "render-manifest-invariants: PASS ("
        <> show deploymentCount
        <> " source domains, "
        <> show objectCount
        <> " identity/namespace/API/reconcile projections, "
        <> show roundTripCount
        <> " Aeson round-trips, 33 locus rows)"
    )
  putStrLn
    ( "render-manifest: PASS ("
        <> show deploymentCount
        <> " semantic projections, "
        <> show objectCount
        <> " objects, 9 object variants, 3 non-vacuous safety predicates, "
        <> show mutantCount
        <> " mutants, 1 covered property)"
    )

checkFixture :: Map Text [Text] -> CapabilityFixture -> IO [(ProvisionedSpec, [K8sObject])]
checkFixture oracle fixture = forM [SingleNode, Distributed 3] $ \shape -> do
  sealed <- either (fail . show) pure (provisionFixture fixture shape)
  let objects = renderAll sealed
      identities = fmap objectIdentity objects
      failures = renderInvariantFailures sealed objects
      deployment = deploymentName fixture shape
      actual = semanticFields objects
  assert (identities == Set.toAscList (Set.fromList identities)) "renderAll output is not in deterministic identity order"
  assert (null failures) ("render invariant failures: " <> show failures)
  expected <- maybe (fail ("semantic oracle omitted " <> Text.unpack deployment)) pure (Map.lookup deployment oracle)
  assert (actual == expected) ("semantic projection drifted for " <> Text.unpack deployment <> "\nEXPECTED: " <> show expected <> "\nACTUAL: " <> show actual)
  pure (sealed, objects)

printRenderSemanticOracle :: IO ()
printRenderSemanticOracle = do
  Text.putStrLn "deployment\tobjects\tidentities\tkinds\tactivations\treconcile_modes\tworkloads\tnetwork_policies\tload_balancers\taccelerator_claims"
  forM_ capabilityFixtures $ \fixture -> forM_ [SingleNode, Distributed 3] $ \shape -> do
    sealed <- either (fail . show) pure (provisionFixture fixture shape)
    Text.putStrLn (Text.intercalate "\t" (deploymentName fixture shape : semanticFields (renderAll sealed)))

deploymentName :: CapabilityFixture -> ServiceShape -> Text
deploymentName fixture shape = fixtureSlug fixture <> "_" <> case shape of
  SingleNode -> "singlenode"
  Distributed _ -> "distributed"

semanticFields :: [K8sObject] -> [Text]
semanticFields objects =
  [ Text.pack (show (length objects))
  , Text.intercalate "," [identity | K8sObjectIdentity identity <- fmap objectIdentity objects]
  , bag (Text.pack . show . objectKind) objects
  , bag (Text.pack . show . objectActivation) objects
  , bag (Text.pack . show . objectReconcileMode) objects
  , bag (Text.pack . show) [kind | object <- objects, WorkloadSpec kind _ <- [objectSpec object]]
  , Text.pack (show (length [() | object <- objects, NetworkPolicySpec {} <- [objectSpec object]]))
  , Text.pack (show (length [() | object <- objects, ServiceSpec DeclaredEdgeLoadBalancer <- [objectSpec object]]))
  , Text.pack (show (length [() | object <- objects, WorkloadSpec _ pod <- [objectSpec object], podAcceleratorClaim pod /= Nothing]))
  ]

bag :: (value -> Text) -> [value] -> Text
bag project values =
  Text.intercalate "," [name <> ":" <> Text.pack (show count) | (name, count) <- Map.toAscList counts]
 where
  counts = Map.fromListWith (+) [(project value, 1 :: Int) | value <- values]

loadSemanticOracle :: IO (Map Text [Text])
loadSemanticOracle = do
  contents <- Text.readFile semanticOraclePath
  case Text.lines contents of
    [] -> fail "render semantic oracle is empty"
    header : rows -> do
      assert
        ( Text.splitOn "\t" header
            == [ "deployment", "objects", "identities", "kinds", "activations", "reconcile_modes"
               , "workloads", "network_policies", "load_balancers", "accelerator_claims"
               ]
        )
        "render semantic oracle header drifted"
      parsed <- forM rows $ \row -> case Text.splitOn "\t" row of
        deployment : fields | length fields == 9 -> pure (deployment, fields)
        _ -> fail ("malformed render semantic oracle row: " <> Text.unpack row)
      let oracle = Map.fromList parsed
      assert (Map.size oracle == length parsed) "render semantic oracle contains duplicate deployments"
      pure oracle

checkRoundTrip :: [K8sObject] -> IO Int
checkRoundTrip objects = case (eitherDecode bytes :: Either String [K8sObject]) of
  Left problem -> fail ("typed K8sObject corpus failed Aeson round trip: " <> problem)
  Right decoded
    | decoded /= objects -> fail "typed K8sObject Aeson round trip changed the values"
    | encodeK8sObjects decoded /= bytes -> fail "canonical K8sObject encoding changed after round trip"
    | otherwise -> pure (length decoded)
 where
  bytes = encodeK8sObjects objects

checkPureBoundary :: IO ()
checkPureBoundary = do
  facade <- Text.readFile "src/Amoebius/Manifest.hs"
  renderAllSource <- Text.readFile "src/Amoebius/Manifest/RenderAll.hs"
  renderSource <- Text.readFile "src/Amoebius/Manifest/Render.hs"
  let surface = facade <> renderAllSource <> renderSource
      prohibited = ["unsafePerformIO", "fromJust", "undefined", "error ", "head ", "tail ", "!!", " IO "]
  assert (all (not . (`Text.isInfixOf` surface)) prohibited) "renderAll transitive surface contains an effectful, partial, or unsafe token"
  assert ("  ( renderAll\n" `Text.isInfixOf` facade) "public manifest facade does not export renderAll"
  assert (not ("renderSourcePrivate" `Text.isInfixOf` facade)) "public manifest facade exports a per-source renderer"
  assert (not ("BoundDeployment" `Text.isInfixOf` surface)) "renderer accepts a merely bound deployment"

checkRenderCalculusProjection :: Int -> Int -> Int -> Int -> Int -> IO ()
checkRenderCalculusProjection deployments objects safety properties mutants = do
  expected <- loadMetricOracle "test/oracle/render_manifest/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "render-manifest-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "render-manifest-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "semantic-deployments" (resources deployments) (RecipeId "render-manifest-corpus" 1)
        budget = budgetComponent scope "rendered-objects" (resources objects) (allowance (Bytes (fromIntegral objects)) (Slots 1) (Bytes (fromIntegral objects)))
        lift = liftComponent scope "safety-predicates" (resources safety) OnHost
        workflow = workflowComponent scope "renderer-property" (resources properties) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources mutants) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [deployments, objects, safety, properties, mutants]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "render manifest projection omitted or reordered a calculus"
    assert (actual == expected) ("render manifest calculus projection changed: " <> show actual)
  action
  putStrLn
    ( "render-manifest-calculus: PASS (5 kinds, "
        <> show (deployments + objects + safety + properties + mutants)
        <> " projected units)"
    )

loadMetricOracle :: FilePath -> IO [(Text, Text)]
loadMetricOracle path = do
  contents <- Text.readFile path
  forM (drop 1 (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [metric, value] -> pure (metric, value)
    _ -> fail ("malformed calculus metric row: " <> Text.unpack row)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
