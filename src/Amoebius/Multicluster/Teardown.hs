module Amoebius.Multicluster.Teardown
  ( TeardownGuarantee (..)
  , TeardownObservation (..)
  , gracefulTeardown
  , chaosFailover
  ) where

data TeardownGuarantee
  = LosslessBySynchronization
  | BoundedByFailoverBudget
  deriving stock (Eq, Show)

data TeardownObservation = TeardownObservation
  { replicationSynchronized :: Bool
  , gatewayHandedOff :: Bool
  , retainedBackingPreserved :: Bool
  , releasedCompute :: Bool
  , observedGuarantee :: TeardownGuarantee
  }
  deriving stock (Eq, Show)

gracefulTeardown :: Bool -> TeardownObservation
gracefulTeardown synchronized = TeardownObservation
  { replicationSynchronized = synchronized
  , gatewayHandedOff = synchronized
  , retainedBackingPreserved = True
  , releasedCompute = synchronized
  , observedGuarantee = LosslessBySynchronization
  }

chaosFailover :: TeardownObservation
chaosFailover = TeardownObservation
  { replicationSynchronized = False
  , gatewayHandedOff = True
  , retainedBackingPreserved = True
  , releasedCompute = True
  , observedGuarantee = BoundedByFailoverBudget
  }
