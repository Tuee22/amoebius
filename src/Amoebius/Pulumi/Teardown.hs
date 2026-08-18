{-# LANGUAGE CPP #-}

-- | Fail-closed teardown decisions and broadened run-owned enumeration.
module Amoebius.Pulumi.Teardown
  ( ResourceClass (..)
  , ResourceObservation (..)
  , TeardownDecision (..)
  , TeardownError (..)
  , SweepCriteria (..)
  , ObservedResource (..)
  , teardownDecision
  , sweepRunOwned
  ) where

import Data.Text (Text)

data ResourceClass = Ephemeral | Durable
  deriving stock (Eq, Show)

data ResourceObservation = Present | Absent | Unreachable
  deriving stock (Eq, Show)

data TeardownDecision = DestroyThenReobserve | AlreadyAbsent | RetainDurable
  deriving stock (Eq, Show)

data TeardownError = RefuseOnUnreachable
  deriving stock (Eq, Show)

data SweepCriteria = SweepCriteria
  { sweepRunTag :: Text
  , sweepVpcId :: Text
  , sweepClusterName :: Text
  }
  deriving stock (Eq, Show)

data ObservedResource = ObservedResource
  { observedResourceId :: Text
  , observedResourceClass :: ResourceClass
  , observedRunTag :: Maybe Text
  , observedVpcId :: Maybe Text
  , observedClusterName :: Maybe Text
  }
  deriving stock (Eq, Show)

teardownDecision :: ResourceClass -> ResourceObservation -> Either TeardownError TeardownDecision
teardownDecision Durable _ = Right RetainDurable
teardownDecision Ephemeral Present = Right DestroyThenReobserve
teardownDecision Ephemeral Absent = Right AlreadyAbsent
teardownDecision Ephemeral Unreachable = Left RefuseOnUnreachable

sweepRunOwned :: SweepCriteria -> [ObservedResource] -> [Text]
#ifdef PROVIDER_DYNAMIC_NODES_SKIP_SWEEP_MUTANT
sweepRunOwned _ _ = []
#else
sweepRunOwned criteria = map observedResourceId . filter leaked
 where
  leaked resource = observedResourceClass resource == Ephemeral && owned resource
  owned resource =
    observedRunTag resource == Just (sweepRunTag criteria)
#ifdef PROVIDER_DYNAMIC_NODES_UNTAGGED_ORPHAN_MUTANT
#else
      || observedVpcId resource == Just (sweepVpcId criteria)
      || observedClusterName resource == Just (sweepClusterName criteria)
#endif
#endif
