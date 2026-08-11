{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Actions
  ( ActionKind (..)
  , ValidatedExecutionTransitionAction
  , validatedAction
  , actionKind
  , actionIdentity
  , renderAction
  , actionCanUseGenericSsa
  , actionIsMutation
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..))
import Control.DeepSeq (NFData)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data ActionKind
  = ColdCreateNamespace
  | AcquireMandatoryLease
  | RenewMandatoryLease
  | ApplyDesiredObject
  | ApplyDesiredPodController
  | SerialOnDeleteStart
  | SerialOnDeleteResume
  | SerialOnDeleteAdvance
  | StopHostProcess
  | StartHostProcess
  | RetainTerminalAwaitingCompletionGateway
  | WriteJobCompletion
  | CleanupTerminalJob
  | CompletedJobNoOp
  | DeleteOwnedObject
  | NoOp
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ValidatedExecutionTransitionAction = ValidatedExecutionTransitionAction
  { actionKind :: ActionKind
  , actionIdentity :: K8sObjectIdentity
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

validatedAction :: ActionKind -> K8sObjectIdentity -> ValidatedExecutionTransitionAction
validatedAction = ValidatedExecutionTransitionAction

renderAction :: ValidatedExecutionTransitionAction -> Text
renderAction action =
  let K8sObjectIdentity identity = actionIdentity action
   in fromString (show (actionKind action)) <> ":" <> identity
 where
  fromString = Text.pack

actionCanUseGenericSsa :: ValidatedExecutionTransitionAction -> Bool
actionCanUseGenericSsa action = actionKind action `elem` [ApplyDesiredObject, ApplyDesiredPodController]

actionIsMutation :: ValidatedExecutionTransitionAction -> Bool
actionIsMutation action = actionKind action `notElem` [NoOp, CompletedJobNoOp, RetainTerminalAwaitingCompletionGateway]
