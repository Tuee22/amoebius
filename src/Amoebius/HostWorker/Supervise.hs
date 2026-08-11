module Amoebius.HostWorker.Supervise
  ( SupervisorPolicy (..)
  , SupervisorSample (..)
  , SupervisorDecision (..)
  , EnforcementRequirement (..)
  , SupervisorError (..)
  , validateSupervisor
  , evaluateSamples
  ) where

import Data.Word (Word64)

data SupervisorPolicy = SupervisorPolicy
  { sampleIntervalMillis :: Word64
  , consecutiveBreachLimit :: Word64
  , cpuCeilingMillis :: Word64
  , rssCeilingBytes :: Word64
  , metalCeilingBytes :: Word64
  , cacheCeilingBytes :: Word64
  }
  deriving stock (Eq, Show)

data SupervisorSample = SupervisorSample
  { observedCpuMillis :: Word64
  , observedRssBytes :: Word64
  , observedMetalBytes :: Word64
  , observedCacheBytes :: Word64
  }
  deriving stock (Eq, Show)

data SupervisorDecision = Continue | TerminateAtSample Int
  deriving stock (Eq, Show)

data EnforcementRequirement = FiniteReactive | InstantaneousHardQuota
  deriving stock (Eq, Show)

data SupervisorError = InvalidSupervisorPolicy | UnsupportedEnforcement
  deriving stock (Eq, Show)

validateSupervisor :: EnforcementRequirement -> SupervisorPolicy -> Either SupervisorError SupervisorPolicy
validateSupervisor InstantaneousHardQuota _ = Left UnsupportedEnforcement
validateSupervisor FiniteReactive policy
  | any (== 0)
      [ sampleIntervalMillis policy
      , consecutiveBreachLimit policy
      , cpuCeilingMillis policy
      , rssCeilingBytes policy
      , metalCeilingBytes policy
      , cacheCeilingBytes policy
      ] = Left InvalidSupervisorPolicy
  | otherwise = Right policy

evaluateSamples :: SupervisorPolicy -> [SupervisorSample] -> SupervisorDecision
evaluateSamples policy = go 1 0
 where
  go _ _ [] = Continue
  go ordinal consecutive (sample : rest)
    | breached sample =
        let next = consecutive + 1
         in if next >= consecutiveBreachLimit policy
              then TerminateAtSample ordinal
              else go (ordinal + 1) next rest
    | otherwise = go (ordinal + 1) 0 rest
  breached sample = or
    [ observedCpuMillis sample > cpuCeilingMillis policy
    , observedRssBytes sample > rssCeilingBytes policy
    , observedMetalBytes sample > metalCeilingBytes policy
    , observedCacheBytes sample > cacheCeilingBytes policy
    ]
