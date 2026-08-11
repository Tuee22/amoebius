{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Manifest.Enact
  ( EffectSurface (..)
  , dispatchSurface
  ) where

import Amoebius.Manifest.Actions
import Control.DeepSeq (NFData)
import GHC.Generics (Generic)

data EffectSurface
  = NoEffect
  | LeaseEffect
  | ServerSideApplyEffect
  | SerialControllerEffect
  | HostSupervisorEffect
  | CompletionGatewayEffect
  | AuthenticatedDeleteEffect
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

dispatchSurface :: ValidatedExecutionTransitionAction -> EffectSurface
dispatchSurface action = case actionKind action of
  ColdCreateNamespace -> LeaseEffect
  AcquireMandatoryLease -> LeaseEffect
  RenewMandatoryLease -> LeaseEffect
  ApplyDesiredObject -> ServerSideApplyEffect
  ApplyDesiredPodController -> ServerSideApplyEffect
  SerialOnDeleteStart -> SerialControllerEffect
  SerialOnDeleteResume -> SerialControllerEffect
  SerialOnDeleteAdvance -> SerialControllerEffect
  StopHostProcess -> HostSupervisorEffect
  StartHostProcess -> HostSupervisorEffect
  RetainTerminalAwaitingCompletionGateway -> NoEffect
  WriteJobCompletion -> CompletionGatewayEffect
  CleanupTerminalJob -> CompletionGatewayEffect
  CompletedJobNoOp -> NoEffect
  DeleteOwnedObject -> AuthenticatedDeleteEffect
  NoOp -> NoEffect
