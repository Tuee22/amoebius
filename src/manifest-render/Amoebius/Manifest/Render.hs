{-# LANGUAGE OverloadedStrings #-}

-- | The witness-driven render. The sealed source inventory becomes objects only through a
-- placement witness and an epoch: a workload names the node the fold assigned it, a StatefulSet
-- carries the claim its volume witness sizes, and every object names the epoch it was
-- rendered for.
module Amoebius.Manifest.Render
  ( RenderRefusal (..)
  , renderRefusalTag
  , renderCandidates
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
  )
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.Sources (renderSourcePrivate)
import Amoebius.Manifest.StatefulSet (renderStatefulSet)
import Amoebius.Placement.Witness (Epoch, Placed, epochName, placedNode)
import Amoebius.Storage.Witness (VolumeRefusal, volumeRefusalTag)
import Amoebius.Vocabulary (Quantity (..))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Text.Read (readMaybe)

-- | Why a render refused.
data RenderRefusal
  = PvcWithoutStatefulSet Text
  | VolumeRefused Text VolumeRefusal
  deriving stock (Eq, Show)

renderRefusalTag :: RenderRefusal -> Text
renderRefusalTag refusal = case refusal of
  PvcWithoutStatefulSet _ -> "PvcWithoutStatefulSet"
  VolumeRefused _ problem -> volumeRefusalTag problem

-- | The one entry into rendering. Every object the sealed source inventory carries is
-- rendered in identity order; a workload names the node the placement witness assigned
-- it, a StatefulSet carries the claim its volume witness sizes, and every object carries the
-- epoch the provision stage rendered for. A volume on any other kind of source is refused.
renderCandidates :: Placed -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]
renderCandidates placed epoch sources = concat <$> mapM expand (Map.elems (provisionedRenderSourceMap sources))
 where
  expand source
    | Just size <- volumeOf source, objectKind object == StatefulSetKind = either (Left . VolumeRefused identity) Right (renderStatefulSet object size)
    | Just _ <- volumeOf source = Left (PvcWithoutStatefulSet identity)
    | otherwise = Right [object]
   where
    -- The object passes through the two witnesses in order: the node, then the epoch.
    object = foldl (\current witness -> witness current) (renderSourcePrivate source) [assignNode source, stampEpoch]
    K8sObjectIdentity identity = renderSourceIdentity source
  volumeOf source = Quantity <$> (Map.lookup "volume-bytes" (renderSourceFields source) >>= readMaybe . Text.unpack)
  stampEpoch object =
    object {objectMetadata = (objectMetadata object) {metadataLabels = Map.insert epochLabel (epochName epoch) (metadataLabels (objectMetadata object))}}
  assignNode source object = case (objectSpec object, workloadOf source) of
    (WorkloadSpec kind pod, Just workload) -> object {objectSpec = WorkloadSpec kind pod {podNodeName = placedNode placed workload}}
    _ -> object

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

