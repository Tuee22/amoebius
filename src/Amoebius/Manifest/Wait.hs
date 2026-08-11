{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Manifest.Wait
  ( ReadinessObservation (..)
  , ChildEnvelope (..)
  , ControllerEnvelopeNamespace (..)
  , ControllerEnvelopeOwner (..)
  , WaitError (..)
  , observeReady
  , validateChildEnvelope
  , claimControllerEnvelopeNamespaces
  ) where

import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ReadinessObservation = ReadinessObservation
  { readinessAvailable :: Bool
  , readinessCreatedMillis :: Natural
  , readinessObservedMillis :: Natural
  , readinessInitialDelaySeconds :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ChildEnvelope = ChildEnvelope
  { childCpuMillis :: Natural
  , childMemoryBytes :: Natural
  , childEphemeralBytes :: Natural
  , childStorageBytes :: Natural
  , childReplicas :: Natural
  , childRolloutOverlap :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ControllerEnvelopeNamespace = ControllerEnvelopeNamespace Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype ControllerEnvelopeOwner = ControllerEnvelopeOwner Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data WaitError
  = ConvergenceTimeout
  | ReadinessReportedBeforeInitialDelay
  | ChildEnvelopeExceeded ChildEnvelope ChildEnvelope
  | ControllerEnvelopeNamespaceShared ControllerEnvelopeNamespace ControllerEnvelopeOwner ControllerEnvelopeOwner
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

observeReady :: ReadinessObservation -> Either WaitError ()
#ifdef PHASE26_WAIT_FOR_READY_PURE_MUTANT
observeReady _ = Right ()
#else
observeReady observed
  | not (readinessAvailable observed) = Left ConvergenceTimeout
  | readinessObservedMillis observed < readinessCreatedMillis observed + readinessInitialDelaySeconds observed * 1000 = Left ReadinessReportedBeforeInitialDelay
  | otherwise = Right ()
#endif

validateChildEnvelope :: ChildEnvelope -> ChildEnvelope -> Either WaitError ()
#ifdef PHASE26_HEALTHY_OVERBOUND_CHILD_MUTANT
validateChildEnvelope _ _ = Right ()
#else
validateChildEnvelope provisioned observed
  | childCpuMillis observed > childCpuMillis provisioned = exceeded
  | childMemoryBytes observed > childMemoryBytes provisioned = exceeded
  | childEphemeralBytes observed > childEphemeralBytes provisioned = exceeded
  | childStorageBytes observed > childStorageBytes provisioned = exceeded
  | childReplicas observed > childReplicas provisioned = exceeded
  | childRolloutOverlap observed > childRolloutOverlap provisioned = exceeded
  | otherwise = Right ()
 where
  exceeded = Left (ChildEnvelopeExceeded provisioned observed)
#endif

claimControllerEnvelopeNamespaces
  :: [(ControllerEnvelopeOwner, ControllerEnvelopeNamespace)]
  -> Either WaitError (Map ControllerEnvelopeNamespace ControllerEnvelopeOwner)
claimControllerEnvelopeNamespaces = foldl claimOne (Right Map.empty)
 where
  claimOne result (owner, namespace) = do
    claimed <- result
    case Map.lookup namespace claimed of
      Nothing -> Right (Map.insert namespace owner claimed)
      Just current
        | current == owner -> Right claimed
        | otherwise -> Left (ControllerEnvelopeNamespaceShared namespace current owner)
