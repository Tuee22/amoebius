{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Capability.Phase30Mutation
  ( phase30MutationTargets
  ) where

import Data.Text (Text)

-- | Closed production mutation registry.  The validation supervisor joins
-- these identities with an independently literal oracle registry and Cabal
-- flags before it executes any row.
phase30MutationTargets :: [(Text, Text)]
phase30MutationTargets =
  [ ("copy-shape-tag", "providerGraph")
  , ("catchall-arm", "capabilityArm")
  , ("shared-app-import", "renderCapabilityNeedSurface")
  , ("provisioned-value-in-bound-deployment", "boundDeploymentIsUnprovisioned")
  ]
