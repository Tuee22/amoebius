-- | The kernel's view of the phase-identity table.
--
-- The table itself lives in the plan-decisions library ('Amoebius.Plan.PhaseIdentity');
-- this module re-exports it so that every kernel consumer keeps its import while the
-- single ordinal-to-capability authority moves out of the validator (DL-0008).
module Amoebius.Validation.PhaseIdentity
  ( PhaseIdentity
  , PhaseRole (..)
  , ResourceProvisionRequirement (..)
  , allPhaseIdentities
  , isPhaseOrdinal
  , lookupCapabilityOrdinal
  , lookupPhaseIdentity
  , phaseIdentityCapability
  , phaseIdentityIntegrityProblems
  , phaseIdentityOrdinal
  , phaseIdentityPath
  , phaseDomainLowerOrdinal
  , phaseDomainUpperOrdinal
  , phaseIdentityResourceProvision
  , phaseOrdinals
  , predecessorOrdinal
  , roleOrdinal
  , successorOrdinal
  ) where

import Amoebius.Plan.PhaseIdentity
