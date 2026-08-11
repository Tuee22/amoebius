{-# LANGUAGE CPP #-}

module Amoebius.Ui.Release.Compatibility
  ( PresentedPlan (..)
  , Admission (..)
  , admitAction
  ) where

import Amoebius.Ui.Release.ArtifactManifest
import Amoebius.Ui.Release.PlanPair
import Amoebius.Ui.Release.Projection

data PresentedPlan = PresentedPlan
  { presentedClientDigest :: Maybe ArtifactDigest
  , presentedServerDigest :: Maybe ArtifactDigest
  , presentedAuthorityDigest :: Maybe ArtifactDigest
  , presentedContentDigest :: Maybe ArtifactDigest
  }
  deriving stock (Eq, Show)

data Admission = Accepted | ReloadRequired
  deriving stock (Eq, Show)

admitAction :: UiProgramRelease -> PresentedPlan -> Admission
admitAction current presented
  | presentedClientDigest presented /= Just expectedClient = ReloadRequired
  | presentedServerDigest presented /= Just expectedServer = ReloadRequired
#ifndef PHASE40_ACCEPT_STALE_AUTHORITY_DIGEST_MUTANT
  | presentedAuthorityDigest presented /= Just (uiReleaseAuthority current) = ReloadRequired
#endif
  | presentedContentDigest presented /= Just (releaseContentDigest current) = ReloadRequired
  | otherwise = Accepted
 where
  pair = uiReleasePair current
  expectedClient = planDigest (pairClient pair)
  expectedServer = planDigest (pairServer pair)
