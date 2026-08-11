{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Diff
  ( DesiredObject (..)
  , DesiredObjectIndex
  , ObservedObject (..)
  , DiffError (..)
  , validateAndIndexRenderedObjects
  , planObjectActions
  ) where

import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (..)
  , RenderActivation (..)
  )
import Amoebius.Manifest.Actions
import Amoebius.Manifest.K8sObject
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

data DesiredObject = DesiredObject
  { desiredObject :: K8sObject
  , desiredActivation :: RenderActivation
  , desiredDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type DesiredObjectIndex = Map K8sObjectIdentity DesiredObject

data ObservedObject = ObservedObject
  { observedObjectIdentity :: K8sObjectIdentity
  , observedResourceVersion :: Text
  , observedDesiredDigest :: Text
  , observedOwner :: Text
  , observedGeneration :: Text
  , observedRetained :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DiffError
  = DuplicateRenderedIdentity K8sObjectIdentity
  | RenderedDomainMismatch (Set.Set K8sObjectIdentity) (Set.Set K8sObjectIdentity)
  | RenderedActivationMismatch K8sObjectIdentity RenderActivation RenderActivation
  | GenericSsaStageNotEligible K8sObjectIdentity RenderActivation
  | ObjectMapKeyMismatch K8sObjectIdentity K8sObjectIdentity
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateAndIndexRenderedObjects
  :: Map K8sObjectIdentity RenderActivation
  -> Map K8sObjectIdentity Text
  -> [K8sObject]
  -> Either DiffError DesiredObjectIndex
validateAndIndexRenderedObjects expectedStages digests rendered = do
  indexed <- foldl insertOne (Right Map.empty) rendered
  if Map.keysSet indexed == Map.keysSet expectedStages
    then Right indexed
    else Left (RenderedDomainMismatch (Map.keysSet expectedStages) (Map.keysSet indexed))
 where
  insertOne outcome object = do
    accumulated <- outcome
    let identity = objectIdentity object
    if Map.member identity accumulated
      then Left (DuplicateRenderedIdentity identity)
      else Right ()
    expected <- case Map.lookup identity expectedStages of
      Nothing -> Left (RenderedDomainMismatch (Map.keysSet expectedStages) (Set.insert identity (Map.keysSet accumulated)))
      Just stage -> Right stage
    if objectActivation object == expected
      then Right ()
      else Left (RenderedActivationMismatch identity expected (objectActivation object))
    let digest = Map.findWithDefault "sha256:missing" identity digests
    Right (Map.insert identity (DesiredObject object expected digest) accumulated)

planObjectActions
  :: Bool
  -> Text
  -> DesiredObjectIndex
  -> Map K8sObjectIdentity ObservedObject
  -> Either DiffError [ValidatedExecutionTransitionAction]
planObjectActions authority generation desired observed =
  traverse plan (Map.toAscList desired)
 where
  plan (identity, wanted) = case Map.lookup identity observed of
    Just actual
      | observedObjectIdentity actual /= identity ->
          Left (ObjectMapKeyMismatch identity (observedObjectIdentity actual))
      | observedDesiredDigest actual == desiredDigest wanted
          && observedGeneration actual == generation ->
              Right (validatedAction (stableKind (objectKind (desiredObject wanted))) identity)
    _ -> do
      if authority then Right () else Left (GenericSsaStageNotEligible identity (desiredActivation wanted))
      if desiredActivation wanted == Immediate
        then Right ()
        else Left (GenericSsaStageNotEligible identity (desiredActivation wanted))
      Right (validatedAction (applyKind (objectKind (desiredObject wanted))) identity)

#ifdef PHASE26_GENERATION_AFTER_DIFF_MUTANT
  -- The mutant deliberately turns stable objects into writes by changing the
  -- generation after diff. The external snapshot oracle catches this.
  stableKind _ = ApplyDesiredObject
#else
  stableKind kind
    | kind == JobKind = RetainTerminalAwaitingCompletionGateway
    | otherwise = NoOp
#endif

  applyKind kind
    | kind `elem` [DeploymentKind, StatefulSetKind, DaemonSetKind] = ApplyDesiredPodController
    | kind == JobKind = RetainTerminalAwaitingCompletionGateway
    | otherwise = ApplyDesiredObject
