{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | The typed, observed bootstrap-host to control-plane daemon Lease handoff.
module Amoebius.ControlPlane.AuthorityHandoff
  ( LeaseSnapshot (..)
  , BootstrapLease
  , ReleasedLease
  , ControlPlaneDaemonLease
  , HandoffError (..)
  , observeBootstrap
  , releaseForHandoff
  , acquireControlPlaneDaemon
  , controlPlaneLeaseSnapshot
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data LeaseSnapshot = LeaseSnapshot
  { handoffLeaseName :: Text
  , handoffLeaseUid :: Text
  , handoffResourceVersion :: Text
  , handoffHolderIdentity :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype BootstrapLease = BootstrapLease LeaseSnapshot
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ReleasedLease = ReleasedLease LeaseSnapshot
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ControlPlaneDaemonLease = ControlPlaneDaemonLease LeaseSnapshot
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HandoffError
  = HandoffLeaseIdentityMissing
  | HandoffBootstrapHolderMismatch Text (Maybe Text)
  | HandoffObjectUidChanged Text Text
  | HandoffResourceVersionStale Text
  | HandoffReleaseNotObserved (Maybe Text)
  | HandoffReleasedLeaseRequired
  | HandoffControlPlaneHolderMismatch Text (Maybe Text)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

observeBootstrap :: Text -> LeaseSnapshot -> Either HandoffError BootstrapLease
observeBootstrap expectedHolder snapshot
  | any Text.null [handoffLeaseName snapshot, handoffLeaseUid snapshot, handoffResourceVersion snapshot] =
      Left HandoffLeaseIdentityMissing
  | handoffHolderIdentity snapshot /= Just expectedHolder =
      Left (HandoffBootstrapHolderMismatch expectedHolder (handoffHolderIdentity snapshot))
  | otherwise = Right (BootstrapLease snapshot)

releaseForHandoff :: BootstrapLease -> LeaseSnapshot -> Either HandoffError ReleasedLease
releaseForHandoff (BootstrapLease prior) successor = do
  validateSuccessor prior successor
  case handoffHolderIdentity successor of
    Nothing -> Right (ReleasedLease successor)
    holder -> Left (HandoffReleaseNotObserved holder)

acquireControlPlaneDaemon :: Text -> ReleasedLease -> LeaseSnapshot -> Either HandoffError ControlPlaneDaemonLease
acquireControlPlaneDaemon podUid (ReleasedLease prior) successor
  | handoffHolderIdentity prior /= Nothing = Left HandoffReleasedLeaseRequired
  | otherwise = do
      validateSuccessor prior successor
      if handoffHolderIdentity successor == Just podUid
        then Right (ControlPlaneDaemonLease successor)
        else Left (HandoffControlPlaneHolderMismatch podUid (handoffHolderIdentity successor))

controlPlaneLeaseSnapshot :: ControlPlaneDaemonLease -> LeaseSnapshot
controlPlaneLeaseSnapshot (ControlPlaneDaemonLease snapshot) = snapshot

validateSuccessor :: LeaseSnapshot -> LeaseSnapshot -> Either HandoffError ()
validateSuccessor prior successor
  | handoffLeaseUid prior /= handoffLeaseUid successor =
      Left (HandoffObjectUidChanged (handoffLeaseUid prior) (handoffLeaseUid successor))
  | handoffLeaseName prior /= handoffLeaseName successor = Left HandoffLeaseIdentityMissing
  | handoffResourceVersion prior == handoffResourceVersion successor =
      Left (HandoffResourceVersionStale (handoffResourceVersion successor))
  | otherwise = Right ()
