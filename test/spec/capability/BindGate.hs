{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module BindGate
  ( runBindGate
  ) where

import Amoebius.Vocabulary (InferenceFamily (LlamaCpp), ExtensionId, mkExtensionId)
import Amoebius.Extension.Capability (DeclaredCapability (JitBuild, Coordination))
import Amoebius.Extension.Graph (linkRefusalTag, mergeExtensions)
import Amoebius.Extension.Spec (ExtensionSpec, mkExtensionSpec)
import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
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
import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (executionBody)
  , ControllerBody (..)
  , ExecutionTransitionSource (FirstDeployment)
  )
import Amoebius.Vocabulary (quantityText)
import Amoebius.Capacity.Vector (ResourceVector (ResourceVector))
import Amoebius.Capability.Assemble (assembleBoundDeployment)
import Amoebius.Capability.Binding
  ( bind
  , boundDeploymentIsUnprovisioned
  , decodeCapabilityProvider
  , validateBindingCoverage
  )
import Amoebius.Capability.Types
  ( BoundDeployment (boundDeploymentServices)
  , BoundExecutionSet (boundExecutionUnits)
  , BoundServiceSpec (..)
  , CapabilityArm (..)
  , CapabilityBinding (CapabilityBinding)
  , CapabilityNeed (..)
  , CapabilityProvider (CanonicalProvider)
  , InferenceEngineNeed (InferenceEngineNeed)
  , ProviderObject (..)
  , ServiceShape (..)
  , capabilityArm
  , renderCapabilityNeedSurface
  )
import Amoebius.Dsl.Error (DecodeError, decodeErrorTag)
import Amoebius.Vocabulary (EngineRuntime (Cuda))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  )
import BindProps (runBindProps)
import CapabilityBindOracle
  ( NegativeRow (..)
  , OracleRow (..)
  , expectedCalculusProjection
  , expectedNegatives
  , expectedRows
  , mutantSpecs
  )
import Control.Monad (unless)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import ShapeOracle (structurallyDifferentByNodeMultiset, validateBoundExecutionInventory)

runBindGate :: IO ()
runBindGate = do
  assert (length expectedRows == 9) "independent capability oracle did not retain nine arms"
  assert (length expectedNegatives == 4) "independent negative oracle did not retain four pairs"
  assert (length mutantSpecs == 4) "independent mutation oracle did not retain four changed-production subjects"
  services <- mapM checkArm expectedRows
  checkNegatives
  checkDeploymentBoundary services
  propertyCount <- runBindProps
  checkCapabilityBindCalculusProjection propertyCount
  putStrLn
    "capability-bind-spec: PASS (9 arms, 18 shapes, 4 paired negatives, 1 property, 4 changed-production mutants)"

checkArm :: OracleRow -> IO BoundServiceSpec
checkArm oracle = do
  let need = needFor oracle
      single = bind need (CapabilityBinding CanonicalProvider SingleNode)
      distributed = bind need (CapabilityBinding CanonicalProvider (Distributed 3))
      expectedSurface = oracleArm oracle <> ":" <> oracleResource oracle
  assert (Text.pack (show (capabilityArm need)) == oracleArm oracle)
    (Text.unpack (oracleSlug oracle) <> " capability arm drifted")
  assert (renderCapabilityNeedSurface need == expectedSurface)
    (Text.unpack (oracleSlug oracle) <> " app surface projection drifted")
  assert (renderCapabilityNeedSurface (boundCapabilityNeed single) == renderCapabilityNeedSurface (boundCapabilityNeed distributed))
    (Text.unpack (oracleSlug oracle) <> " app surface changed across binding shapes")
  assert (boundCapabilityNeed single == need && boundCapabilityNeed distributed == need)
    (Text.unpack (oracleSlug oracle) <> " bind did not preserve the application need")
  assert (boundProviderProduct single == oracleProduct oracle && boundProviderProduct distributed == oracleProduct oracle)
    (Text.unpack (oracleSlug oracle) <> " provider product projection drifted")
  assert (actualProjection single == expectedProjection oracle True)
    (Text.unpack (oracleSlug oracle) <> " single shape semantic projection drifted")
  assert (structurallyDifferentByNodeMultiset single distributed)
    (Text.unpack (oracleSlug oracle) <> " shape structural projection drifted")
  assert (actualProjection distributed == expectedProjection oracle False)
    (Text.unpack (oracleSlug oracle) <> " distributed shape semantic projection drifted")
  assert (validateBoundExecutionInventory single && validateBoundExecutionInventory distributed)
    (Text.unpack (oracleSlug oracle) <> " execution inventory drifted")
  pure distributed

data Projection = Projection Text Text Bool Int Int Int
  deriving stock (Eq, Show)

expectedProjection :: OracleRow -> Bool -> Projection
expectedProjection oracle single =
  Projection
    (oracleMemberKind oracle)
    (oracleControllerKind oracle)
    (oracleHasBootstrap oracle)
    (if single then oracleSingleObjects oracle else oracleDistributedObjects oracle)
    (if single then oracleSingleExecutions oracle else oracleDistributedExecutions oracle)
    (oracleIntentCount oracle)

actualProjection :: BoundServiceSpec -> Projection
actualProjection service =
  Projection memberKind controllerKind hasBootstrap objectCount executionCount intentCount
 where
  objects = boundProviderGraph service
  units = boundExecutionUnits (boundServiceExecutions service)
  member = case [object | object <- objects, providerObjectRole object == "member"] of
    object : _ -> object
    [] -> error "bound service has no member object"
  memberKind = providerObjectKind member
  controllerKind = case Map.lookup (providerObjectIdentity member) units of
    Nothing -> "missing"
    Just unit -> controllerTag (executionBody unit)
  hasBootstrap = any ((== "bootstrap") . providerObjectRole) objects
  objectCount = length objects
  executionCount = Map.size units
  intentCount = length (boundProviderIntents service)

controllerTag :: ControllerBody -> Text
controllerTag body = case body of
  DeploymentBody {} -> "Deployment"
  StatefulSetBody {} -> "StatefulSet"
  DaemonSetBody {} -> "DaemonSet"
  JobBody {} -> "Job"
  HostProcessBody {} -> "HostProcess"

needFor :: OracleRow -> CapabilityNeed
needFor oracle = case oracleArm oracle of
  "ObjectStore" -> ObjectStoreNeed (oracleResource oracle)
  "SecretStore" -> SecretStoreNeed (oracleResource oracle)
  "MessageBus" -> MessageBusNeed (oracleResource oracle)
  "Sql" -> SqlNeed (oracleResource oracle)
  "Identity" -> IdentityNeed (oracleResource oracle)
  "Observability" -> ObservabilityNeed (oracleResource oracle)
  "Registry" -> RegistryNeed (oracleResource oracle)
  "Edge" -> EdgeNeed (oracleResource oracle)
  "InferenceEngine" ->
    InferenceEngineCapabilityNeed
      (InferenceEngineNeed (oracleResource oracle) "llama-3" Cuda LlamaCpp)
  other -> error ("unknown independent capability arm: " <> Text.unpack other)

checkNegatives :: IO ()
checkNegatives = do
  let byName name = case [row | row <- expectedNegatives, negativeName row == name] of
        [row] -> row
        _ -> error ("missing independent negative row: " <> Text.unpack name)
  checkDecodePair (byName "illegal_unbuilt_provider")
    (decodeCapabilityProvider "Canonical")
    (decodeCapabilityProvider "Alternate")
  checkDecodePair (byName "illegal_unbound_capability")
    (validateBindingCoverage (Set.singleton ObjectStore) (Map.singleton ObjectStore canonicalBinding))
    (validateBindingCoverage (Set.singleton ObjectStore) Map.empty)
  checkPair linkRefusalTag (byName "illegal_cyclic_extension")
    (mergeExtensions legalExtensions)
    (mergeExtensions [extension "alpha" [JitBuild] [Coordination], extension "beta" [Coordination] [JitBuild]])
  checkPair linkRefusalTag (byName "illegal_shadowing_extension")
    (mergeExtensions legalExtensions)
    (mergeExtensions
      [ extension "alpha" [JitBuild] []
      , extension "beta" [JitBuild] []
      ])
 where
  canonicalBinding = CapabilityBinding CanonicalProvider SingleNode
  legalExtensions =
    [ extension "alpha" [JitBuild] []
    , extension "beta" [Coordination] [JitBuild]
    ]
  extension :: Text -> [DeclaredCapability] -> [DeclaredCapability]
    -> ExtensionSpec ExtensionId () DeclaredCapability () () () () () () ()
  extension name provides requires = case mkExtensionId name of
    Nothing -> error "invalid trusted extension fixture identity"
    Just identifier -> either (error . show) id
      (mkExtensionSpec identifier () provides requires () (const []) [] (() :| []) () ())

checkDecodePair :: NegativeRow -> Either DecodeError value -> Either DecodeError value -> IO ()
checkDecodePair = checkPair decodeErrorTag

checkPair :: Show problem => (problem -> Text) -> NegativeRow -> Either problem value -> Either problem value -> IO ()
checkPair tag row positive negative = do
  case positive of
    Left problem -> fail (Text.unpack (negativeName row) <> " paired positive failed: " <> show problem)
    Right _ -> pure ()
  case negative of
    Left problem -> assert (tag problem == negativeTag row)
      (Text.unpack (negativeName row) <> " negative tag drifted at " <> Text.unpack (negativeLocus row))
    Right _ -> fail (Text.unpack (negativeName row) <> " negative unexpectedly decoded")

checkDeploymentBoundary :: [BoundServiceSpec] -> IO ()
checkDeploymentBoundary services = case assembleBoundDeployment FirstDeployment Nothing Nothing services of
  Left problem -> fail ("bound deployment assembly failed: " <> show problem)
  Right deployment -> do
    assert (Map.size (boundDeploymentServices deployment) == 9) "bound deployment service coverage drifted"
    assert (boundDeploymentIsUnprovisioned deployment) "bound deployment crossed provision boundary"

checkCapabilityBindCalculusProjection :: Int -> IO ()
checkCapabilityBindCalculusProjection propertyCount = do
  tenant <- either (fail . show) pure (trustedTenant "capability-bind-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "capability-bind-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ FixtureAuthority.withFixtureScope tenant subject membership $ \scope -> do
    let resources :: Int -> ResourceVector
        resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "capability-arms" (resources 9) (RecipeId "capability-bind-corpus" 1)
        budget = budgetComponent scope "bound-service-shapes" (resources 18) (allowance (Bytes 18) (Slots 1) (Bytes 18))
        lift = liftComponent scope "boundary-negatives" (resources 4) OnHost
        workflow = workflowComponent scope "bind-property" (resources propertyCount) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 4) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [9, 18, 4, propertyCount, 4 :: Int]))
          , ("resource-vector", Text.intercalate "," ([quantityText cpu, quantityText memory, quantityText ephemeral, quantityText pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "capability bind projection omitted or reordered a calculus"
    assert (actual == expectedCalculusProjection) ("capability bind calculus projection changed: " <> show actual)
  action

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
