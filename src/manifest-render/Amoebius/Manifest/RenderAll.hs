module Amoebius.Manifest.RenderAll
  ( renderAll
  ) where

import Amoebius.Capacity.Provision (ProvisionedSpec, provisionedRenderSources)
import Amoebius.Capacity.RenderSource (provisionedRenderSourceMap)
import Amoebius.Manifest.K8sObject (K8sObject)
import Amoebius.Manifest.Render (renderSourcePrivate)
import Data.Map.Strict qualified as Map

-- | Pure total mapping of the sole identity-keyed source inventory. Map order
-- fixes deterministic identity order; no renderer re-derives ownership.
renderAll :: ProvisionedSpec -> [K8sObject]
renderAll = fmap renderSourcePrivate . Map.elems . provisionedRenderSourceMap . provisionedRenderSources
