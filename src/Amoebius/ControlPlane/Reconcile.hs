{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | A small total model of discover -> diff -> enact -> re-observe.
module Amoebius.ControlPlane.Reconcile
  ( ObjectIdentity (..)
  , ReconcilePlan (..)
  , EnactRecord (..)
  , enactPlan
  , executePlan
  , converged
  ) where

import Amoebius.ControlPlane.Singleton (singletonFieldManager)
import Control.DeepSeq (NFData)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

newtype ObjectIdentity = ObjectIdentity {unObjectIdentity :: Text}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype ReconcilePlan = ReconcilePlan {plannedEnactments :: [ObjectIdentity]}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data EnactRecord = EnactRecord
  { enactedIdentity :: ObjectIdentity
  , enactedFieldManager :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

enactPlan :: Set ObjectIdentity -> Set ObjectIdentity -> ReconcilePlan
#ifdef PHASE33_ENACT_NOOP_MUTANT
enactPlan _ _ = ReconcilePlan []
#else
enactPlan desired observed = ReconcilePlan (Set.toAscList (desired `Set.difference` observed))
#endif

executePlan :: Set ObjectIdentity -> ReconcilePlan -> (Set ObjectIdentity, [EnactRecord])
executePlan observed (ReconcilePlan actions) =
  ( observed `Set.union` Set.fromList actions
  , fmap (`EnactRecord` singletonFieldManager) actions
  )

converged :: Set ObjectIdentity -> Set ObjectIdentity -> Bool
converged desired observed = null (plannedEnactments (enactPlan desired observed))
