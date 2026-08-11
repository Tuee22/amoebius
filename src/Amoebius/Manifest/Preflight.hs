{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Manifest.Preflight
  ( LiveResourceVector (..)
  , ObservedLiveResourceSnapshot (..)
  , PreflightError (..)
  , ValidatedLiveTarget
  , validateLiveTarget
  , validatedTargetActions
  , validatedTargetFingerprint
  ) where

import Amoebius.Manifest.Actions (ValidatedExecutionTransitionAction)
import Control.DeepSeq (NFData)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data LiveResourceVector = LiveResourceVector
  { liveCpuMillis :: Natural
  , liveMemoryBytes :: Natural
  , liveEphemeralBytes :: Natural
  , livePodSlots :: Natural
  , liveApiBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedLiveResourceSnapshot = ObservedLiveResourceSnapshot
  { observedLiveFingerprint :: Text
  , observedLiveResidual :: LiveResourceVector
  , observedLiveUnknownCommitments :: Set Text
  , observedLeaseHolder :: Maybe Text
  , observedLeaseResourceVersion :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PreflightError
  = LiveSnapshotChanged Text Text
  | UnknownCommitment (Set Text)
  | LiveCpuExceeded Natural Natural
  | LiveMemoryExceeded Natural Natural
  | LiveEphemeralExceeded Natural Natural
  | LivePodSlotsExceeded Natural Natural
  | LiveApiBytesExceeded Natural Natural
  | MandatoryLeaseNotHeld
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ValidatedLiveTarget = ValidatedLiveTarget
  { validatedTargetFingerprint :: Text
  , validatedTargetActions :: [ValidatedExecutionTransitionAction]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateLiveTarget
  :: Text
  -> Text
  -> LiveResourceVector
  -> ObservedLiveResourceSnapshot
  -> [ValidatedExecutionTransitionAction]
  -> Either PreflightError ValidatedLiveTarget
validateLiveTarget expectedFingerprint expectedHolder demand observed actions = do
  if observedLiveFingerprint observed == expectedFingerprint
    then Right ()
    else Left (LiveSnapshotChanged expectedFingerprint (observedLiveFingerprint observed))
  if Set.null (observedLiveUnknownCommitments observed)
    then Right ()
    else Left (UnknownCommitment (observedLiveUnknownCommitments observed))
  fits LiveCpuExceeded liveCpuMillis
  fits LiveMemoryExceeded liveMemoryBytes
  fits LiveEphemeralExceeded liveEphemeralBytes
  fits LivePodSlotsExceeded livePodSlots
  fits LiveApiBytesExceeded liveApiBytes
  if observedLeaseHolder observed == Just expectedHolder && observedLeaseResourceVersion observed /= Nothing
    then Right ()
    else Left MandatoryLeaseNotHeld
  pure (ValidatedLiveTarget expectedFingerprint actions)
 where
  residual = observedLiveResidual observed
  fits constructor axis =
    let required = axis demand
        available = axis residual
     in if required <= available then Right () else Left (constructor required available)
