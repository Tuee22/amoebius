{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Admission.ExecutionIdentity
  ( ExecutionIdentity (..)
  , AdmissionReadiness (..)
  , AdmissionError (..)
  , admitExecutionCreate
  , admitExecutionUpdate
  ) where

import Amoebius.Scheduler.Readiness (ManagedCapacityReady)
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data ExecutionIdentity = ExecutionIdentity
  { executionDeployment :: Text
  , executionGeneration :: Text
  , executionSource :: Text
  , executionRevision :: Text
  , executionReservationTemplate :: Text
  , executionSchedulerName :: Text
  , executionOwnerChainValid :: Bool
  , executionToleratesManagedTaint :: Bool
  , executionIsBootstrapScheduler :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data AdmissionReadiness = BeforeManagedCapacityReady | AfterManagedCapacityReady ManagedCapacityReady
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data AdmissionError
  = ManagedCapacityNotReady
  | ExecutionIdentityIncomplete
  | ExecutionOwnerChainInvalid
  | ExecutionSchedulerMismatch
  | DefaultSchedulerManagedNodeBypass
  | ProtectedExecutionIdentityChanged
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

admitExecutionCreate :: AdmissionReadiness -> ExecutionIdentity -> Either AdmissionError ()
admitExecutionCreate readiness identity
  | executionIsBootstrapScheduler identity =
      if executionSchedulerName identity == "default-scheduler" && not (executionToleratesManagedTaint identity)
        then Right ()
        else Left ExecutionSchedulerMismatch
  | incomplete identity = Left ExecutionIdentityIncomplete
  | not (executionOwnerChainValid identity) = Left ExecutionOwnerChainInvalid
#ifndef CAPACITY_SCHEDULER_DEFAULT_SCHEDULER_BYPASS_MUTANT
  | executionToleratesManagedTaint identity && executionSchedulerName identity /= "amoebius-capacity" = Left DefaultSchedulerManagedNodeBypass
#endif
  | executionSchedulerName identity /= "amoebius-capacity" = Left ExecutionSchedulerMismatch
  | otherwise = case readiness of
      BeforeManagedCapacityReady -> Left ManagedCapacityNotReady
      AfterManagedCapacityReady _ -> Right ()

admitExecutionUpdate
  :: AdmissionReadiness
  -> ExecutionIdentity
  -> ExecutionIdentity
  -> Either AdmissionError ()
admitExecutionUpdate readiness old new
  | protected old /= protected new = Left ProtectedExecutionIdentityChanged
  | otherwise = admitExecutionCreate readiness new

incomplete :: ExecutionIdentity -> Bool
incomplete identity = any nullText
  [ executionDeployment identity
  , executionGeneration identity
  , executionSource identity
  , executionRevision identity
  , executionReservationTemplate identity
  ]

protected :: ExecutionIdentity -> (Text, Text, Text, Text, Text, Text)
protected identity =
  ( executionDeployment identity
  , executionGeneration identity
  , executionSource identity
  , executionRevision identity
  , executionReservationTemplate identity
  , executionSchedulerName identity
  )

nullText :: Text -> Bool
nullText value = value == mempty
