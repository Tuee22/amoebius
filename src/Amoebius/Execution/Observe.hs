{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Execution.Observe
  ( PodUid (..)
  , HostProcessInstanceId (..)
  , HostReservationId (..)
  , ObservedExecutionIdentity (..)
  , ObservedExecution (..)
  , ExecutionObservationError (..)
  , authenticateObservedExecutions
  ) where

import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)

newtype PodUid = PodUid Text deriving stock (Eq, Generic, Ord, Show) deriving anyclass (NFData)
newtype HostProcessInstanceId = HostProcessInstanceId Text deriving stock (Eq, Generic, Ord, Show) deriving anyclass (NFData)
newtype HostReservationId = HostReservationId Text deriving stock (Eq, Generic, Ord, Show) deriving anyclass (NFData)

data ObservedExecutionIdentity
  = KubernetesPod PodUid
  | HostProcess HostProcessInstanceId
  | HostReservation HostReservationId
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObservedExecution = ObservedExecution
  { observedExecutionIdentity :: ObservedExecutionIdentity
  , observedExecutionSource :: Text
  , observedExecutionRevision :: Text
  , observedExecutionOwnerChain :: [Text]
  , observedExecutionBound :: Bool
  , observedExecutionReady :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ExecutionObservationError
  = ExecutionMapKeyMismatch ObservedExecutionIdentity ObservedExecutionIdentity
  | ExecutionProvenanceMissing ObservedExecutionIdentity
  | ExecutionOwnerChainMissing ObservedExecutionIdentity
  | PlannedSlotUsedAsObservedIdentity Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

authenticateObservedExecutions
  :: Map ObservedExecutionIdentity ObservedExecution
  -> Either ExecutionObservationError (Map ObservedExecutionIdentity ObservedExecution)
authenticateObservedExecutions rows = traverseWithKey validate rows
 where
  traverseWithKey function = Map.traverseWithKey function
  validate key value
    | key /= observedExecutionIdentity value = Left (ExecutionMapKeyMismatch key (observedExecutionIdentity value))
    | observedExecutionSource value == "" || observedExecutionRevision value == "" = Left (ExecutionProvenanceMissing key)
    | null (observedExecutionOwnerChain value) = Left (ExecutionOwnerChainMissing key)
    | otherwise = Right value
