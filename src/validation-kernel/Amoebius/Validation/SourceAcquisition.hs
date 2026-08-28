-- | Refusal-only external source-acquisition facade.
--
-- Caller-supplied trust anchors, challenges, replay sets, manifests, wires,
-- and bundles can exercise the bounded diagnostic protocol. Candidate-facing
-- verification and the opaque acquired-snapshot constructor remain
-- package-hidden.
module Amoebius.Validation.SourceAcquisition
  ( sourceAcquisitionDiagnostic
  ) where

import Amoebius.Validation.SourceAcquisition.Internal
  ( sourceAcquisitionDiagnostic
  )
