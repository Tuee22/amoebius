module Amoebius.Manifest.RenderAll
  ( renderAll
  ) where

import Amoebius.Capacity.Provision (ProvisionedSpec, provisionedEpoch, provisionedPlacement, provisionedRenderSources)
import Amoebius.Manifest.K8sObject (K8sObject)
import Amoebius.Manifest.Render (RenderRefusal, renderCandidates)

-- | Pure total mapping of the sole identity-keyed source inventory through the placement
-- and epoch the provision stage produced. Map order fixes deterministic identity order; no
-- renderer re-derives ownership.
renderAll :: ProvisionedSpec -> Either RenderRefusal [K8sObject]
renderAll spec = renderCandidates (provisionedPlacement spec) (provisionedEpoch spec) (provisionedRenderSources spec)
