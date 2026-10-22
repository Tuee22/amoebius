{-# LANGUAGE OverloadedStrings #-}

-- | Link-time capability declarations. Peer-only concerns do not add arms to
-- the application-facing service vocabulary or its Dhall decoder.
module Amoebius.Extension.Capability
  ( DeclaredCapability (..), coreCapabilities, declaredCapabilityName
  , serviceCapability
  ) where

import Amoebius.Vocabulary (CapabilityArm (..))
import Data.Text (Text)
import Data.Text qualified as Text

data DeclaredCapability
  = ServiceCapability CapabilityArm
  | JitBuild
  | Coordination
  deriving (Eq, Ord, Show)

-- InferenceEngine belongs to the closed service vocabulary, but its provider
-- is extension-owned. Seeding it here would hide an absent infernix library.
coreCapabilities :: [DeclaredCapability]
coreCapabilities =
  [ServiceCapability arm | arm <- [minBound .. maxBound], arm /= InferenceEngine]

declaredCapabilityName :: DeclaredCapability -> Text
declaredCapabilityName capability = case capability of
  ServiceCapability arm -> Text.pack (show arm)
  JitBuild -> "JitBuild"
  Coordination -> "Coordination"

serviceCapability :: DeclaredCapability -> Maybe CapabilityArm
serviceCapability capability = case capability of
  ServiceCapability arm -> Just arm
  JitBuild -> Nothing
  Coordination -> Nothing
