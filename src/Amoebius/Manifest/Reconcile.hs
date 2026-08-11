{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Reconcile
  ( ReconcilePlan
  , reconcilePlan
  , reconcileActions
  , planInitialIdentity
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..))
import Amoebius.Manifest.Actions
import Amoebius.Manifest.Preflight (ValidatedLiveTarget, validatedTargetActions)
import Data.Text qualified as Text

newtype ReconcilePlan = ReconcilePlan {reconcileActions :: [ValidatedExecutionTransitionAction]}
  deriving stock (Eq, Show)

reconcilePlan :: ValidatedLiveTarget -> ReconcilePlan
reconcilePlan = ReconcilePlan . validatedTargetActions

planInitialIdentity :: K8sObjectIdentity -> ValidatedExecutionTransitionAction
planInitialIdentity identity@(K8sObjectIdentity raw)
  | "Namespace/" `Text.isPrefixOf` raw = validatedAction ColdCreateNamespace identity
  | "Lease/" `Text.isPrefixOf` raw = validatedAction AcquireMandatoryLease identity
  | "StatefulSet/" `Text.isPrefixOf` raw = validatedAction SerialOnDeleteStart identity
  | "Job/" `Text.isPrefixOf` raw = validatedAction RetainTerminalAwaitingCompletionGateway identity
  | "Deployment/" `Text.isPrefixOf` raw = validatedAction ApplyDesiredPodController identity
  | otherwise = validatedAction ApplyDesiredObject identity
