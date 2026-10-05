{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | The unit-tagged resource vector and its total arithmetic. Every axis is a
-- 'Quantity' of its own unit, so a sum or a comparison across two units does not
-- compile, and a quantity reaches a bare number only through 'quantityValue'.
module Amoebius.Capacity.Vector
  ( ResourceVector (..)
  , zeroResources
  , addResources
  , monus
  ) where

import Amoebius.Vocabulary (Quantity, Unit (..))
import Control.DeepSeq (NFData)
import GHC.Generics (Generic)

-- | What a workload, a node, or a budget holds on the four axes the fold judges.
data ResourceVector = ResourceVector
  { resourceCpu :: Quantity 'CpuUnit
  , resourceMemory :: Quantity 'MemoryUnit
  , resourceEphemeralStorage :: Quantity 'EphemeralUnit
  , resourcePodSlots :: Quantity 'SlotUnit
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

zeroResources :: ResourceVector
zeroResources = ResourceVector 0 0 0 0

addResources :: ResourceVector -> ResourceVector -> ResourceVector
addResources left right =
  ResourceVector
    { resourceCpu = resourceCpu left + resourceCpu right
    , resourceMemory = resourceMemory left + resourceMemory right
    , resourceEphemeralStorage = resourceEphemeralStorage left + resourceEphemeralStorage right
    , resourcePodSlots = resourcePodSlots left + resourcePodSlots right
    }

-- | The difference of two quantities of one unit, with a result below zero held at zero.
monus :: Quantity unit -> Quantity unit -> Quantity unit
monus available required = available - min available required
