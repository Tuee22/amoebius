{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | A bounded growth declaration.  There is deliberately no unbounded arm.
module Amoebius.Capacity.Growable
  ( ScalingPolicy (..)
  , Growable (..)
  , maximumProvisioned
  ) where

import Control.DeepSeq (NFData)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ScalingPolicy = ScalingPolicy
  { scalingTriggerFreeBytes :: Natural
  , scalingIncrementBytes :: Natural
  , scalingCeilingBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Growable a
  = FixedCapacity a
  | PolicyBounded a ScalingPolicy
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

maximumProvisioned :: Growable Natural -> Natural
maximumProvisioned value = case value of
  FixedCapacity bytes -> bytes
  PolicyBounded _ policy -> scalingCeilingBytes policy
