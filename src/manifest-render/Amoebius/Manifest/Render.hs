{-# LANGUAGE OverloadedStrings #-}

-- | The witness-driven render. The sealed source inventory becomes objects only through a
-- placement witness and an epoch: a workload names the node the fold assigned it, a StatefulSet
-- carries the claim its volume witness sizes, and every object names the epoch it was
-- rendered for.
module Amoebius.Manifest.Render
  ( RenderRefusal (..)
  , renderRefusalTag
  , renderCandidates
  , ScopeAuthorities
  , stampScope
  ) where

import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedPartWitness (..)
  , ProvisionedRenderSource
  , ProvisionedRenderSourceSet
  , provisionedRenderSourceMap
  , renderSourceFields
  , renderSourceIdentity
  , renderSourceWitness
  , RenderSourceOwner
  , renderSourceOwner
  )
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.Sources (renderSourcePrivate)
import Amoebius.Manifest.StatefulSet (renderStatefulSet)
import Amoebius.Placement.Witness (Epoch, Placed, epochName, placedNode)
import Amoebius.Storage.Witness (VolumeRefusal, volumeRefusalTag)
import Amoebius.Scope.Attested (ScopeStamp, stampIssuer, stampApplication, stampNeed, stampLabel)
import Amoebius.Vocabulary (Quantity (..))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Text.Read (readMaybe)

-- | Why a render refused.
data RenderRefusal
  = PvcWithoutStatefulSet Text
  | VolumeRefused Text VolumeRefusal
  | InvalidEngineRuntime Text
  | UnattestedScope Text
  deriving stock (Eq, Show)

renderRefusalTag :: RenderRefusal -> Text
renderRefusalTag refusal = case refusal of
  PvcWithoutStatefulSet _ -> "PvcWithoutStatefulSet"
  VolumeRefused _ problem -> volumeRefusalTag problem
  InvalidEngineRuntime _ -> "InvalidEngineRuntime"
  UnattestedScope _ -> "UnattestedScope"

type ScopeAuthorities = Map.Map RenderSourceOwner ScopeStamp

-- | The one entry into rendering. Every object the sealed source inventory carries is
-- rendered in identity order; a workload names the node the placement witness assigned
-- it, a StatefulSet carries the claim its volume witness sizes, and every object carries the
-- epoch the provision stage rendered for. A volume on any other kind of source is refused.
renderCandidates :: ScopeAuthorities -> Placed -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]
renderCandidates authorities placed epoch sources = concat <$> mapM expand (Map.elems (provisionedRenderSourceMap sources))
 where
  expand source = do
    authority <- maybe (Left (UnattestedScope identity)) Right (Map.lookup (renderSourceOwner source) authorities)
    objects <- expandObjects source
    Right (map (stampScope authority) objects)
   where K8sObjectIdentity identity = renderSourceIdentity source
  expandObjects source
    | Map.lookup "kind" fields == Just "EngineWorkload"
    , Map.lookup "engine-runtime" fields `notElem` map Just ["LinuxCpu", "Cuda", "AppleMetal"] = Left (InvalidEngineRuntime identity)
    | Just size <- volumeOf source, objectKind object == StatefulSetKind = either (Left . VolumeRefused identity) Right (renderStatefulSet object size)
    | Just _ <- volumeOf source = Left (PvcWithoutStatefulSet identity)
    | otherwise = Right [object]
   where
    fields = renderSourceFields source
    -- The object passes through the two witnesses in order: the node, then the epoch.
    object = foldl (\current witness -> witness current) (renderSourcePrivate source) [assignNode source, stampEpoch]
    K8sObjectIdentity identity = renderSourceIdentity source
  volumeOf source = Quantity <$> (Map.lookup "volume-bytes" (renderSourceFields source) >>= readMaybe . Text.unpack)
  stampEpoch object =
    object {objectMetadata = (objectMetadata object) {metadataLabels = Map.insert epochLabel (epochName epoch) (metadataLabels (objectMetadata object))}}
  assignNode source object = case (objectSpec object, workloadOf source) of
    (WorkloadSpec kind pod, Just workload) -> object {objectSpec = WorkloadSpec kind pod {podNodeName = placedNode placed workload}}
    _ -> object

-- | Apply the opaque projection of an actual attestation. This projection
-- labels a rendered value; it cannot introduce or retag a request scope.
stampScope :: ScopeStamp -> K8sObject -> K8sObject
stampScope authority object = object
  { objectMetadata = (objectMetadata object)
      { metadataLabels = Map.insert "amoebius.io/scope" (stampLabel authority) (metadataLabels (objectMetadata object))
      , metadataAnnotations = Map.union (Map.fromList
          [("amoebius.io/scope-issuer", stampIssuer authority),
           ("amoebius.io/scope-application", stampApplication authority),
           ("amoebius.io/scope-need", stampNeed authority)]) (metadataAnnotations (objectMetadata object))
      }
  }

-- | The label that names the epoch an object was rendered for.
epochLabel :: Text
epochLabel = "amoebius.io/epoch"

-- | The identifier the placement fold used for the workload a source renders.
workloadOf :: ProvisionedRenderSource -> Maybe Text
workloadOf source = case renderSourceWitness source of
  AppWorkloadPart app -> Just ("app/" <> app)
  ServiceWorkloadPart _ -> Just identity
  _ -> Nothing
 where
  K8sObjectIdentity identity = renderSourceIdentity source

