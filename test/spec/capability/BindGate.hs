{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module BindGate
  ( runBindGate
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
import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (executionBody)
  , ControllerBody (..)
  , ExecutionTransitionSource (FirstDeployment)
  )
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Capability.Binding
  ( assembleBoundDeployment
  , bind
  , boundDeploymentIsUnprovisioned
  , decodeCapabilityProvider
  , validateBindingCoverage
  , validateExtensionGraph
  )
import Amoebius.Capability.Types
  ( BoundDeployment (boundDeploymentServices)
  , BoundExecutionSet (boundExecutionUnits)
  , BoundServiceSpec (..)
  , CapabilityArm (..)
  , CapabilityBinding (CapabilityBinding)
  , CapabilityNeed (..)
  , CapabilityProvider (CanonicalProvider)
  , EngineRuntime (Cuda)
  , ExtensionDescriptor (ExtensionDescriptor)
  , ExtensionName (..)
  , InferenceEngineNeed (InferenceEngineNeed)
  , ProviderObject (..)
  , ServiceShape (..)
  , capabilityArm
  , renderAppCapabilityNeedDhallType
  , renderCapabilityArmDhallType
  , renderCapabilityNeedSurface
  , renderEngineRuntimeDhallType
  )
import Amoebius.Dsl.Error (DecodeError, decodeErrorTag)
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
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
import Control.Exception (SomeException, catch)
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Dhall qualified
import ShapeOracle (structurallyDifferentByNodeMultiset, validateBoundExecutionInventory)

runBindGate :: IO ()
runBindGate = do
  assert (length expectedRows == 9) "independent capability oracle did not retain nine arms"
  assert (length expectedNegatives == 7) "independent negative oracle did not retain seven pairs"
  assert (length mutantSpecs == 4) "independent mutation oracle did not retain four changed-production subjects"
  services <- mapM checkArm expectedRows
  checkNegatives
  checkDeploymentBoundary services
  propertyCount <- runBindProps
  checkCapabilityBindCalculusProjection propertyCount
  putStrLn
    "capability-bind-spec: PASS (9 arms, 18 shapes, 7 paired negatives, 1 property, 4 changed-production mutants)"

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
      (InferenceEngineNeed (oracleResource oracle) "llama-3" (Cuda "cuda-llama-3"))
  other -> error ("unknown independent capability arm: " <> Text.unpack other)

checkNegatives :: IO ()
checkNegatives = do
  let byName name = case [row | row <- expectedNegatives, negativeName row == name] of
        [row] -> row
        _ -> error ("missing independent negative row: " <> Text.unpack name)
  checkDhallPair (byName "illegal_product_in_app")
    ("let Capability = " <> renderCapabilityArmDhallType <> " in Capability.ObjectStore")
    ("let Capability = " <> renderCapabilityArmDhallType <> " in Capability.MinIO")
  checkDhallPair (byName "illegal_engine_by_url")
    ("let EngineRuntime = " <> renderEngineRuntimeDhallType <> " in EngineRuntime.Cuda \"catalog\"")
    ("let EngineRuntime = " <> renderEngineRuntimeDhallType <> " in EngineRuntime.Url \"https://invalid\"")
  checkDhallPair (byName "illegal_shape_in_app") (appRecord False) (appRecord True)
  checkDecodePair (byName "illegal_unbuilt_provider")
    (decodeCapabilityProvider "Canonical")
    (decodeCapabilityProvider "Alternate")
  checkDecodePair (byName "illegal_unbound_capability")
    (validateBindingCoverage (Set.singleton ObjectStore) (Map.singleton ObjectStore canonicalBinding))
    (validateBindingCoverage (Set.singleton ObjectStore) Map.empty)
  checkDecodePair (byName "illegal_cyclic_extension")
    (validateExtensionGraph legalExtensions)
    (validateExtensionGraph [ExtensionDescriptor InfernixExtension (Set.singleton ObjectStore) (Set.singleton ObjectStore)])
  checkDecodePair (byName "illegal_shadowing_extension")
    (validateExtensionGraph legalExtensions)
    (validateExtensionGraph
      [ ExtensionDescriptor InfernixExtension (Set.singleton ObjectStore) Set.empty
      , ExtensionDescriptor JitMLExtension (Set.singleton ObjectStore) Set.empty
      ])
 where
  canonicalBinding = CapabilityBinding CanonicalProvider SingleNode
  legalExtensions =
    [ ExtensionDescriptor InfernixExtension (Set.singleton InferenceEngine) Set.empty
    , ExtensionDescriptor JitMLExtension (Set.singleton ObjectStore) Set.empty
    ]
  appRecord includeBinding =
    "let Capability = " <> renderCapabilityArmDhallType
      <> " in ({ capability = Capability.ObjectStore, name = \"assets\""
      <> (if includeBinding then ", shape = \"Distributed\", provider = \"Canonical\"" else "")
      <> " } : " <> renderAppCapabilityNeedDhallType <> ")"

checkDhallPair :: NegativeRow -> Text -> Text -> IO ()
checkDhallPair row positive negative = do
  positiveAccepted <- dhallTypechecks positive
  negativeAccepted <- dhallTypechecks negative
  assert positiveAccepted (Text.unpack (negativeName row) <> " paired positive failed at " <> Text.unpack (negativeLocus row))
  assert (not negativeAccepted && negativeTag row == "DhallTypeError")
    (Text.unpack (negativeName row) <> " did not fail Dhall typechecking at " <> Text.unpack (negativeLocus row))

dhallTypechecks :: Text -> IO Bool
dhallTypechecks source =
  (Dhall.inputExpr source >> pure True)
    `catch` \(_problem :: SomeException) -> pure False

checkDecodePair :: NegativeRow -> Either DecodeError value -> Either DecodeError value -> IO ()
checkDecodePair row positive negative = do
  case positive of
    Left problem -> fail (Text.unpack (negativeName row) <> " paired positive failed: " <> show problem)
    Right _ -> pure ()
  case negative of
    Left problem -> assert (decodeErrorTag problem == negativeTag row)
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
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources :: Int -> ResourceVector
        resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "capability-arms" (resources 9) (RecipeId "capability-bind-corpus" 1)
        budget = budgetComponent scope "bound-service-shapes" (resources 18) (allowance (Bytes 18) (Slots 1) (Bytes 18))
        lift = liftComponent scope "boundary-negatives" (resources 7) OnHost
        workflow = workflowComponent scope "bind-property" (resources propertyCount) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 4) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [9, 18, 7, propertyCount, 4 :: Int]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "capability bind projection omitted or reordered a calculus"
    assert (actual == expectedCalculusProjection) ("capability bind calculus projection changed: " <> show actual)
  action

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
