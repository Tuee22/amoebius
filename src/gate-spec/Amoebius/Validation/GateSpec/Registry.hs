{-# LANGUAGE OverloadedStrings #-}

-- | The one registry of gate specifications, keyed by capability. The runner
-- resolves an ordinal to a capability through the phase-identity table and looks
-- the specification up here; an absent entry is a refusal, never a default. The
-- seed specification and the toolchain specification are the first two entries.
module Amoebius.Validation.GateSpec.Registry
  ( registeredCapabilities
  , specInputFor
  ) where

import Amoebius.Validation.GateSpec (GateSpecInput)
import Amoebius.Validation.GateSpec.Seed (phaseZeroSpecInput)
import Amoebius.Validation.GateSpec.Toolchain (toolchainSpecInput)
import Data.Text (Text)

registeredCapabilities :: [Text]
registeredCapabilities = map fst registry

specInputFor :: Text -> Maybe GateSpecInput
specInputFor capability = lookup capability registry

registry :: [(Text, GateSpecInput)]
registry = [("documentation_suite", phaseZeroSpecInput), ("toolchain_spike", toolchainSpecInput)]
