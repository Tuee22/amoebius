{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Bind the admitted extension declarations to actual application needs.
-- These are pure plans. Provider execution and live monitoring remain with
-- their later owners; the returned steps are the contributed plans consumed
-- by the same fake-apply path as every core object.
module Amoebius.Dsl.Extensions
  ( ExtensionRefusal (..), extensionRefusalTag
  , AttestedDeployment, attestDeployment, scopeAuthorities, deploymentScope
  , extensionFacts, scopeFacts, workflowFacts, contributedSteps
  , conformanceFiles
  , admittedSources
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..), RenderSourceOwner (..), RenderActivation (Immediate), ReconcileMode (ServerSideApply))
import Amoebius.Capacity.Vector (ResourceVector, zeroResources, addResources)
import Amoebius.Capacity.Execution (BoundExecutionUnit (executionResource))
import Amoebius.Capacity.Types (envelopeRequests)
import Amoebius.Capability.Types (BoundApp (boundAppName), BoundServiceSpec (boundCapabilityNeed, boundServiceExecutions), BoundExecutionSet (..), CapabilityNeed (..), InferenceEngineNeed (inferenceRuntime, inferenceFamily), boundDeploymentServices)
import Amoebius.Dsl.Dump (commas, row, rows)
import Amoebius.Dsl.Lower (Lowered (..))
import Amoebius.Extension.AstCheck (CheckedExtensionSource, checkedSourceFiles)
import Amoebius.Extension.SourceClosure (contributionRoot)
import Amoebius.Extension.Calculi (CalculusRefusal, instantiateDeclaration, declarationRows)
import Amoebius.Extension.Conformance.Model qualified as Conformance
import Amoebius.Extension.Capability (DeclaredCapability (..), declaredCapabilityName)
import Amoebius.Extension.Config
import Amoebius.Extension.Declaration (declarationDigest, extensionName)
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.Monitoring qualified as Monitoring
import Amoebius.Extension.Spec
import Amoebius.Extension.Surface qualified as Surface
import Amoebius.Kernel.Interpret (sha256Hex)
import Amoebius.Kernel.Step (Step, StepRefusal, chain, stepFrame, stepLabel, validateChain)
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.Render (ScopeAuthorities, stampScope)
import Amoebius.Scope.Attested
import Amoebius.Vocabulary (CapabilityArm (ObjectStore, Registry, InferenceEngine), ExtensionId, extensionIdText, engineRuntimeName, inferenceFamilyName)
import Data.Bifunctor (first)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (sortOn)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding

data ExtensionRefusal
  = ExtensionScopeRefused ScopeError
  | ExtensionCalculusRefused CalculusRefusal
  | ExtensionSurfaceRefused Surface.SurfaceRefusal
  | ExtensionMonitoringRefused Monitoring.MonitoringRefusal
  | ExtensionConformanceRefused Conformance.ModelRefusal
  | ExtensionStepsRefused StepRefusal
  | ExtensionBindingRequired Text
  | ExtensionDependencyOutputMissing Text
  deriving (Eq, Show)

extensionRefusalTag :: ExtensionRefusal -> Text
extensionRefusalTag problem = case problem of
  ExtensionScopeRefused _ -> "UnattestedScope"
  ExtensionCalculusRefused _ -> "ExtensionDeclarationRefused"
  ExtensionSurfaceRefused refusal -> Surface.surfaceRefusalTag refusal
  ExtensionMonitoringRefused refusal -> Monitoring.monitoringRefusalTag refusal
  ExtensionConformanceRefused refusal -> Conformance.modelRefusalTag refusal
  ExtensionStepsRefused _ -> "ExtensionChainRefused"
  ExtensionBindingRequired _ -> "ExtensionBindingRequired"
  ExtensionDependencyOutputMissing _ -> "ExtensionDependencyOutputMissing"

type Proof = Linked.BindingProof CheckedExtensionSource

-- Only this binder can construct a producer output, after instantiating its
-- admitted declaration. Consumers resolve it through declared graph edges.
data Produced = Produced !ExtensionId !Text ![(Text, Text)]

data AttestedDeployment = AttestedDeployment
  { scopeAuthorities :: ScopeAuthorities
  , deploymentScope :: ScopeStamp
  , extensionFacts :: Text
  , scopeFacts :: Text
  , workflowFacts :: Text
  , conformanceFiles :: [(FilePath, ByteString.ByteString)]
  , contributedSteps :: [K8sObject] -> Either ExtensionRefusal [Step]
  }

withProof :: Proof -> (forall scope. RequestScope scope -> Either ExtensionRefusal value) -> Either ExtensionRefusal value
withProof proof action = first ExtensionScopeRefused (attest (bindingAttestation proof) action) >>= id

attestDeployment :: Lowered -> Either ExtensionRefusal AttestedDeployment
attestDeployment lowered = do
  primary <- maybe (Left (ExtensionBindingRequired "application has no needs")) (Right . snd) (Map.lookupMin proofs)
  stamps <- traverse (\proof -> withProof proof (Right . scopeStamp)) proofs
  primaryStamp <- withProof primary (Right . scopeStamp)
  if null active || not (null extensionProofs) then Right () else Left (ExtensionBindingRequired "inference")
  qualified <- traverse (\proof -> do
    resources <- representedResources proof
    withProof proof $ \scope -> foldExtensions scope resources [] [] active) extensionProofs
  let observations = concat [values | (_, values, _) <- qualified]
      generated = concat [files | (_, _, files) <- qualified]
      authorities = Map.fromList
        ([(DeploymentGlobalOwner, primaryStamp), (AppOwner (boundAppName (loweredApp lowered)), primaryStamp)] <>
         [(CapabilityServiceOwner name, stamp) | (name, stamp) <- Map.toList stamps])
      identities = concat
        [[row ("scope." <> need <> "." <> field) value | (field, value) <-
          [("issuer", stampIssuer stamp), ("application", stampApplication stamp),
           ("need", stampNeed stamp), ("scope-label", stampLabel stamp)]]
         | (need, stamp) <- Map.toList stamps]
  Right AttestedDeployment
    { scopeAuthorities = authorities, deploymentScope = primaryStamp
    , scopeFacts = rows identities
    , extensionFacts = rows
        ([row "extensions.active" (commas (map (extensionIdText . extId . fst) active))] <>
         [row key value | (key, value) <- observations])
    , workflowFacts = rows
        ([row ("workflow." <> Linked.bindingNeed proof <> "." <> field) value
          | proof <- if null active then [primary] else extensionProofs,
            (field, value) <- [("application", Linked.bindingApplication proof),
              ("need", Linked.bindingNeed proof), ("issuer", Linked.bindingIssuer proof)]] <>
         [row key value | (key, value) <- observations, ".declaration." `Text.isInfixOf` key])
    , conformanceFiles = generated
    , contributedSteps = assembleSteps
    }
 where
  proofs = loweredProofs lowered
  active = loweredExtensions lowered
  extensionProofs = if null active then [] else
    [proof | proof <- Map.elems proofs, Linked.bindingCapability proof == ServiceCapability InferenceEngine]
  serviceFor proof = maybe (Left (ExtensionBindingRequired (Linked.bindingNeed proof))) Right
    (Map.lookup (Linked.bindingNeed proof) (boundDeploymentServices (loweredDeployment lowered)))
  runtimeFor proof = do
    service <- serviceFor proof
    case boundCapabilityNeed service of
      InferenceEngineCapabilityNeed inference -> Right (inferenceRuntime inference)
      _ -> Left (ExtensionBindingRequired (Linked.bindingNeed proof))
  representedResources proof = do
    service <- serviceFor proof
    let BoundExecutionSet units = boundServiceExecutions service
    Right (foldl addResources zeroResources [envelopeRequests (executionResource unit) | unit <- Map.elems units])
  backing parameters = do
    reference <- configurationReference parameters
    Map.lookup reference proofs
  coreReference capability = case [Linked.bindingNeed proof | proof <- Map.elems proofs,
                                  Linked.bindingCapability proof == ServiceCapability capability] of
    name : _ -> Right name
    [] -> Left (ExtensionBindingRequired (declaredCapabilityName (ServiceCapability capability)))

  -- A single producer value is threaded to both consumers. Reference identity
  -- includes its actual declaration, parameters and attested scope, rather
  -- than being an independently invented name in each consumer.
  foldExtensions :: RequestScope scope -> ResourceVector -> [Produced] -> [(Text, Text)]
    -> [(Linked.ConcreteSpec, ExtensionParameters)]
    -> Either ExtensionRefusal ([Produced], [(Text, Text)], [(FilePath, ByteString.ByteString)])
  foldExtensions scope resources initialProduced initialObservations initialRemaining = do
    declarations <- traverse (\(specification, parameters) ->
      first ExtensionCalculusRefused (instantiateDeclaration (extDeclaration specification) scope parameters
        (if parameterSchema parameters == InferenceConfig then resources else zeroResources))) initialRemaining
    qualified <- first ExtensionConformanceRefused
      (Conformance.qualifyDeclarations Conformance.NativeScopeClientsRequired scope declarations)
    let admitted = Map.fromList [(extensionName declaration, declaration) | declaration <- Conformance.modeledDeclarations qualified]
        prefix = "extension." <> scopeNeed scope <> ".conformance."
        generated = [("conformance/" <> Text.unpack (scopeNeed scope) <> "/" <> path, bytes) | (path, bytes) <- Conformance.modeledFiles qualified]
    go generated admitted initialProduced (initialObservations <> [(prefix <> key, value) | (key, value) <- Conformance.modeledRows qualified]) initialRemaining
   where
    go generated admitted produced observations remaining = case remaining of
      [] -> Right (produced, observations, generated)
      (specification, parameters) : rest -> do
        declaration <- maybe (Left (ExtensionBindingRequired (extensionIdText (extId specification)))) Right
          (Map.lookup (extensionIdText (extId specification)) admitted)
        monitors <- traverse (\factory -> do
          builder <- first ExtensionSurfaceRefused (Surface.buildMonitoring factory parameters)
          first ExtensionMonitoringRefused (Monitoring.realizeMonitoring scope (backing parameters) builder)) (extMonitoring specification)
        fields <- case parameterSchema parameters of
          BuildCacheConfig -> do
            store <- coreReference ObjectStore
            registry <- coreReference Registry
            Right [("cache-budget", number (cacheBudget parameters)), ("cache-temporary", number (cacheTemporary parameters)),
                   ("cache-concurrency", number (cacheConcurrency parameters)), ("object-store", store), ("registry", registry)]
          CoordinationConfig -> Right [("message-bus", maybe "" id (configurationReference parameters))]
          InferenceConfig -> do
            build <- dependency JitBuild specification produced
            service <- maybe (Left (ExtensionBindingRequired (scopeNeed scope))) Right
              (Map.lookup (scopeNeed scope) (boundDeploymentServices (loweredDeployment lowered)))
            case boundCapabilityNeed service of
              InferenceEngineCapabilityNeed inference -> Right
                [("jit-build", build), ("cache-budget", number (cacheBudget parameters)),
                 ("engine-runtime", engineRuntimeName (inferenceRuntime inference)),
                 ("engine-family", inferenceFamilyName (inferenceFamily inference))]
              _ -> Left (ExtensionBindingRequired (scopeNeed scope))
          TrainingConfig -> do
            build <- dependency JitBuild specification produced
            coordination <- dependency Coordination specification produced
            inference <- dependency (ServiceCapability InferenceEngine) specification produced
            Right [("jit-build", build), ("coordination", coordination), ("infernix", inference),
                   ("training-store", maybe "" id (configurationReference parameters))]
        let name = extensionIdText (extId specification)
            reference = "plan-" <> sha256Hex (frameFields
              (["extension-plan/v1", name, declarationDigest declaration, scopeLabel scope] <>
               concat [[key, value] | (key, value) <- fields]))
            prefix = "extension." <> scopeNeed scope <> "." <> name <> "."
            facts = [(prefix <> "output", reference)] <> [(prefix <> key, value) | (key, value) <- fields] <>
              [(prefix <> "declaration." <> key, value) | (key, value) <- declarationRows declaration] <>
              [(prefix <> "monitor." <> Text.pack (show index) <> "." <> key, value)
               | (index, monitor) <- zip [1 :: Int ..] (NonEmpty.toList monitors), (key, value) <- Monitoring.monitoringRows monitor]
        go generated admitted (produced <> [Produced (extId specification) reference fields]) (observations <> facts) rest
  dependency capability specification produced
    | capability `notElem` extRequires specification = Left (ExtensionDependencyOutputMissing (declaredCapabilityName capability))
    | otherwise = case [reference | (provider, _) <- active, capability `elem` extProvides provider,
                        Produced identifier reference _ <- produced, identifier == extId provider] of
        [value] -> Right value
        _ -> Left (ExtensionDependencyOutputMissing (declaredCapabilityName capability))
  number = maybe "" (Text.pack . show)

  engineFor proof object = case objectIdentity object of
    K8sObjectIdentity identity -> ("inferenceengine/" <> Linked.bindingNeed proof <> "/") `Text.isPrefixOf` identity
  assembleSteps objects = do
    base <- first ExtensionStepsRefused (chain [object | object <- objects, not (any (`engineFor` object) extensionProofs)])
    contributions <- concat <$> traverse (\proof -> stepsFor proof objects) extensionProofs
    let steps = sortOn (\step -> (stepFrame step, stepLabel step)) (base <> contributions)
    first ExtensionStepsRefused (validateChain steps)
    Right steps
  stepsFor proof objects = do
    runtime <- runtimeFor proof
    resources <- representedResources proof
    withProof proof $ \scope -> do
      (produced, _, _) <- foldExtensions scope resources [] [] active
      let engineObjects = filter (engineFor proof) objects
      if null engineObjects then Left (ExtensionBindingRequired (Linked.bindingNeed proof)) else Right ()
      inferenceFields <- case [Map.fromList (("infernix-output", reference) : fields)
          | Produced owner reference fields <- produced, (specification, _) <- active,
            owner == extId specification, ServiceCapability InferenceEngine `elem` extProvides specification] of
        [fields] -> Right fields
        _ -> Left (ExtensionDependencyOutputMissing "InferenceEngine")
      epoch <- case Set.toList (Set.fromList [value | object <- objects, Just value <- [Map.lookup "amoebius.io/epoch" (metadataLabels (objectMetadata object))]]) of
        [value] | all (Map.member "amoebius.io/epoch" . metadataLabels . objectMetadata) objects -> Right value
        _ -> Left (ExtensionSurfaceRefused Surface.ExtensionChainMismatch)
      let
        enrich object = case (objectIdentity object, objectSpec object) of
          (K8sObjectIdentity identity, ConfigurationSpec fields)
            | identity == "inferenceengine/" <> scopeNeed scope <> "/config" ->
                object {objectSpec = ConfigurationSpec (Map.union inferenceFields fields)}
          _ -> object
        namespace = case [value | object <- engineObjects, Just value <- [metadataNamespace (objectMetadata object)]] of
          value : _ -> Just value
          [] -> Nothing
        planObject name reference fields = stampScope (scopeStamp scope) K8sObject
          { objectIdentity = K8sObjectIdentity ("extension/" <> scopeNeed scope <> "/" <> name <> "/plan")
          , objectApiVersion = "v1", objectKind = ConfigMapKind
          , objectMetadata = ObjectMetadata (name <> "-" <> Text.take 12 (Text.drop 2 (scopeLabel scope))) namespace
              (Map.fromList [("amoebius.io/owner", "extension/" <> name),
                ("app.kubernetes.io/managed-by", "amoebius"), ("amoebius.io/epoch", epoch)]) Map.empty
          , objectSpec = ConfigurationSpec (Map.fromList (("output", reference) : fields))
          , objectActivation = Immediate, objectReconcileMode = ServerSideApply }
      contributions <- traverse (\(specification, parameters) -> do
        let name = extensionIdText (extId specification)
            plans = [planObject name reference fields | Produced owner reference fields <- produced, owner == extId specification]
            owned = plans <> if ServiceCapability InferenceEngine `elem` extProvides specification then map enrich engineObjects else []
        input <- first ExtensionSurfaceRefused (Surface.prepareExtensionInput scope specification parameters runtime owned)
        first ExtensionSurfaceRefused (Surface.checkContributedChain input (extChain specification input))) active
      Right (concat contributions)

-- A plan reference binds every field with unambiguous byte framing. Neither
-- ambient Show formatting nor a caller-provided reference defines identity.
frameFields :: [Text] -> ByteString.ByteString
frameFields = LazyByteString.toStrict . Builder.toLazyByteString . foldMap
  (\field -> let bytes = Encoding.encodeUtf8 field in
    Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes)

-- Exact source bytes were sealed at link time by the shared checker. Writing
-- them under the compile output lets the shipped astcheck command re-admit
-- that complete closure without trusting an unrelated working directory.
admittedSources :: [(FilePath, Text)]
admittedSources = case Linked.linkedExtensionSet of
  Left _ -> []
  Right links -> case Linked.extensionsIn links of
    [] -> []
    specification : _ -> [("admitted-source/" <> contributionRoot <> "/" <> path, source) |
      (path, source) <- NonEmpty.toList (checkedSourceFiles (extSourceSeal specification))]
