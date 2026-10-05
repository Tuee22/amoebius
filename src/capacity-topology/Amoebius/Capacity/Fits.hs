{-# LANGUAGE DataKinds #-}

-- | The leaf checks of the total fold: one demand against one capacity, and one
-- carve out of a capacity. Both are total, name the first exceeded axis, and an exact
-- fit is a success with zero left on that axis.
module Amoebius.Capacity.Fits
  ( fits
  , carve
  , subtractResources
  , effectiveReserved
  ) where

import Amoebius.Capacity.Types
  ( AvailableCapacity (..)
  , Demand (..)
  , Headroom (..)
  , Overcommit
  , ResourceEnvelope
  , envelopeHeadroom
  , envelopeRequests
  , firstExceeded
  )
import Amoebius.Capacity.Vector (ResourceVector (..), addResources, monus)

-- | One demand against one capacity: what is left, or the first axis the demand exceeds.
fits :: Demand -> ResourceVector -> Either Overcommit Headroom
fits (Demand required) capacity = Headroom <$> subtractResources required capacity

-- | Allocate a sub-capacity out of an available capacity by subtraction.
carve :: AvailableCapacity -> Demand -> Either Overcommit AvailableCapacity
carve (AvailableCapacity capacity) (Demand required) =
  AvailableCapacity <$> subtractResources required capacity

-- | The available vector less the required one, or the first axis (cpu, memory,
-- ephemeral storage, pod slots, in that order) on which the required one exceeds it.
subtractResources :: ResourceVector -> ResourceVector -> Either Overcommit ResourceVector
subtractResources required available = case firstExceeded required available of
  Just excess -> Left excess
  Nothing ->
    Right
      ResourceVector
        { resourceCpu = monus (resourceCpu available) (resourceCpu required)
        , resourceMemory = monus (resourceMemory available) (resourceMemory required)
        , resourceEphemeralStorage = monus (resourceEphemeralStorage available) (resourceEphemeralStorage required)
        , resourcePodSlots = monus (resourcePodSlots available) (resourcePodSlots required)
        }

-- | What a pod reserves: its requests plus its declared headroom.
effectiveReserved :: ResourceEnvelope -> ResourceVector
effectiveReserved envelope = addResources (envelopeRequests envelope) (envelopeHeadroom envelope)
