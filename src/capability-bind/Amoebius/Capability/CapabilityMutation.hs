{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Capability.CapabilityMutation
  ( capabilityMutationTargets
  ) where

import Data.Text (Text)

-- | Closed production mutation registry.  The validation supervisor joins
-- these identities with an independently literal oracle registry and Cabal
-- flags before it executes any row.
capabilityMutationTargets :: [(Text, Text)]
capabilityMutationTargets =
  [ ("copy-shape-tag", "providerGraph")
  , ("catchall-arm", "capabilityArm")
  , ("shared-app-import", "renderCapabilityNeedSurface")
  , ("provisioned-value-in-bound-deployment", "boundDeploymentIsUnprovisioned")
  ]
