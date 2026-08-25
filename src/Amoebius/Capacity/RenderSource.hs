{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | The checked, renderer-independent source inventory sealed by Phase 12.
-- No Kubernetes AST or serialization type is imported here.
module Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (..)
  , KubernetesObjectId
  , RenderActivation (..)
  , ReconcileMode (..)
  , RenderSourceOwner (..)
  , ProvisionedPartWitness (..)
  , RenderSourceCandidate (..)
  , ProvisionedDeploymentParts (..)
  , ProvisionedRenderSource
  , renderSourceIdentity
  , renderSourceOwner
  , renderSourceFields
  , renderSourceReconcileMode
  , renderSourceActivation
  , renderSourceWitness
  , ProvisionedRenderSourceSet
  , provisionedRenderSourceMap
  , RenderSourceError (..)
  , provisionRenderSources
  , activationForWitness
  , ownerForWitness
  ) where

import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)

newtype K8sObjectIdentity = K8sObjectIdentity Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

type KubernetesObjectId = K8sObjectIdentity

data RenderActivation
  = Immediate
  | BootstrapSchedulerStage
  | AfterBootstrapAddonCutover
  | AfterManagedCapacityReady
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data ReconcileMode = ServerSideApply | CreateBeforeDelete | ReplaceOnChange
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data RenderSourceOwner
  = DeploymentGlobalOwner
  | CapabilityServiceOwner Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedPartWitness
  = NamespacePart
  | CapacitySchedulerPart
  | BootstrapAddonCutoverPart
  | ManagedCapacityAdmissionPart
  | ServiceConfigurationPart Text
  | ServiceEndpointPart Text
  | ServiceWorkloadPart Text
  | ServicePolicyPart Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Candidate key is intentionally separate from embedded identity so the
-- equal-key invariant is checked rather than made tautological.
data RenderSourceCandidate = RenderSourceCandidate
  { candidateMapKey :: K8sObjectIdentity
  , candidateIdentity :: K8sObjectIdentity
  , candidateOwner :: RenderSourceOwner
  , candidateFields :: Map Text Text
  , candidateReconcileMode :: ReconcileMode
  , candidateActivation :: RenderActivation
  , candidateWitness :: ProvisionedPartWitness
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedDeploymentParts = ProvisionedDeploymentParts
  { expectedRenderSourceDomain :: Set K8sObjectIdentity
  , renderSourceCandidates :: [RenderSourceCandidate]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedRenderSource = ProvisionedRenderSource
  { renderSourceIdentity :: K8sObjectIdentity
  , renderSourceOwner :: RenderSourceOwner
  , renderSourceFields :: Map Text Text
  , renderSourceReconcileMode :: ReconcileMode
  , renderSourceActivation :: RenderActivation
  , renderSourceWitness :: ProvisionedPartWitness
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ProvisionedRenderSourceSet = ProvisionedRenderSourceSet
  { provisionedRenderSourceMap :: Map K8sObjectIdentity ProvisionedRenderSource
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RenderSourceError
  = DuplicateRenderSource K8sObjectIdentity
  | MissingRenderSourceDomain (Set K8sObjectIdentity) (Set K8sObjectIdentity)
  | RenderSourceKeyMismatch K8sObjectIdentity K8sObjectIdentity
  | RenderSourceOwnerMismatch K8sObjectIdentity RenderSourceOwner RenderSourceOwner
  | RenderSourceActivationMismatch K8sObjectIdentity RenderActivation RenderActivation
  | MissingActivationStage RenderActivation
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionRenderSources :: ProvisionedDeploymentParts -> Either RenderSourceError ProvisionedRenderSourceSet
provisionRenderSources parts = do
  sources <- foldl insertCandidate (Right Map.empty) (renderSourceCandidates parts)
  let observed = Map.keysSet sources
      expected = expectedRenderSourceDomain parts
  if observed /= expected
    then Left (MissingRenderSourceDomain expected observed)
    else Right ()
  mapM_ (ensureStage sources) [minBound .. maxBound]
  pure (ProvisionedRenderSourceSet sources)
 where
  insertCandidate outcome candidate = do
    accumulated <- outcome
    if candidateMapKey candidate /= candidateIdentity candidate
      then Left (RenderSourceKeyMismatch (candidateMapKey candidate) (candidateIdentity candidate))
      else Right ()
    case Map.lookup (candidateMapKey candidate) accumulated of
      Just _ -> Left (DuplicateRenderSource (candidateMapKey candidate))
      Nothing -> Right ()
    let expectedOwner = ownerForWitness (candidateWitness candidate)
        expectedActivation = activationForWitness (candidateWitness candidate)
    if candidateOwner candidate /= expectedOwner
      then Left (RenderSourceOwnerMismatch (candidateIdentity candidate) expectedOwner (candidateOwner candidate))
      else Right ()
    if candidateActivation candidate /= expectedActivation
      then Left (RenderSourceActivationMismatch (candidateIdentity candidate) expectedActivation (candidateActivation candidate))
      else Right ()
    let source =
          ProvisionedRenderSource
            { renderSourceIdentity = candidateIdentity candidate
            , renderSourceOwner = candidateOwner candidate
            , renderSourceFields = candidateFields candidate
            , renderSourceReconcileMode = candidateReconcileMode candidate
            , renderSourceActivation = candidateActivation candidate
            , renderSourceWitness = candidateWitness candidate
            }
    Right (Map.insert (candidateMapKey candidate) source accumulated)

ensureStage :: Map K8sObjectIdentity ProvisionedRenderSource -> RenderActivation -> Either RenderSourceError ()
ensureStage sources stage
  | any ((== stage) . renderSourceActivation) (Map.elems sources) = Right ()
  | otherwise = Left (MissingActivationStage stage)

activationForWitness :: ProvisionedPartWitness -> RenderActivation
activationForWitness witness = case witness of
  NamespacePart -> Immediate
  CapacitySchedulerPart -> BootstrapSchedulerStage
  BootstrapAddonCutoverPart -> AfterBootstrapAddonCutover
  ManagedCapacityAdmissionPart -> AfterManagedCapacityReady
  ServiceConfigurationPart _ -> Immediate
  ServiceEndpointPart _ -> AfterBootstrapAddonCutover
  ServiceWorkloadPart _ -> AfterBootstrapAddonCutover
  ServicePolicyPart _ -> AfterManagedCapacityReady

ownerForWitness :: ProvisionedPartWitness -> RenderSourceOwner
ownerForWitness witness = case witness of
  NamespacePart -> DeploymentGlobalOwner
  CapacitySchedulerPart -> DeploymentGlobalOwner
  BootstrapAddonCutoverPart -> DeploymentGlobalOwner
  ManagedCapacityAdmissionPart -> DeploymentGlobalOwner
  ServiceConfigurationPart service -> CapabilityServiceOwner service
  ServiceEndpointPart service -> CapabilityServiceOwner service
  ServiceWorkloadPart service -> CapabilityServiceOwner service
  ServicePolicyPart service -> CapabilityServiceOwner service
